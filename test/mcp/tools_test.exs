defmodule Tidewave.MCP.ToolsTest do
  use ExUnit.Case, async: true

  test "tools have valid callbacks" do
    {_, dispatch_map} = Tidewave.MCP.Server.tools_and_dispatch()

    for {tool, callback} <- dispatch_map do
      assert is_function(callback, 1) or is_function(callback, 2),
             "#{tool} does not have a valid callback #{inspect(callback)}"
    end
  end

  test "tools are hidden from the list when excluded" do
    refute Enum.any?(
             Tidewave.MCP.Server.tools(
               {%{}, %{exclude_tools: ["project_eval"], include_tools: nil}}
             ),
             &(&1.name == "project_eval")
           )

    assert Enum.any?(
             Tidewave.MCP.Server.tools({%{}, %{exclude_tools: [], include_tools: nil}}),
             &(&1.name == "project_eval")
           )

    assert Enum.map(
             Tidewave.MCP.Server.tools(
               {%{}, %{include_tools: ["project_eval"], exclude_tools: []}}
             ),
             & &1.name
           ) == ["project_eval"]
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
