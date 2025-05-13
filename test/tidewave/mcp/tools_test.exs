defmodule Tidewave.MCP.ToolsTest do
  use ExUnit.Case, async: true

  test "tools have valid callbacks" do
    {_, dispatch_map} = Tidewave.MCP.Server.tools_and_dispatch()

    for {tool, callback} <- dispatch_map do
      assert is_function(callback, 1) or is_function(callback, 2),
             "#{tool} does not have a valid callback #{inspect(callback)}"
    end
  end

  test "fs tools have listable callback" do
    tools = Tidewave.MCP.Tools.FS.tools()

    for tool <- tools do
      assert is_function(tool.listable, 1),
             "fs tool #{tool.name} does not have a listable callback"

      assert tool.listable.(%{"include_fs_tools" => true}) == true
      assert tool.listable.(%{}) == false
    end
  end
end
