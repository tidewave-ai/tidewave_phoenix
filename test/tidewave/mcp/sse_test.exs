defmodule Tidewave.MCP.SSETest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  import ExUnit.CaptureLog

  alias Tidewave.MCP.Connection

  @moduletag :capture_log

  describe "handle_sse/1" do
    test "establishes SSE connection with correct headers" do
      conn =
        conn(:get, "/tidewave/mcp")
        |> Map.put(:scheme, :http)
        |> Map.put(:host, "localhost")
        |> Map.put(:port, 9000)

      # Start the SSE connection in a separate process to avoid blocking the test
      :proc_lib.spawn_link(fn -> Tidewave.call(conn, Tidewave.init([])) end)

      # Wait briefly for the connection to be established
      :timer.sleep(100)

      # Verify that a connection was established in the ETS table
      assert Registry.count(Tidewave.MCP.Registry) == 1
    end
  end

  describe "handle_message/1" do
    setup do
      sse_conn =
        conn(:get, "/tidewave/mcp?include_fs_tools=true")
        |> Map.put(:scheme, :http)
        |> Map.put(:host, "localhost")
        |> Map.put(:port, 9000)
        |> Plug.Conn.fetch_query_params()

      state_pid =
        :proc_lib.spawn_link(fn ->
          Tidewave.call(sse_conn, Tidewave.init([]))
        end)

      %{session_id: session_id} = :sys.get_state(state_pid)

      # Build a test connection for a POST to /message
      conn =
        conn(:post, "/tidewave/mcp/message", %{})
        |> Map.put(:query_params, %{"sessionId" => session_id})
        |> put_req_header("content-type", "application/json")

      %{conn: conn, session_id: session_id, state_pid: state_pid}
    end

    test "handles initialization message", %{conn: conn, state_pid: state_pid} do
      # First ensure the state is ready
      :ok = Connection.handle_initialize(state_pid)

      message = %{
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "id" => "1",
        "params" => %{
          "protocolVersion" => "2024-11-05",
          "capabilities" => %{
            "version" => "1.0"
          }
        }
      }

      conn = %{conn | body_params: message}
      response = Tidewave.call(conn, Tidewave.init([]))

      assert response.status == 202
      assert Jason.decode!(response.resp_body) == %{"status" => "ok"}
    end

    test "handles initialized notification", %{conn: conn, state_pid: state_pid} do
      # First ensure the state is initialized
      :ok = Connection.handle_initialize(state_pid)

      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      }

      conn = %{conn | body_params: message}
      response = Tidewave.call(conn, Tidewave.init([]))

      assert response.status == 202
      assert Jason.decode!(response.resp_body) == %{"status" => "ok"}
    end

    test "handles cancelled notification", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/cancelled",
        "params" => %{"reason" => "test"}
      }

      conn = %{conn | body_params: message}
      response = Tidewave.call(conn, Tidewave.init([]))

      assert response.status == 202
      assert Jason.decode!(response.resp_body) == %{"status" => "ok"}
    end

    test "returns error for missing session", %{conn: conn} do
      conn = Map.put(conn, :query_params, %{})

      log =
        capture_log([level: :warning], fn ->
          response = Tidewave.call(conn, Tidewave.init([]))

          assert response.status == 400
          assert Jason.decode!(response.resp_body) == %{"error" => "session_id is required"}
        end)

      assert log =~ "Missing session ID in request"
    end

    test "returns error for invalid session", %{conn: conn} do
      conn = Map.put(conn, :query_params, %{"sessionId" => ""})

      log =
        capture_log([level: :warning], fn ->
          response = Tidewave.call(conn, Tidewave.init([]))

          assert response.status == 400
          assert Jason.decode!(response.resp_body) == %{"error" => "Invalid session ID"}
        end)

      assert log =~ "Invalid session ID provided"
    end

    test "returns error for session not found", %{conn: conn} do
      conn = Map.put(conn, :query_params, %{"sessionId" => "nonexistent"})

      log =
        capture_log([level: :warning], fn ->
          response = Tidewave.call(conn, Tidewave.init([]))

          assert response.status == 404
          assert Jason.decode!(response.resp_body) == %{"error" => "Could not find session"}
        end)

      assert log =~ "Session not found: nonexistent"
    end

    test "returns error for invalid JSON-RPC message", %{conn: conn} do
      message = %{"invalid" => "message"}

      log =
        capture_log([level: :warning], fn ->
          conn = %{conn | body_params: message}
          response = Tidewave.call(conn, Tidewave.init([]))

          assert response.status == 200
          response_body = Jason.decode!(response.resp_body)
          assert response_body["error"]["code"] == -32600
          assert response_body["error"]["message"] == "Could not parse message"
        end)

      assert log =~ "Invalid JSON-RPC message format"
    end

    test "rescues / catches exceptions in tool calls", %{conn: conn, state_pid: state_pid} do
      :ok = Connection.handle_initialize(state_pid)

      assert %{status: 202, resp_body: ~s({"status":"ok"})} =
               Tidewave.call(
                 %{
                   conn
                   | body_params: %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}
                 },
                 Tidewave.init([])
               )

      assert %{status: 202, resp_body: ~s({"status":"ok"})} =
               Tidewave.call(
                 %{
                   conn
                   | body_params: %{
                       "jsonrpc" => "2.0",
                       "method" => "tools/call",
                       "id" => "23123",
                       "params" => %{
                         "name" => "project_eval",
                         "arguments" => %{"code" => "raise \"oops\""}
                       }
                     }
                 },
                 Tidewave.init([])
               )

      assert Process.alive?(state_pid)
    end
  end
end
