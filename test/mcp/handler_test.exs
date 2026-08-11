defmodule Tidewave.MCP.HandlerTest do
  use ExUnit.Case, async: true

  @moduletag :capture_log

  alias Tidewave.MCP.Handler

  test "tools have valid callbacks" do
    {_, dispatch_map} = Tidewave.MCP.Handler.tools_and_dispatch(true)

    for {tool, callback} <- dispatch_map do
      assert is_function(callback, 1) or is_function(callback, 2),
             "#{tool} does not have a valid callback #{inspect(callback)}"
    end
  end

  describe "handle_message/3" do
    test "handles a decoded message without a transport" do
      message = %{
        "jsonrpc" => "2.0",
        "method" => "initialize",
        "id" => 1,
        "params" => %{"protocolVersion" => "2025-03-26"}
      }

      assert {:reply, response} = Handler.handle_message(message, tidewave_config())

      assert response.id == 1
      assert response.result.protocolVersion == "2025-03-26"
      assert "browser_eval" in Enum.map(response.result.tools, & &1.name)
    end

    test "accepts handler options" do
      message = %{"jsonrpc" => "2.0", "method" => "tools/list", "id" => 2}

      assert {:reply, response} =
               Handler.handle_message(message, tidewave_config(), include_browser_tools: false)

      refute "browser_eval" in Enum.map(response.result.tools, & &1.name)
    end

    test "validates JSON-RPC independently of a transport" do
      assert {:reply, response} =
               Handler.handle_message(%{"invalid" => "message"}, tidewave_config())

      assert response.error == %{code: -32600, message: "Could not parse message"}
    end

    test "identifies notifications" do
      message = %{"jsonrpc" => "2.0", "method" => "notifications/initialized"}

      assert :notification = Handler.handle_message(message, tidewave_config())
    end

    test "identifies errors while handling valid requests" do
      message = %{"jsonrpc" => "2.0", "method" => "unknown", "id" => 3}

      assert {:error, response} = Handler.handle_message(message, tidewave_config())
      assert response.error.code == -32601
    end
  end

  defp tidewave_config do
    %{
      allow_remote_access: false,
      phoenix_endpoint: nil,
      inspect_opts: [charlists: :as_lists, limit: 50, pretty: true]
    }
  end
end
