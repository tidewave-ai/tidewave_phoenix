defmodule Tidewave.MCP.Tools.LogsTest do
  use ExUnit.Case, async: true

  require Logger
  alias Tidewave.MCP.Tools.Logs

  describe "tools/0" do
    test "returns list of available tools" do
      tools = Logs.tools()

      assert is_list(tools)
      assert length(tools) == 1
      assert Enum.any?(tools, &(&1.name == "get_logs"))
    end
  end

  describe "get_logs/2" do
    test "returns the logged content" do
      Logger.info("hello darkness my old friend")
      {:ok, logs} = Logs.get_logs(%{"tail" => 10})
      assert logs =~ "hello darkness my old friend"
    end

    test "filters by level" do
      Logger.debug("this will not be seen")
      Logger.error("hello darkness my old friend")
      {:ok, logs} = Logs.get_logs(%{"tail" => 10, "level" => "info"})
      assert logs =~ "hello darkness my old friend"
      refute logs =~ "this will not be seen"
    end
  end
end
