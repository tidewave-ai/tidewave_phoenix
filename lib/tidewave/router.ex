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

  get "/mcp" do
    Logger.metadata(tidewave_mcp: true)

    conn
    |> MCP.SSE.handle_sse()
    |> halt()
  end

  post "/mcp" do
    conn
    |> send_resp(405, "Method not allowed")
    |> halt()
  end

  post "/mcp/message" do
    Logger.metadata(tidewave_mcp: true)

    opts =
      Plug.Parsers.init(
        parsers: [:json],
        pass: [],
        json_decoder: Jason
      )

    conn
    |> Plug.Parsers.call(opts)
    |> MCP.SSE.handle_message()
    |> halt()
  end

  defp check_remote_ip(conn, _opts) do
    cond do
      is_local?(conn.remote_ip) ->
        conn

      conn.private.tidewave_config.allow_remote_access ->
        conn

      true ->
        conn
        |> send_resp(403, """
        For security reasons, Tidewave does not accept remote connections by default.

        If you really want to allow remote connections, configure the Tidewave with the `allow_remote_access: true` option.
        """)
        |> halt()
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
          conn |> send_resp(403, "Forbidden") |> halt()
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

  defp tidewave_html() do
    client_url = Application.get_env(:tidewave, :client_url, "https://tidewave.ai")

    credentials = Application.get_env(:tidewave, :credentials, [])
    credentials = Keyword.merge(default_credentials(), credentials)

    config = %{
      credentials: Map.new(credentials),
      framework: %{
        type: "phoenix"
      }
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

  defp default_credentials() do
    credentials = [
      anthropic: System.get_env("ANTHROPIC_API_KEY"),
      openai: System.get_env("OPENAI_API_KEY"),
      google: System.get_env("GOOGLE_AI_API_KEY")
    ]

    Enum.filter(credentials, fn {_key, value} -> value end)
  end
end
