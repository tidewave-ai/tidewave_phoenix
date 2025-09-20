defmodule Tidewave do
  @moduledoc false
  @behaviour Plug

  @impl true
  def init(opts) do
    %{
      allowed_origins: Keyword.get(opts, :allowed_origins, nil),
      allow_remote_access: Keyword.get(opts, :allow_remote_access, false),
      phoenix_endpoint: nil,
      team: Keyword.get(opts, :team, []),
      inspect_opts:
        Keyword.get(opts, :inspect_opts, charlists: :as_lists, limit: 50, pretty: true)
    }
  end

  @impl true
  def call(%Plug.Conn{path_info: ["tidewave" | rest]} = conn, config) do
    config = %{config | phoenix_endpoint: conn.private[:phoenix_endpoint]}

    conn
    |> validate!()
    |> Plug.Conn.put_private(:tidewave_config, config)
    |> Plug.forward(rest, Tidewave.Router, [])
    |> Plug.Conn.halt()
  end

  def call(conn, _opts) do
    conn
    |> validate!()
    |> Plug.Conn.register_before_send(fn conn ->
      conn
      |> maybe_rewrite_csp()
      |> Plug.Conn.delete_resp_header("x-frame-options")
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
        [policy, directives] = String.split(policy_directive, " ", parts: 2),
        policy != "frame-ancestors" do
      if policy == "script-src" do
        case :binary.match(directives, "'unsafe-eval'") do
          :nomatch ->
            "#{policy} 'unsafe-eval' #{directives}"

          _ ->
            "#{policy} #{directives}"
        end
      else
        "#{policy} #{directives}"
      end
    end
    |> Enum.join("; ")
  end
end
