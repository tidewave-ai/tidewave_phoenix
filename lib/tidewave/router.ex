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
    |> send_resp(200, tidewave_html(conn.private.tidewave_config))
    |> halt()
  end

  get "/config" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode_to_iodata!(config(conn.private.tidewave_config)))
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

  match "/*_ignored" do
    # Return 404 for /.well-known resources lookup and similar
    Logger.metadata(tidewave_mcp: true)

    conn
    |> send_resp(404, "Not Found")
    |> halt()
  end

  defp shell(port_init, args, conn) do
    args = [:exit_status, :binary, :hide, :use_stdio, :stderr_to_stdout, cd: MCP.root()] ++ args
    port = Port.open(port_init, args)

    conn =
      conn
      |> put_resp_content_type("application/octet-stream")
      |> send_chunked(200)
      |> halt()

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
        if validate_allowed_origin(conn, URI.parse(origin)) do
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
    allowed_origins = conn.private.tidewave_config.allowed_origins || [host_from_endpoint!(conn)]
    Enum.any?(allowed_origins, &allowed_origin?(origin, parse_allowed_origin!(&1)))
  end

  defp host_from_endpoint!(conn) do
    case conn.private do
      %{phoenix_endpoint: endpoint} ->
        "//#{endpoint.struct_url().host}"

      _ ->
        raise """
        no Phoenix endpoint found! You must manually configure the \
        allowed origins for Tidewave by setting the `:allowed_origins` \
        option on the Tidewave plug:

            plug Tidewave, allowed_origins: ["//localhost"]
        """
    end
  end

  defp parse_allowed_origin!(origin) do
    case URI.parse(origin) do
      %URI{host: nil} ->
        raise ArgumentError,
              "invalid :allowed_origins value: #{inspect(origin)}. " <>
                "Expected an origin with a host that is parsable by URI.parse/1. For example: " <>
                "[\"https://example.com\", \"//another.com:888\", \"//other.com\"]"

      %URI{} = uri ->
        uri
    end
  end

  defp allowed_origin?(origin, allowed) do
    compare?(origin.scheme, allowed.scheme) and
      compare?(origin.port, allowed.port) and
      compare_host?(origin.host, allowed.host)
  end

  defp compare?(request_val, allowed_val) do
    is_nil(allowed_val) or request_val == allowed_val
  end

  defp compare_host?(request_host, "*." <> allowed_host),
    do: request_host == allowed_host or String.ends_with?(request_host, "." <> allowed_host)

  defp compare_host?(request_host, allowed_host),
    do: request_host == allowed_host

  defp log_and_send_403(conn, message) do
    require Logger
    Logger.warning(message)

    conn
    |> send_resp(403, message)
    |> halt()
  end

  defp tidewave_html(plug_config) do
    client_url = Application.get_env(:tidewave, :client_url, "https://tidewave.ai")

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
        <meta name="tidewave:config" content="#{config(plug_config) |> Jason.encode!() |> Plug.HTML.html_escape()}" />
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

  defp config(plug_config) do
    %{
      project_name: MCP.project_name(),
      framework_type: "phoenix",
      tidewave_version: package_version(:tidewave),
      team: Map.new(plug_config.team)
    }
  end
end
