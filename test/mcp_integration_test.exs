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
             case Req.post("http://127.0.0.1:9100") do
               {:ok, _} -> {:halt, true}
               _ -> {:cont, false}
             end
           end),
           "server not listening"

    %{tools: initialize_and_get_tools(context[:query_params] || "include_fs_tools=true")}
  end

  test "does not include fs tools by default" do
    tools = initialize_and_get_tools()
    tool_names = Enum.map(tools, & &1["name"])

    refute "list_project_files" in tool_names
    refute "read_project_file" in tool_names
  end

  test "connects to HTTP endpoint and receives tools on initialize", %{tools: tools} do
    assert is_list(tools)
    assert tool_names = Enum.map(tools, & &1["name"])
    assert "list_project_files" in tool_names
  end

  test "write to file needs to be recent", %{tools: tools} do
    assert "write_project_file" in Enum.map(tools, & &1["name"])

    on_exit(fn ->
      File.rm("test.txt")
    end)

    File.write!("test.txt", "Hello, world!")

    write_id = System.unique_integer([:positive])

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => write_id,
        "method" => "tools/call",
        "params" => %{
          "name" => "write_project_file",
          "arguments" => %{"path" => "test.txt", "content" => "Hello, world!", "atime" => 0}
        }
      })

    assert response["id"] == write_id
    assert response["result"]["isError"] == true
    assert hd(response["result"]["content"])["text"] =~ "File has been modified"

    read_id = System.unique_integer([:positive])
    mtime = File.stat!("test.txt", time: :posix).mtime + 1

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => read_id,
        "method" => "tools/call",
        "params" => %{
          "name" => "read_project_file",
          "arguments" => %{"path" => "test.txt", "atime" => mtime}
        }
      })

    assert response["id"] == read_id
    assert [%{"text" => "Hello, world!"}] = response["result"]["content"]

    write_try2 = System.unique_integer([:positive])

    response =
      send_http_request(%{
        "jsonrpc" => "2.0",
        "id" => write_try2,
        "method" => "tools/call",
        "params" => %{
          "name" => "write_project_file",
          "arguments" => %{"path" => "test.txt", "content" => "Hello, world! again"}
        }
      })

    assert response["id"] == write_try2
    assert response["result"]["content"] == [%{"text" => "Success!", "type" => "text"}]

    assert "Hello, world! again" = File.read!("test.txt")
  end

  test "fs tools return mtime as metadata" do
    on_exit(fn ->
      File.rm("test.txt")
    end)

    File.write!("test.txt", "Hello, world!")

    write_id = System.unique_integer([:positive])

    response =
      send_http_request(%{
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

    assert response["id"] == write_id
    assert response["result"]["content"] == [%{"text" => "Success!", "type" => "text"}]
    mtime = response["result"]["_meta"]["mtime"]

    assert "Hello, world! again" = File.read!("test.txt")
    assert mtime == File.stat!("test.txt", time: :posix).mtime
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
        "params" => %{"name" => "list_project_files"}
      })

    assert response["id"] == id
    assert response["result"]
  end

  ### helpers

  defp initialize_and_get_tools(query_params \\ nil) do
    url = if is_nil(query_params), do: @base_url, else: @base_url <> "?" <> query_params

    response =
      send_http_request(
        %{
          "jsonrpc" => "2.0",
          "id" => "init",
          "method" => "initialize",
          "params" => %{
            "protocolVersion" => "2025-03-06",
            "capabilities" => %{}
          }
        },
        url
      )

    assert response["jsonrpc"] == "2.0"
    assert response["id"] == "init"
    assert response["result"]["tools"]

    response["result"]["tools"]
  end

  defp send_http_request(message, url \\ @base_url <> "?include_fs_tools=true") do
    {:ok, http_response} = Req.post(url, json: message)
    assert http_response.body

    http_response.body
  end
end
