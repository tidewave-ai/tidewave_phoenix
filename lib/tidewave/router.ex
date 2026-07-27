defmodule Tidewave.Router do
  @moduledoc false

  use Plug.Router

  import Plug.Conn
  alias Tidewave.MCP

  plug(:match)
  plug(:check_remote_ip)
  plug(:check_origin)
  plug(:dispatch)

  @allowed_upload_content_types ["image/png", "image/jpeg", "video/webm"]
  @allowed_upload_types ["screenshot", "recording"]

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, entrypoint_html())
    |> halt()
  end

  get "/connect" do
    conn
    |> put_resp_content_type("text/html")
    |> put_resp_header("content-security-policy", "base-uri 'self'; frame-ancestors 'self';")
    |> send_resp(200, control_html(conn))
    |> halt()
  end

  get "/config" do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("access-control-allow-origin", "*")
    |> send_resp(200, Jason.encode_to_iodata!(Tidewave.tidewave_config(conn)))
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

  post "/upload" do
    Logger.metadata(tidewave_mcp: true)

    opts =
      Plug.Parsers.init(
        parsers: [:multipart],
        pass: [],
        length: 200_000_000
      )

    conn
    |> Plug.Parsers.call(opts)
    |> handle_upload()
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
      # No origin header is always allowed
      {_, []} ->
        conn

      # GET / allows any origin
      {[], _} ->
        conn

      # /config contains metadata for discovery and it is safe to allow any origin
      {[no_check_origin], _} when no_check_origin in ["config"] ->
        conn

      # /ws and /upload are acessed from the web app and must have origins
      {[check_origin], [origin]} when check_origin in ["ws", "upload"] ->
        if valid_allowed_origin?(conn, URI.parse(origin)) do
          conn
        else
          log_and_send_403(conn, """
          For security reasons, Tidewave only accepts requests from the same origin your web app is running on.

          If you really want to allow remote connections, configure the Tidewave with the `allowed_origins: [#{inspect(origin)}]` option.
          """)
        end

      # /mcp and everything else fails if origin header is set
      {_, _} ->
        log_and_send_403(conn, """
        For security reasons, Tidewave does not accept requests with an origin header for this endpoint.
        """)
    end
  end

  defp valid_allowed_origin?(conn, origin) do
    allowed_origins =
      case conn.private.tidewave_config.allowed_origins do
        [_ | _] = allowed_origins -> allowed_origins
        _ -> [host_from_endpoint!(conn)]
      end

    Enum.any?(allowed_origins, &allowed_origin?(origin, parse_allowed_origin!(&1)))
  end

  defp host_from_endpoint!(conn) do
    case conn.private do
      %{tidewave_config: %{phoenix_endpoint: endpoint}} when not is_nil(endpoint) ->
        "//#{host_from_endpoint(endpoint)}"

      _ ->
        raise """
        no Phoenix endpoint found! You must manually configure the \
        allowed origins for Tidewave by setting the `:allowed_origins` \
        option on the Tidewave plug:

            plug Tidewave, allowed_origins: ["//localhost"]
        """
    end
  end

  defp host_from_endpoint(endpoint) do
    cond do
      function_exported?(endpoint, :struct_url, 0) ->
        endpoint.struct_url().host

      function_exported?(endpoint, :config, 1) ->
        endpoint.config(:url)[:host]

      true ->
        nil
    end || raise_missing_allowed_origins!()
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

  defp raise_missing_allowed_origins! do
    raise """
    Tidewave cannot verify the origin because no allowed origins are configured and no Phoenix endpoint URL host is available.

    Configure the Tidewave plug with `allowed_origins: [...]` to list allowed origins manually.
    """
  end

  defp log_and_send_403(conn, message) do
    require Logger
    Logger.warning(message)

    conn
    |> send_resp(403, message)
    |> halt()
  end

  defp entrypoint_html do
    client_url = Application.get_env(:tidewave, :client_url, "https://tidewave.ai")

    """
    <html>
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <script type="module" src="#{client_url}/tc/tc.js"></script>
      </head>
      <body></body>
    </html>
    """
  end

  defp control_html(conn) do
    client_url = Application.get_env(:tidewave, :client_url, "https://tidewave.ai")

    """
    <html>
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <meta name="tidewave:config" content="#{Tidewave.tidewave_config_meta(conn) |> Jason.encode!() |> Plug.HTML.html_escape()}" />
        <script type="module" src="#{client_url}/tc/control.js"></script>
      </head>
      <body></body>
    </html>
    """
  end

  defp handle_upload(conn) do
    with %{"type" => type, "file" => %Plug.Upload{} = upload}
         when type in @allowed_upload_types <- conn.body_params,
         true <- is_allowed_content_type?(upload) do
      tmp_dir = conn.private.tidewave_config.tmp_dir
      create_upload_dir!(tmp_dir, type)
      dest = upload_path(tmp_dir, type, upload.filename)
      File.cp!(upload.path, dest)

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(
        200,
        Jason.encode_to_iodata!(%{status: "ok", path: dest})
      )
    else
      _ ->
        conn
        |> send_resp(400, "Bad Request: missing or invalid file parameter")
    end
  end

  defp create_upload_dir!(tmp_dir, type) do
    File.mkdir_p!(upload_dir(tmp_dir, type))
  end

  defp upload_dir(tmp_dir, type) do
    tmp_dir
    |> Path.join("tidewave")
    |> Path.join(folder_for_type(type))
  end

  defp upload_path(tmp_dir, type, filename) do
    ext = filename |> Path.extname() |> String.downcase()

    cond do
      not String.match?(filename, ~r/^[A-Za-z0-9_.-]+$/) ->
        raise "filename must only contain numbers, letters, hyphens, and underscores: #{filename}"

      ext not in [".png", ".jpg", ".jpeg", ".webm"] ->
        raise "filename must have a valid extension (.png, .jpg, .jpeg, .webm): #{filename}"

      true ->
        Path.join(upload_dir(tmp_dir, type), filename)
    end
  end

  defp folder_for_type("screenshot"), do: "screenshots"
  defp folder_for_type("recording"), do: "recordings"

  defp is_allowed_content_type?(%Plug.Upload{content_type: content_type, path: path}) do
    # video/webm;codecs=vp9 -> we are only interested in video/webm
    [ct | _] = String.split(content_type, ";")
    file = File.open!(path, [:binary, :raw])
    magic_bytes = IO.binread(file, 128)
    File.close(file)

    ct in @allowed_upload_content_types and Tidewave.MagicBytes.type(magic_bytes) != :unknown
  end
end
