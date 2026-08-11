defmodule Tidewave.MCP.HTTP do
  @moduledoc false

  require Logger

  import Plug.Conn

  alias Tidewave.MCP.Handler

  def handle_message(conn) do
    Logger.info("Received #{conn.method} message")
    message = conn.body_params
    conn = fetch_query_params(conn)
    include_browser_tools? = conn.query_params["include_browser_tools"] != "false"

    case Handler.handle_message(message, conn.private.tidewave_config,
           include_browser_tools: include_browser_tools?
         ) do
      :notification ->
        conn |> put_status(202) |> send_json(%{status: "ok"})

      {:reply, response} ->
        conn |> put_status(200) |> send_json(response)

      {:error, error_response} ->
        conn |> put_status(400) |> send_json(error_response)
    end
  end

  defp send_json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end
end
