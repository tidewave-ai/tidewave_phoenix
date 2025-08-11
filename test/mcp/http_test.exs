defmodule Tidewave.MCP.HTTPTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn
  import ExUnit.CaptureLog

  @moduletag :capture_log

  describe "handle_message/1" do
    setup do
      # Create a simple conn with the needed configuration
      conn =
        conn(:post, "/tidewave/mcp?include_fs_tools=true", %{})
        |> put_req_header("content-type", "application/json")
        |> put_private(:tidewave_config, %{
          allowed_origins: nil,
          allow_remote_access: false,
          sse_keepalive_timeout: 15_000,
          phoenix_endpoint: nil,
          inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]
        })

      %{conn: conn}
    end

    test "handles initialization message", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "id" => "1",
        "params" => %{
          "protocolVersion" => "2025-03-06",
          "capabilities" => %{
            "version" => "1.0"
          }
        }
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.HTTP.handle_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["jsonrpc"] == "2.0"
      assert response_body["id"] == "1"
      assert response_body["result"]["protocolVersion"] == "2025-03-06"
      assert is_list(response_body["result"]["tools"])
    end

    test "handles initialized notification", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.HTTP.handle_message(conn)

      assert response.status == 202
      assert response.resp_body == ""
    end

    test "handles cancelled notification", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/cancelled",
        "params" => %{"reason" => "test"}
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.HTTP.handle_message(conn)

      assert response.status == 202
      assert response.resp_body == ""
    end

    test "handles tools/list request", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => "2"
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.HTTP.handle_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["jsonrpc"] == "2.0"
      assert response_body["id"] == "2"
      assert is_list(response_body["result"]["tools"])
    end

    test "returns error for invalid JSON-RPC message", %{conn: conn} do
      message = %{"invalid" => "message"}

      log =
        capture_log([level: :warning], fn ->
          conn = %{conn | body_params: message}
          response = Tidewave.MCP.HTTP.handle_message(conn)

          assert response.status == 200
          response_body = Jason.decode!(response.resp_body)
          assert response_body["error"]["code"] == -32600
          assert response_body["error"]["message"] == "Could not parse message"
        end)

      assert log =~ "Invalid JSON-RPC message format"
    end

    test "handles tool calls", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => "3",
        "params" => %{
          "name" => "project_eval",
          "arguments" => %{"code" => "1 + 1"}
        }
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.HTTP.handle_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["jsonrpc"] == "2.0"
      assert response_body["id"] == "3"
      assert response_body["result"]["content"]
    end
  end
end
