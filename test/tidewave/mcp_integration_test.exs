defmodule Tidewave.MCPIntegrationTest do
  use ExUnit.Case, async: false
  require Logger

  @base_url "http://localhost:9100/tidewave/mcp"

  @moduletag :capture_log

  setup context do
    start_supervised!(
      {Bandit, plug: {Tidewave, context[:plug_opts] || []}, port: 9100, startup_log: false},
      shutdown: 10
    )

    assert Stream.interval(10)
           |> Stream.take(10)
           |> Enum.reduce_while(nil, fn _, _ ->
             case ping_server("http://127.0.0.1:9100") do
               :ok -> {:halt, true}
               _ -> {:cont, false}
             end
           end),
           "server not listening"

    %{tools: initialize_and_get_tools()}
  end

  test "connects to HTTP endpoint and receives tools on initialize", %{tools: tools} do
    assert is_list(tools)
    assert tool_names = Enum.map(tools, & &1["name"])
    assert "get_logs" in tool_names
  end

  test "stores logs but ignores logs from MCP itself", %{tools: tools} do
    assert "get_logs" in Enum.map(tools, & &1["name"])

    Logger.info("hello from test!")

    id = System.unique_integer([:positive])

    # execute a code that logs
    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "tools/call",
        "params" => %{
          "name" => "project_eval",
          "arguments" => %{"code" => "require Logger; Logger.info(\"hello from MCP!\")"}
        }
      })

    assert response["id"] == id
    assert response["result"]

    id = System.unique_integer([:positive])

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "tools/call",
        "params" => %{
          "name" => "get_logs",
          "arguments" => %{"tail" => 10}
        }
      })

    assert response["id"] == id
    assert [%{"text" => text}] = response["result"]["content"]

    assert text =~ "hello from test"
    refute text =~ "hello from MCP"
  end

  test "standard JSON-RPC error for invalid arguments" do
    id = System.unique_integer([:positive])

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "tools/call",
        "params" => %{
          "name" => "get_logs",
          "arguments" => %{"foo" => 10}
        }
      })

    assert response["id"] == id
    assert response["error"]["code"] == -32602
    assert response["error"]["message"] == "Invalid arguments for tool"
  end

  test "does not expect arguments to be given" do
    id = System.unique_integer([:positive])

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => "tools/call",
        "params" => %{"name" => "get_ecto_schemas"}
      })

    assert response["id"] == id
    assert response["result"]
  end

  ### helpers

  defp initialize_and_get_tools() do
    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => "init",
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => "2025-03-26",
          "capabilities" => %{}
        }
      })

    assert response["jsonrpc"] == "2.0"
    assert response["id"] == "init"
    assert response["result"]["tools"]

    response["result"]["tools"]
  end

  defp send_http_request(message) do
    {:ok, body} = post_json(@base_url, message)
    body
  end

  defp ping_server(url) do
    case :httpc.request(String.to_charlist(url)) do
      {:ok, _response} -> :ok
      error -> error
    end
  end

  defp post_json(url, message) do
    headers = [{~c"content-type", ~c"application/json"}]
    body = Jason.encode!(message)
    request = {String.to_charlist(url), headers, ~c"application/json", body}

    case :httpc.request(:post, request, [], body_format: :binary) do
      {:ok, {{_http_version, _status, _reason_phrase}, _headers, response_body}} ->
        {:ok, Jason.decode!(response_body)}

      error ->
        error
    end
  end
end
