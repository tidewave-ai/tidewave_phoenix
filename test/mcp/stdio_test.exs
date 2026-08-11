defmodule Tidewave.MCP.StdioTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Stdio

  test "reads and writes unicode" do
    message = %{
      "jsonrpc" => "2.0",
      "method" => "tools/call",
      "id" => "zażółć 👋",
      "params" => %{
        "name" => "project_eval",
        "arguments" => %{"code" => ~S|"cześć 🌊"|}
      }
    }

    {:ok, stdio} = StringIO.open(Jason.encode!(message) <> "\n")

    assert :ok = Stdio.run(stdio)
    assert {_input, output} = StringIO.contents(stdio)

    assert %{
             "id" => "zażółć 👋",
             "result" => %{
               "content" => [%{"type" => "text", "text" => ~S|"cześć 🌊"|}]
             }
           } = Jason.decode!(output)
  end

  test "replies with a parse error for invalid JSON" do
    {:ok, stdio} = StringIO.open("not json\n")

    assert :ok = Stdio.run(stdio)
    assert {_input, output} = StringIO.contents(stdio)

    assert %{"id" => nil, "error" => %{"code" => -32700, "message" => "Parse error"}} =
             Jason.decode!(output)
  end

  test "does not expose browser tools" do
    message = Jason.encode!(%{"jsonrpc" => "2.0", "method" => "tools/list", "id" => 1})
    {:ok, stdio} = StringIO.open(message <> "\n")

    assert :ok = Stdio.run(stdio)
    assert {_input, output} = StringIO.contents(stdio)

    response = Jason.decode!(output)
    refute "browser_eval" in Enum.map(response["result"]["tools"], & &1["name"])
  end
end
