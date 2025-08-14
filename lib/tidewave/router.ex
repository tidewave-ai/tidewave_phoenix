defmodule Tidewave.Router do
  @moduledoc false

  use Plug.Router

  import Plug.Conn
  alias Tidewave.MCP

  plug(:match)
  plug(:check_remote_ip)
  plug(:check_origin)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, tidewave_html())
    |> halt()
  end

  get "/empty" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, "")
    |> halt()
  end

  get "/mcp" do
    Logger.metadata(tidewave_mcp: true)

    # For GET requests, return 405 Method Not Allowed 
    # (Tidewave doesn't need to support SSE streaming)
    conn
    |> send_resp(405, "Method Not Allowed")
    |> halt()
  end

  post "/mcp" do
    Logger.metadata(tidewave_mcp: true)

    opts =
      Plug.Parsers.init(
        parsers: [:json],
        pass: [],
        json_decoder: Jason
      )

    conn
    |> Plug.Parsers.call(opts)
    |> MCP.Server.handle_http_message()
    |> halt()
  end

  post "/shell" do
    # Finding shell command logic from :os.cmd in OTP
    # https://github.com/erlang/otp/blob/8deb96fb1d017307e22d2ab88968b9ef9f1b71d0/lib/kernel/src/os.erl#L184
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        %{"command" => cmd} = Jason.decode!(body)

        case :os.type() do
          {:unix, _} ->
            shell_path = :os.find_executable(~c"sh") || raise "missing sh"
            shell({:spawn_executable, shell_path}, [args: ["-c", "(#{cmd}\n)"]], conn)

          {:win32, osname} ->
            cmd =
              case {System.get_env("COMSPEC"), osname} do
                {nil, :windows} -> ~c"cmd.com /s /c #{cmd}"
                {nil, _} -> ~c"cmd /s /c #{cmd}"
                {comspec, _} -> ~c"#{comspec} /s /c #{cmd}"
              end

            shell({:spawn, cmd}, [], conn)
        end

      _ ->
        raise "request body too large"
    end
  end

  defp shell(port_init, args, conn) do
    args = [:exit_status, :binary, :hide, :use_stdio, :stderr_to_stdout] ++ args
    port = Port.open(port_init, args)

    conn =
      conn
      |> put_resp_content_type("application/octet-stream")
      |> send_chunked(200)

    shell(port, conn)
  end

  defp shell(port, conn) do
    receive do
      {^port, {:data, ""}} ->
        shell(port, conn)

      {^port, {:data, data}} ->
        {:ok, conn} = chunk(conn, [0, <<byte_size(data)::32-unsigned-integer-big>>, data])
        shell(port, conn)

      {^port, {:exit_status, status}} ->
        data = ~s|{"status":#{status}}|
        {:ok, conn} = chunk(conn, [1, <<byte_size(data)::32-unsigned-integer-big>>, data])
        conn
    end
  end

  defp check_remote_ip(conn, _opts) do
    cond do
      is_local?(conn.remote_ip) ->
        conn

      conn.private.tidewave_config.allow_remote_access ->
        conn

      true ->
        log_and_send_403(conn, """
        For security reasons, Tidewave does not accept remote connections by default.

        If you really want to allow remote connections, configure the Tidewave with the `allow_remote_access: true` option.
        """)
    end
  end

  defp is_local?({127, 0, 0, _}), do: true
  defp is_local?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  # ipv4 mapped ipv6 address ::ffff:127.0.0.1
  defp is_local?({0, 0, 0, 0, 0, 65535, 32512, 1}), do: true
  defp is_local?(_), do: false

  defp check_origin(conn, _opts) do
    case get_req_header(conn, "origin") do
      [origin] ->
        if validate_allowed_origin(conn, origin) do
          conn
        else
          log_and_send_403(conn, """
          For security reasons, Tidewave only accepts requests from the same origin your web app is running on.

          If you really want to allow remote connections, configure the Tidewave with the `allowed_origins: [#{inspect(origin)}]` option.
          """)
        end

      [] ->
        # no origin is fine, as it means the request is NOT from a browser
        # e.g. Cursor, Claude Code, etc.
        conn
    end
  end

  defp validate_allowed_origin(conn, origin) do
    case conn.private.tidewave_config.allowed_origins do
      nil ->
        validate_origin_from_endpoint!(conn, origin)

      allowed_origins ->
        origin in allowed_origins
    end
  end

  defp validate_origin_from_endpoint!(conn, origin) do
    case conn.private do
      %{phoenix_endpoint: endpoint} ->
        origin == endpoint.url()

      _ ->
        raise """
        no Phoenix endpoint found! You must manually configure the \
        allowed origins for Tidewave by setting the `:allowed_origins` \
        option on the Tidewave plug:

            plug Tidewave, allowed_origins: ["http://localhost:4000"]
        """
    end
  end

  defp log_and_send_403(conn, message) do
    require Logger
    Logger.warning(message)

    conn
    |> send_resp(403, message)
    |> halt()
  end

  defp tidewave_html() do
    client_url = Application.get_env(:tidewave, :client_url, "https://tidewave.ai")

    config = %{
      project_name: MCP.project_name(),
      framework_type: "phoenix",
      tidewave_version: package_version(:tidewave)
    }

    # We return a basic page that loads script from Tidewave server to
    # bootstrap the client app. Note that the script name does not
    # include a hash, since is is very small and its main purpose is
    # to fetch the latest assets, those include the hash and can be
    # cached.
    """
    <html>
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="tidewave:config" content="#{config |> Jason.encode!() |> Plug.HTML.html_escape()}" />
        <script type="module" src="#{client_url}/tc/tc.js"></script>
      </head>
      <body></body>
    </html>
    """
  end

  defp package_version(app) do
    if vsn = Application.spec(app)[:vsn] do
      List.to_string(vsn)
    end
  end
end
