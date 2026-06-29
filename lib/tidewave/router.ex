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
    conn = fetch_query_params(conn)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, tidewave_html(conn.query_params))
    |> halt()
  end

  get "/config" do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("access-control-allow-origin", "*")
    |> send_resp(200, Jason.encode_to_iodata!(config(conn)))
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

  get "/ws" do
    conn
    |> WebSockAdapter.upgrade(Tidewave.ControlSocket, %{}, timeout: 60_000)
    |> halt()
  end

  match "/*_ignored" do
    # Return 404 for /.well-known resources lookup and similar
    Logger.metadata(tidewave_mcp: true)

    conn
    |> send_resp(404, "Not Found")
    |> halt()
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
    case {conn.path_info, get_req_header(conn, "origin")} do
      # GET / allows any origin
      {[], _} ->
        conn

      # /config contains metadata for discovery and it is safe to allow any origin
      {["config"], _} ->
        conn

      # The control page WebSocket is the one endpoint that legitimately
      # receives an Origin header (browsers always send it on WebSocket
      # upgrades), so it gets a same-origin check instead.
      {["ws"], origin} ->
        check_ws_origin(conn, origin)

      # No origin header is always allowed
      {_, []} ->
        conn

      # /mcp refuses if origin header is set
      {_, _} ->
        log_and_send_403(conn, """
        For security reasons, Tidewave does not accept requests with an origin header for this endpoint.
        """)
    end
  end

  defp check_ws_origin(conn, []), do: conn

  defp check_ws_origin(conn, [origin | _]) do
    if origin_host(origin) in allowed_origin_hosts(conn.private.tidewave_config) do
      conn
    else
      log_and_send_403(conn, """
      For security reasons, the Tidewave control page only accepts WebSocket connections from the application's own origin.
      """)
    end
  end

  defp origin_host(origin) do
    URI.parse(origin).host
  end

  defp allowed_origin_hosts(%{allowed_origins: [_ | _] = allowed_origins}) do
    Enum.map(allowed_origins, &origin_or_host_to_host/1)
  end

  defp allowed_origin_hosts(%{phoenix_endpoint: endpoint}) when not is_nil(endpoint) do
    if host = endpoint.config(:url)[:host] do
      [host]
    else
      raise_missing_allowed_origins!()
    end
  end

  defp allowed_origin_hosts(_config) do
    raise_missing_allowed_origins!()
  end

  defp origin_or_host_to_host(origin_or_host) do
    case URI.parse(origin_or_host) do
      %URI{host: host} when is_binary(host) -> host
      _ -> origin_or_host
    end
  end

  defp raise_missing_allowed_origins! do
    raise """
    Tidewave cannot verify the WebSocket origin because no allowed origins are configured and no Phoenix endpoint URL host is available.

    Configure the Tidewave plug with `allowed_origins: [...]` to list the hosts that may open the control page.
    """
  end

  defp log_and_send_403(conn, message) do
    require Logger
    Logger.warning(message)

    conn
    |> send_resp(403, message)
    |> halt()
  end

  defp tidewave_html(params) do
    client_url = Application.get_env(:tidewave, :client_url, "https://tidewave.ai")

    script =
      case params do
        %{"entrypoint" => _} -> "tc.js"
        _ -> "control.js"
      end

    # We return a basic page that is used by Tidewave Web.
    # Note that, by itself, this page is harmless and it
    # cannot invoke any of the MCP endpoints, since the MCP
    # refuses any requests with an Origin header.
    """
    <html>
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <script type="module" src="#{client_url}/tc/#{script}"></script>
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

  defp config(conn) do
    plug_config = conn.private.tidewave_config

    %{
      project_name: MCP.project_name(),
      framework_type: "phoenix",
      tidewave_version: package_version(:tidewave),
      team: Map.new(plug_config.team),
      local_port: get_sock_data(conn).port
    }
  end
end
