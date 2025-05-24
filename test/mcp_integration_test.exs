defmodule Tidewave.MCPIntegrationTest do
  use ExUnit.Case, async: false
  require Logger

  @base_url "http://localhost:9100/tidewave/mcp?include_fs_tools=true"

  @moduletag :capture_log

  setup context do
    start_supervised!(
      {Bandit, plug: {Tidewave, context[:plug_opts] || []}, port: 9100, startup_log: false},
      shutdown: 10
    )

    assert Stream.interval(10)
           |> Stream.take(10)
           |> Enum.reduce_while(nil, fn _, _ ->
             case Req.post("http://127.0.0.1:9100") do
               {:ok, _} -> {:halt, true}
               _ -> {:cont, false}
             end
           end),
           "server not listening"

    %{request: connect_and_initialize(context[:base_url] || @base_url)}
  end

  @tag base_url: "http://localhost:9100/tidewave/mcp"
  test "does not include fs tools by default", %{request: request} do
    assert %{tools: tools} = request
    assert is_list(tools)

    tool_names = Enum.map(tools, & &1["name"])

    refute "list_project_files" in tool_names
    refute "shell_eval" in tool_names
  end

  test "connects to SSE endpoint and receives tools on initialize", %{request: request} do
    assert %{tools: tools} = request
    assert is_list(tools)
    assert tool_names = Enum.map(tools, & &1["name"])
    assert "list_project_files" in tool_names
  end

  @tag plug_opts: [tools: [exclude: [:write_project_file]]]
  test "can exclude tools via plug opts", %{request: request} do
    assert %{tools: tools} = request
    assert is_list(tools)
    assert tool_names = Enum.map(tools, & &1["name"])
    assert "list_project_files" in tool_names
    refute "write_project_file" in tool_names
  end

  test "write to file needs read first", %{request: request} do
    assert %{resp: resp, endpoint_url: endpoint_url, tools: tools} = request
    assert "write_project_file" in Enum.map(tools, & &1["name"])

    on_exit(fn ->
      File.rm("test.txt")
    end)

    File.write!("test.txt", "Hello, world!")

    write_id = System.unique_integer([:positive])

    send_message(endpoint_url, %{
      "jsonrpc" => "2.0",
      "id" => write_id,
      "method" => "tools/call",
      "params" => %{
        "name" => "write_project_file",
        "arguments" => %{"path" => "test.txt", "content" => "Hello, world!"}
      }
    })

    assert %{
             data: %{
               "id" => ^write_id,
               "result" => %{
                 "isError" => true,
                 "content" => [
                   %{
                     "text" =>
                       "File has not been read yet. Use read_project_file first to before overwriting it!"
                   }
                 ]
               }
             }
           } = receive_sse_message(resp)

    read_id = System.unique_integer([:positive])

    send_message(endpoint_url, %{
      "jsonrpc" => "2.0",
      "id" => read_id,
      "method" => "tools/call",
      "params" => %{
        "name" => "read_project_file",
        "arguments" => %{"path" => "test.txt"}
      }
    })

    assert %{
             data: %{"id" => ^read_id, "result" => %{"content" => [%{"text" => "Hello, world!"}]}}
           } = receive_sse_message(resp)

    write_try2 = System.unique_integer([:positive])

    send_message(endpoint_url, %{
      "jsonrpc" => "2.0",
      "id" => write_try2,
      "method" => "tools/call",
      "params" => %{
        "name" => "write_project_file",
        "arguments" => %{"path" => "test.txt", "content" => "Hello, world! again"}
      }
    })

    assert %{
             data: %{
               "id" => ^write_try2,
               "result" => %{
                 "content" => [
                   %{"text" => "Success!", "type" => "text"}
                 ]
               }
             }
           } = receive_sse_message(resp)

    assert "Hello, world! again" = File.read!("test.txt")
  end

  test "fs tools return mtime as metadata", %{request: request} do
    assert %{resp: resp, endpoint_url: endpoint_url} = request

    on_exit(fn ->
      File.rm("test.txt")
    end)

    File.write!("test.txt", "Hello, world!")

    write_id = System.unique_integer([:positive])

    send_message(endpoint_url, %{
      "jsonrpc" => "2.0",
      "id" => write_id,
      "method" => "tools/call",
      "params" => %{
        "name" => "write_project_file",
        "arguments" => %{
          "path" => "test.txt",
          "content" => "Hello, world! again",
          "atime" => File.stat!("test.txt", time: :posix).mtime
        }
      }
    })

    assert %{
             data: %{
               "id" => ^write_id,
               "result" => %{
                 "content" => [
                   %{"text" => "Success!", "type" => "text"}
                 ],
                 "_meta" => %{
                   "mtime" => mtime
                 }
               }
             }
           } = receive_sse_message(resp)

    assert "Hello, world! again" = File.read!("test.txt")
    assert mtime == File.stat!("test.txt", time: :posix).mtime
  end

  test "stores logs but ignores logs from MCP itself", %{request: request} do
    assert %{resp: resp, endpoint_url: endpoint_url, tools: tools} = request

    assert "get_logs" in Enum.map(tools, & &1["name"])

    Logger.info("hello from test!")

    id = System.unique_integer([:positive])

    # execute a code that logs
    send_message(endpoint_url, %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "tools/call",
      "params" => %{
        "name" => "project_eval",
        "arguments" => %{"code" => "require Logger; Logger.info(\"hello from MCP!\")"}
      }
    })

    assert %{data: %{"id" => ^id, "result" => %{}}} = receive_sse_message(resp)

    id = System.unique_integer([:positive])

    send_message(endpoint_url, %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "tools/call",
      "params" => %{
        "name" => "get_logs",
        "arguments" => %{"tail" => 10}
      }
    })

    assert %{
             data: %{
               "id" => ^id,
               "result" => %{
                 "content" => [
                   %{"text" => text}
                 ]
               }
             }
           } = receive_sse_message(resp)

    assert text =~ "hello from test"
    refute text =~ "hello from MCP"
  end

  test "standard JSON-RPC error for invalid arguments", %{request: request} do
    assert %{resp: resp, endpoint_url: endpoint_url} = request
    id = System.unique_integer([:positive])

    send_message(endpoint_url, %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "tools/call",
      "params" => %{
        "name" => "get_logs",
        "arguments" => %{"foo" => 10}
      }
    })

    assert %{
             data: %{
               "id" => ^id,
               "error" => %{
                 "code" => -32602,
                 "message" => "Invalid arguments for tool"
               }
             }
           } = receive_sse_message(resp)
  end

  test "does not expect arguments to be given", %{request: request} do
    assert %{resp: resp, endpoint_url: endpoint_url} = request
    id = System.unique_integer([:positive])

    send_message(endpoint_url, %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "tools/call",
      "params" => %{"name" => "list_project_files"}
    })

    assert %{
             data: %{
               "id" => ^id,
               "result" => %{}
             }
           } = receive_sse_message(resp)
  end

  ### helpers

  defp connect_and_initialize(base_url) do
    {:ok, resp} = connect_to_sse(base_url)
    assert %{event: "endpoint", data: endpoint_url} = receive_sse_message(resp, false)
    init_id = System.unique_integer([:positive])

    send_message(endpoint_url, %{
      "jsonrpc" => "2.0",
      "id" => init_id,
      "method" => "initialize",
      "params" => %{"protocolVersion" => "2024-11-05", "capabilities" => %{}}
    })

    assert %{data: %{"id" => ^init_id, "result" => %{"tools" => tools}}} =
             receive_sse_message(resp)

    %{resp: resp, endpoint_url: endpoint_url, tools: tools}
  end

  defp connect_to_sse(sse_url) do
    # Start the SSE connection in the current process
    # With into: :self, this doesn't block - it returns immediately
    # and events will be delivered to the process mailbox
    resp =
      Req.get!(
        sse_url,
        headers: [{"accept", "text/event-stream"}],
        # Stream events directly to the calling process
        into: :self,
        receive_timeout: :infinity,
        retry: false
      )

    # Return the response for later cancellation
    {:ok, resp}
  end

  defp receive_sse_message(resp, decode_json \\ true, timeout \\ 5000) do
    assert {:ok, [data: data]} =
             Req.parse_message(
               resp,
               receive do
                 data -> data
               after
                 timeout -> :timeout
               end
             )

    case String.split(data, "\n", trim: true) do
      ["event: " <> event, "data: " <> data] ->
        %{event: event, data: if(decode_json, do: Jason.decode!(data), else: data)}

      _ ->
        raise "Unexpected SSE message format: #{data}"
    end
  end

  defp send_message(endpoint_url, message) do
    Req.post!(
      endpoint_url,
      json: message,
      headers: [
        {"accept", "application/json"},
        {"content-type", "application/json"}
      ]
    )
  end
end
