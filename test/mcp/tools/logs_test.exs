defmodule Tidewave.MCP.Tools.LogsTest do
  use ExUnit.Case, async: true

  require Logger
  alias Tidewave.MCP.Tools.Logs

  describe "tools/0" do
    test "returns list of available tools" do
      tools = Logs.tools()

      assert is_list(tools)
      assert length(tools) == 2
      assert Enum.any?(tools, &(&1.name == "get_logs"))
      assert Enum.any?(tools, &(&1.name == "clear_logs"))
    end
  end

  describe "get_logs/2" do
    @tag :capture_log
    test "returns the logged content" do
      Logger.info("hello darkness my old friend")
      {:ok, logs} = Logs.get_logs(%{"tail" => 10})
      assert logs =~ "hello darkness my old friend"
    end

    @tag :capture_log
    test "filters by level" do
      Logger.debug("this will not be seen")
      Logger.error("hello darkness my old friend")

      {:ok, logs} = Logs.get_logs(%{"tail" => 10, "grep" => "darkness"})
      assert logs =~ "hello darkness my old friend"
      refute logs =~ "this will not be seen"

      {:ok, logs} = Logs.get_logs(%{"tail" => 10, "grep" => "darkness|seen"})
      assert logs =~ "hello darkness my old friend"
      assert logs =~ "this will not be seen"

      {:ok, logs} = Logs.get_logs(%{"tail" => 10, "grep" => "DARKNESS|seen"})
      assert logs =~ "hello darkness my old friend"
      assert logs =~ "this will not be seen"
    end
  end

  describe "clear_logs/1" do
    @tag :capture_log
    test "clears all logs" do
      Logger.info("log before clear")
      {:ok, logs} = Logs.get_logs(%{"tail" => 10})
      assert logs =~ "log before clear"

      {:ok, message} = Logs.clear_logs(%{})
      assert message == "Logs cleared"

      {:ok, logs} = Logs.get_logs(%{"tail" => 10})
      refute logs =~ "log before clear"
      assert logs == ""
    end

    @tag :capture_log
    test "allows fresh logs after clearing" do
      Logger.info("old log")
      {:ok, _} = Logs.clear_logs(%{})
      Logger.info("new log")

      {:ok, logs} = Logs.get_logs(%{"tail" => 10})
      refute logs =~ "old log"
      assert logs =~ "new log"
    end
  end
end
