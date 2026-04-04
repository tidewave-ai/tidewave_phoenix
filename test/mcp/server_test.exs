defmodule Tidewave.MCP.ServerTest do
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
          allow_remote_access: false,
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
          "protocolVersion" => "2025-03-26",
          "capabilities" => %{
            "version" => "1.0"
          }
        }
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.Server.handle_http_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["jsonrpc"] == "2.0"
      assert response_body["id"] == "1"
      assert response_body["result"]["protocolVersion"] == "2025-03-26"
      assert is_list(response_body["result"]["tools"])
    end

    test "handles initialized notification", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.Server.handle_http_message(conn)

      assert response.status == 202
      assert response.resp_body == "{\"status\":\"ok\"}"
    end

    test "handles cancelled notification", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "notifications/cancelled",
        "params" => %{"reason" => "test"}
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.Server.handle_http_message(conn)

      assert response.status == 202
      assert response.resp_body == "{\"status\":\"ok\"}"
    end

    test "handles tools/list request", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => "2"
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.Server.handle_http_message(conn)

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
          response = Tidewave.MCP.Server.handle_http_message(conn)

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
      response = Tidewave.MCP.Server.handle_http_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["jsonrpc"] == "2.0"
      assert response_body["id"] == "3"
      assert response_body["result"]["content"]
    end

    test "handles prompts/list request", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "prompts/list",
        "id" => "4"
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.Server.handle_http_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["result"]["prompts"] == []
    end

    test "handles resources/list request", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "resources/list",
        "id" => "6"
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.Server.handle_http_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["result"]["resources"] == []
    end

    test "handles resources/templates/list request", %{conn: conn} do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "resources/templates/list",
        "id" => "10"
      }

      conn = %{conn | body_params: message}
      response = Tidewave.MCP.Server.handle_http_message(conn)

      assert response.status == 200
      response_body = Jason.decode!(response.resp_body)
      assert response_body["result"]["templates"] == []
    end
  end

  describe "register_tools/1" do
    test "registers a custom tool that can be called" do
      conn =
        conn(:post, "/tidewave/mcp", %{})
        |> put_req_header("content-type", "application/json")
        |> put_private(:tidewave_config, %{
          allow_remote_access: false,
          phoenix_endpoint: nil,
          inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]
        })
      tool = %{
        name: "test_custom_tool",
        description: "A test tool",
        inputSchema: %{type: "object", properties: %{msg: %{type: "string"}}},
        callback: fn args -> {:ok, "echo: #{args["msg"]}"} end
      }

      assert :ok = Tidewave.MCP.Server.register_tools([tool])

      # Verify tool appears in tools/list
      list_msg = %{
        "jsonrpc" => "2.0",
        "method" => "tools/list",
        "id" => "100"
      }

      conn = %{conn | body_params: list_msg}
      response = Tidewave.MCP.Server.handle_http_message(conn)
      response_body = Jason.decode!(response.resp_body)
      tool_names = Enum.map(response_body["result"]["tools"], & &1["name"])
      assert "test_custom_tool" in tool_names

      # Verify tool can be called
      call_msg = %{
        "jsonrpc" => "2.0",
        "method" => "tools/call",
        "id" => "101",
        "params" => %{
          "name" => "test_custom_tool",
          "arguments" => %{"msg" => "hello"}
        }
      }

      conn = conn(:post, "/tidewave/mcp", %{})
             |> put_req_header("content-type", "application/json")
             |> put_private(:tidewave_config, %{
               allow_remote_access: false,
               phoenix_endpoint: nil,
               inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]
             })
      conn = %{conn | body_params: call_msg}
      response = Tidewave.MCP.Server.handle_http_message(conn)
      response_body = Jason.decode!(response.resp_body)
      [content] = response_body["result"]["content"]
      assert content["text"] == "echo: hello"
    end

    test "skips duplicate tool names" do
      {tools_before, _} = Tidewave.MCP.Server.tools_and_dispatch()
      existing_name = hd(tools_before).name

      duplicate = %{
        name: existing_name,
        description: "Duplicate",
        inputSchema: %{},
        callback: fn _args -> {:ok, "should not replace"} end
      }

      assert :ok = Tidewave.MCP.Server.register_tools([duplicate])

      {tools_after, _} = Tidewave.MCP.Server.tools_and_dispatch()
      assert length(tools_after) == length(tools_before)
    end
  end
end
