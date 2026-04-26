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
    @tag :capture_log
    test "returns the logged content" do
      Logger.info("hello darkness my old friend")
      {:ok, logs} = Logs.get_logs(%{"tail" => 10})
      assert logs =~ "hello darkness my old friend"
    end

    @tag :capture_log
    test "returns the logged content with Unicode" do
      Logger.info(~c"こんにちは世界")
      {:ok, logs} = Logs.get_logs(%{"tail" => 10})
      assert logs =~ "こんにちは世界"
    end

    @tag :capture_log
    test "filters by grep" do
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

    @tag :capture_log
    test "filters by log level" do
      Logger.debug("debug message")
      Logger.info("info message")
      Logger.warning("warning message")
      Logger.error("error message")

      {:ok, logs} = Logs.get_logs(%{"tail" => 10, "level" => "error"})
      assert logs =~ "error message"
      refute logs =~ "debug message"
      refute logs =~ "info message"
      refute logs =~ "warning message"

      {:ok, logs} = Logs.get_logs(%{"tail" => 10, "level" => "warning"})
      assert logs =~ "warning message"
      refute logs =~ "debug message"
      refute logs =~ "info message"
      refute logs =~ "error message"
    end

    @tag :capture_log
    test "combines level and grep filters" do
      Logger.error("database connection failed")
      Logger.error("timeout waiting for response")
      Logger.warning("database connection slow")

      {:ok, logs} = Logs.get_logs(%{"tail" => 10, "level" => "error", "grep" => "database"})
      assert logs =~ "database connection failed"
      refute logs =~ "timeout waiting for response"
      refute logs =~ "database connection slow"
    end
  end
end
