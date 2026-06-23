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
    if origin_allowed?(origin, conn.private.tidewave_config) do
      conn
    else
      log_and_send_403(conn, """
      For security reasons, the Tidewave control page only accepts WebSocket connections from the application's own origin.
      """)
    end
  end

  defp origin_allowed?(origin, config) do
    with {:ok, origin} <- normalize_origin(origin) do
      Enum.any?(allowed_ws_origins(config), &origin_matches?(origin, &1))
    else
      :error -> false
    end
  end

  defp origin_matches?(origin, {:origin, allowed_origin}) do
    origin == allowed_origin
  end

  defp origin_matches?(origin, {:host, allowed_host}) do
    origin.host == allowed_host
  end

  defp allowed_ws_origins(%{allowed_origins: [_ | _] = allowed_origins}) do
    Enum.map(allowed_origins, &allowed_origin_or_host/1)
  end

  defp allowed_ws_origins(%{phoenix_endpoint: endpoint}) when not is_nil(endpoint) do
    url_config = endpoint.config(:url)

    if host = url_config[:host] do
      [{:origin, endpoint_origin(url_config, host)}]
    else
      raise_missing_allowed_origins!()
    end
  end

  defp allowed_ws_origins(_config) do
    raise_missing_allowed_origins!()
  end

  defp allowed_origin_or_host(origin_or_host) do
    case normalize_origin(origin_or_host) do
      {:ok, origin} -> {:origin, origin}
      :error -> {:host, normalize_host(origin_or_host)}
    end
  end

  defp endpoint_origin(url_config, host) do
    scheme = url_config |> Keyword.get(:scheme, "http") |> to_string() |> String.downcase()
    port = url_config |> Keyword.get(:port, default_port(scheme)) |> normalize_port()

    %{scheme: scheme, host: normalize_host(host), port: port}
  end

  defp normalize_origin(origin) when is_binary(origin) do
    case URI.parse(origin) do
      %URI{scheme: scheme, host: host, port: port} when is_binary(scheme) and is_binary(host) ->
        scheme = String.downcase(scheme)

        {:ok,
         %{
           scheme: scheme,
           host: normalize_host(host),
           port: normalize_port(port || default_port(scheme))
         }}

      _ ->
        :error
    end
  end

  defp normalize_origin(_origin), do: :error

  defp normalize_host(host) when is_binary(host), do: String.downcase(host)
  defp normalize_host(host), do: host |> to_string() |> String.downcase()

  defp normalize_port(port) when is_integer(port), do: port

  defp normalize_port(port) when is_binary(port) do
    String.to_integer(port)
  end

  defp default_port("http"), do: 80
  defp default_port("https"), do: 443
  defp default_port(_scheme), do: nil

  defp raise_missing_allowed_origins! do
    raise """
    Tidewave cannot verify the WebSocket origin because no allowed origins are configured and no Phoenix endpoint URL origin is available.

    Configure the Tidewave plug with `allowed_origins: [...]` to list the origins or hosts that may open the control page.
    """
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

    # We return a basic page that is used by Tidewave Web.
    # Note that, by itself, this page is harmless and it
    # cannot invoke any of the MCP endpoints, since the MCP
    # refuses any requests with an Origin header.
    """
    <html>
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <script type="module" src="#{client_url}/tc/tc.js?entrypoint=control"></script>
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
