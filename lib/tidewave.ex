defmodule Tidewave do
  @moduledoc false
  @behaviour Plug

  @doc """
  Clears all captured logs from the logger buffer.

  This is useful when you want to ensure that subsequent log retrievals only contain
  fresh logs. A typical pattern is to clear logs before executing code, then retrieve
  logs afterward to see exactly what was logged during that execution.

  You may also instruct your coding agents to invoke this function whenever necessary.
  For example, you might say: "when debugging, use the `project_eval` tool to run
  `Tidewave.clear_logs` before executing code, then use `get_logs` to see only fresh
  output".

  ## Example

      # In project_eval tool:
      Tidewave.clear_logs()
      MyApp.some_function()
      # Now get_logs will only show logs from some_function()

  """
  def clear_logs do
    Tidewave.MCP.Logger.clear_logs()
  end

  @impl true
  def init(opts) do
    %{
      allow_remote_access: Keyword.get(opts, :allow_remote_access, false),
      phoenix_endpoint: nil,
      team: Keyword.get(opts, :team, []),
      toolbar: Keyword.get(opts, :toolbar, true),
      inspect_opts:
        Keyword.get(opts, :inspect_opts, charlists: :as_lists, limit: 50, pretty: true)
    }
  end

  @impl true
  def call(conn, config) do
    config = %{config | phoenix_endpoint: conn.private[:phoenix_endpoint]}

    conn
    |> validate!()
    |> Plug.Conn.put_private(:tidewave_config, config)
    |> call()
  end

  defp call(%Plug.Conn{path_info: ["tidewave" | rest]} = conn) do
    conn
    |> Plug.forward(rest, Tidewave.Router, [])
    |> Plug.Conn.halt()
  end

  defp call(conn) do
    conn
    |> Plug.Conn.register_before_send(fn conn ->
      conn
      |> maybe_rewrite_csp()
      |> Plug.Conn.delete_resp_header("x-frame-options")
      |> maybe_inject_toolbar()
    end)
  end

  defp validate!(conn) do
    if live_reload_enabled?(conn) or request_body_parsed?(conn) do
      raise "plug Tidewave is runnning too late, after the request body has been parsed. " <>
              "Make sure to place \"plug Tidewave\" before the \"if code_reloading? do\" block"
    end

    conn
  end

  defp live_reload_enabled?(conn) do
    match?(%{phoenix_live_reload: true}, conn.private)
  end

  defp request_body_parsed?(conn) do
    not match?(%Plug.Conn.Unfetched{}, conn.body_params)
  end

  defp maybe_rewrite_csp(conn) do
    case Plug.Conn.get_resp_header(conn, "content-security-policy") do
      [csp | _] ->
        csp = rewrite_csp(csp)
        Plug.Conn.put_resp_header(conn, "content-security-policy", csp)

      _ ->
        conn
    end
  end

  defp rewrite_csp(csp) do
    policy_directives = String.split(csp, ";", trim: true)

    for policy_directive <- policy_directives,
        policy_directive = String.trim(policy_directive),
        not String.starts_with?(policy_directive, "frame-ancestors") do
      case String.split(policy_directive, " ", parts: 2) do
        ["script-src", directives] ->
          case :binary.match(directives, "'unsafe-eval'") do
            :nomatch -> "script-src 'unsafe-eval' #{directives}"
            _ -> "script-src #{directives}"
          end

        [policy, directives] ->
          "#{policy} #{directives}"

        [leftover] ->
          leftover
      end
    end
    |> Enum.join("; ")
  end

  defp maybe_inject_toolbar(conn) do
    if conn.private.tidewave_config.toolbar and conn.resp_body != nil and html?(conn) do
      resp_body = IO.iodata_to_binary(conn.resp_body)

      if String.contains?(resp_body, "</head>") do
        {head, [last]} = Enum.split(String.split(resp_body, "</head>"), -1)
        head = Enum.intersperse(head, "</head>")
        body = [head, tidewave_html(conn), "</head>" | last]
        put_in(conn.resp_body, body)
      else
        conn
      end
    else
      conn
    end
  end

  defp html?(conn) do
    case Plug.Conn.get_resp_header(conn, "content-type") do
      [] -> false
      [type | _] -> String.starts_with?(type, "text/html")
    end
  end

  defp tidewave_html(conn) do
    client_url = Application.get_env(:tidewave, :client_url, "https://tidewave.ai")

    app_paths =
      if Code.loaded?(Mix.Project) do
        for {app, path} <- Mix.Project.deps_paths(), into: %{}, do: {to_string(app), path}
      else
        %{}
      end

    config = %{
      tidewave: tidewave_config(conn),
      root: Tidewave.MCP.root(),
      framework: %{
        app_paths: app_paths
      }
    }

    """
    <meta name="tidewave:config" content="#{config |> Jason.encode!() |> Plug.HTML.html_escape()}" />
    <script type="module" src="#{client_url}/tc/toolbar.js"></script>
    """
  end

  @doc false
  def tidewave_config(conn) do
    plug_config = conn.private.tidewave_config

    %{
      project_name: Tidewave.MCP.project_name(),
      framework_type: "phoenix",
      tidewave_version: package_version(:tidewave),
      team: Map.new(plug_config.team),
      local_port: Plug.Conn.get_sock_data(conn).port
    }
  end

  defp package_version(app) do
    if vsn = Application.spec(app)[:vsn] do
      List.to_string(vsn)
    end
  end
end
