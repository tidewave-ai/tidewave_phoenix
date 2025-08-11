# This file is based on mcp_sse: https://github.com/kEND/mcp_sse
# Adapted from SSE transport to streamable HTTP transport for MCP 2025-03-06 and further
#
# MIT License
#
# Copyright (c) 2025 kEND
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

defmodule Tidewave.MCP.HTTP do
  @moduledoc false

  require Logger

  import Plug.Conn
  alias Tidewave.MCP.Server

  def handle_message(conn) do
    Logger.info("Received #{conn.method} message")
    params = conn.body_params
    conn = fetch_query_params(conn)
    Logger.debug("Raw params: #{inspect(params, pretty: true)}")

    case validate_jsonrpc_message(params) do
      {:ok, message} ->
        handle_jsonrpc_message(conn, message)

      {:error, :invalid_jsonrpc} ->
        Logger.warning("Invalid JSON-RPC message format")
        send_jsonrpc_error(conn, nil, -32600, "Could not parse message")
    end
  end

  defp handle_jsonrpc_message(conn, message) do
    # TODO: this will be removed when we fully deprecate/remove FS tools
    assigns = %{connect_params: conn.query_params}
    assigns = Map.merge(assigns, conn.private.tidewave_config)

    case message do
      # Handle initialization sequence
      %{"method" => "initialize"} = msg ->
        Logger.info("Routing MCP message - Method: initialize, ID: #{msg["id"]}")
        Logger.debug("Full message: #{inspect(msg, pretty: true)}")
        {:ok, response} = Server.handle_message(msg, assigns)

        conn |> put_status(200) |> send_json(response)

      %{"method" => "notifications/initialized"} ->
        send_resp(conn, 202, "")

      %{"method" => "notifications/cancelled"} ->
        # Just log the cancellation notification and return ok
        Logger.info("Request cancelled: #{inspect(message["params"])}")
        send_resp(conn, 202, "")

      # Handle requests
      _ when is_map_key(message, "id") ->
        handle_request(conn, message, assigns)

      # For any other notifications without id
      _ ->
        send_resp(conn, 202, "")
    end
  end

  defp handle_request(conn, message, assigns) do
    case Server.handle_message(message, assigns) do
      {:ok, nil} ->
        send_resp(conn, 202, "")

      {:ok, response} ->
        Logger.debug("Sending HTTP response: #{inspect(response, pretty: true)}")
        conn |> put_status(200) |> send_json(response)

      {:error, error_response} ->
        Logger.warning("Error handling message: #{inspect(error_response)}")
        conn |> put_status(400) |> send_json(error_response)
    end
  end

  defp send_json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end

  defp send_jsonrpc_error(conn, id, code, message, data \\ nil) do
    error = %{
      code: code,
      message: message
    }

    error = if data, do: Map.put(error, :data, data), else: error

    response = %{
      jsonrpc: "2.0",
      id: id,
      error: error
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  defp validate_jsonrpc_message(%{"jsonrpc" => "2.0"} = message) do
    cond do
      # Request must have method and id (string or number)
      Map.has_key?(message, "id") and Map.has_key?(message, "method") ->
        case message["id"] do
          id when is_binary(id) or is_number(id) -> {:ok, message}
          nil -> {:error, :invalid_jsonrpc}
          _ -> {:error, :invalid_jsonrpc}
        end

      # Notification must have method but no id
      not Map.has_key?(message, "id") and Map.has_key?(message, "method") ->
        {:ok, message}

      # reply (e.g. to ping) with ID + result
      Map.has_key?(message, "id") and Map.has_key?(message, "result") ->
        {:ok, message}

      true ->
        {:error, :invalid_jsonrpc}
    end
  end

  defp validate_jsonrpc_message(_), do: {:error, :invalid_jsonrpc}
end
