# This file is based on mcp_sse: https://github.com/kEND/mcp_sse
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

defmodule Tidewave.MCP.SSE do
  @moduledoc false

  require Logger

  import Plug.Conn
  alias Tidewave.MCP.Connection
  alias Tidewave.MCP.Server

  def handle_sse(conn) do
    session_id = generate_session_id()
    conn = fetch_query_params(conn)

    conn
    |> setup_sse_connection()
    |> send_initial_message(session_id)
    |> enter_loop(session_id)
  end

  def handle_message(conn) do
    Logger.info("Received POST message")
    params = conn.body_params
    Logger.debug("Raw params: #{inspect(params, pretty: true)}")

    with {:ok, session_id} <- get_session_id(conn),
         {:ok, connection_pid} <- lookup_session(session_id),
         {:ok, message} <- validate_jsonrpc_message(params) do
      # Record client activity
      Connection.record_activity(connection_pid)

      # Handle initialization sequence
      case message do
        %{"method" => "initialize"} = msg ->
          Logger.info("Routing MCP message - Method: initialize, ID: #{msg["id"]}")
          Logger.debug("Full message: #{inspect(msg, pretty: true)}")
          Connection.handle_initialize(connection_pid)

          case Tidewave.MCP.Server.handle_message(msg, connection_pid) do
            {:ok, response} ->
              Logger.debug("Sending SSE response: #{inspect(response, pretty: true)}")
              Connection.send_sse_message(connection_pid, response)
              conn |> put_status(202) |> send_json(%{status: "ok"})
          end

        %{"method" => "notifications/initialized"} ->
          Connection.handle_initialized(connection_pid)
          conn |> put_status(202) |> send_json(%{status: "ok"})

        %{"method" => "notifications/cancelled"} ->
          # Just log the cancellation notification and return ok
          Logger.info("Request cancelled: #{inspect(message["params"])}")
          conn |> put_status(202) |> send_json(%{status: "ok"})

        %{"id" => id, "result" => _} ->
          case Connection.handle_result(connection_pid, id) do
            :ok ->
              conn |> put_status(202) |> send_json(%{status: "ok"})

            {:error, :not_found} ->
              Logger.warning("Request not found: #{inspect(message)}")
              send_jsonrpc_error(conn, id, -32601, "Request not found")
          end

        _ ->
          if not Map.has_key?(message, "id") do
            conn |> put_status(202) |> send_json(%{status: "ok"})
          else
            # Handle requests that expect responses
            # TODO: we can always directly reply with 202 Accepted here, the response
            # is sent over the SSE connection
            case Server.handle_message(message, connection_pid) do
              {:ok, nil} ->
                conn |> put_status(202) |> send_json(%{status: "ok"})

              {:ok, response} ->
                Logger.debug("Sending SSE response: #{inspect(response, pretty: true)}")
                Connection.send_sse_message(connection_pid, response)
                conn |> put_status(202) |> send_json(%{status: "ok"})

              {:error, error_response} ->
                Logger.warning("Error handling message: #{inspect(error_response)}")
                # Send error response via SSE to match JSON-RPC 2.0 spec
                Connection.send_sse_message(connection_pid, error_response)
                # we still reply with 202, because some clients abort the connection
                # when they receive a non-200 response
                conn |> put_status(202) |> send_json(%{status: "ok"})
            end
          end
      end
    else
      {:error, :missing_session} ->
        Logger.warning("Missing session ID in request")
        send_error(conn, 400, "session_id is required")

      {:error, :invalid_session} ->
        Logger.warning("Invalid session ID provided")
        send_error(conn, 400, "Invalid session ID")

      {:error, :session_not_found} ->
        Logger.warning("Session not found: #{conn.query_params["sessionId"]}")
        send_error(conn, 404, "Could not find session")

      {:error, :invalid_jsonrpc} ->
        Logger.warning("Invalid JSON-RPC message format")
        send_jsonrpc_error(conn, nil, -32600, "Could not parse message")
    end
  end

  defp send_json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end

  defp send_error(conn, status, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(%{error: message}))
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

  defp setup_sse_connection(conn) do
    conn
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("content-type", "text/event-stream; charset=utf-8")
    |> send_chunked(200)
  end

  defp send_initial_message(conn, session_id) do
    endpoint =
      "#{conn.scheme}://#{conn.host}:#{conn.port}/tidewave/mcp/message?sessionId=#{session_id}"

    case chunk(conn, "event: endpoint\ndata: #{endpoint}\n\n") do
      {:ok, conn} -> conn
      {:error, _reason} -> conn
    end
  end

  defp enter_loop(conn, session_id) do
    try do
      Registry.register(Tidewave.MCP.Registry, session_id, [])
      Connection.init({session_id, conn})
    catch
      :exit, :normal -> conn
      :exit, :shutdown -> conn
      :exit, {:shutdown, _} -> conn
    after
      # Bandit re-uses the same process for new requests,
      # therefore we need to unregister manually and clear
      # any pending messages from the inbox
      Registry.unregister(Tidewave.MCP.Registry, session_id)
      clear_inbox()
      send(self(), {:plug_conn, :sent})
    end
  end

  defp clear_inbox do
    receive do
      _ -> clear_inbox()
    after
      0 -> :ok
    end
  end

  defp get_session_id(conn) do
    case conn.query_params do
      %{"sessionId" => ""} -> {:error, :invalid_session}
      %{"sessionId" => session_id} -> {:ok, session_id}
      _ -> {:error, :missing_session}
    end
  end

  defp lookup_session(session_id) do
    case Registry.lookup(Tidewave.MCP.Registry, session_id) do
      [{connection_pid, _}] -> {:ok, connection_pid}
      [] -> {:error, :session_not_found}
    end
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

  defp generate_session_id do
    <<i1::32, i2::32, i3::32>> = :crypto.strong_rand_bytes(12)

    :io_lib.format("~8.16.0b-~8.16.0b-~8.16.0b", [i1, i2, i3])
    |> List.to_string()
  end
end
