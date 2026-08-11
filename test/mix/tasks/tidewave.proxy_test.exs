defmodule Mix.Tasks.Tidewave.ProxyTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  setup do
    start_supervised!(
      {Bandit, plug: {Tidewave, inspect_opts: [base: :hex]}, port: 9101, startup_log: false},
      shutdown: 10
    )

    :ok
  end

  test "proxies MCP requests over stdio" do
    output =
      run_task([
        %{
          "jsonrpc" => "2.0",
          "method" => "initialize",
          "id" => 1,
          "params" => %{"protocolVersion" => "2025-03-26"}
        },
        %{"jsonrpc" => "2.0", "method" => "notifications/initialized"},
        %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "id" => 2,
          "params" => %{
            "name" => "project_eval",
            "arguments" => %{"code" => "255", "port" => 9101}
          }
        },
        %{
          "jsonrpc" => "2.0",
          "method" => "tools/call",
          "id" => 3,
          "params" => %{
            "name" => "project_eval",
            "arguments" => %{"code" => "1 + 1"}
          }
        }
      ])

    assert [initialize, tool_call, missing_port] = decode_lines(output)

    assert initialize["id"] == 1
    assert initialize["result"]["protocolVersion"] == "2025-03-26"

    assert "browser_eval" in Enum.map(initialize["result"]["tools"], & &1["name"])

    assert Enum.all?(initialize["result"]["tools"], fn tool ->
             tool["inputSchema"]["properties"]["port"] == %{
               "type" => "integer",
               "description" => "The port of the Tidewave HTTP server handling this tool call"
             } and "port" in tool["inputSchema"]["required"]
           end)

    assert tool_call["id"] == 2
    assert tool_call["result"]["content"] == [%{"type" => "text", "text" => "0xFF"}]

    assert missing_port["id"] == 3

    assert missing_port["error"] == %{
             "code" => -32602,
             "message" => "Invalid port argument for tool"
           }
  end

  test "can exclude browser tools" do
    output =
      run_task(
        [
          %{
            "jsonrpc" => "2.0",
            "method" => "initialize",
            "id" => 1,
            "params" => %{"protocolVersion" => "2025-03-26"}
          }
        ],
        ["--no-browser-tools"]
      )

    assert [initialize] = decode_lines(output)
    refute "browser_eval" in Enum.map(initialize["result"]["tools"], & &1["name"])
  end

  defp run_task(messages, args \\ []) do
    input = Enum.map_join(messages, "\n", &Jason.encode!/1)
    {:ok, stdio} = StringIO.open(input <> "\n")
    original_group_leader = Process.group_leader()
    Process.group_leader(self(), stdio)

    try do
      assert :ok =
               Mix.Task.rerun("tidewave.proxy", ["--no-logger-redirect" | args])

      {_input, output} = StringIO.contents(stdio)
      output
    after
      Process.group_leader(self(), original_group_leader)
      StringIO.close(stdio)
    end
  end

  defp decode_lines(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end
end
