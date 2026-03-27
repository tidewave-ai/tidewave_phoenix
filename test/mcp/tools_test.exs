defmodule Tidewave.MCP.ToolsTest do
  use ExUnit.Case, async: true

  test "tools have valid callbacks" do
    {_, dispatch_map} = Tidewave.MCP.Server.tools_and_dispatch()

    for {tool, {callback, recompile}} <- dispatch_map do
      assert is_function(callback, 1) or is_function(callback, 2),
             "#{tool} does not have a valid callback #{inspect(callback)}"

      assert is_boolean(recompile),
             "#{tool} does not have a valid recompile flag #{inspect(recompile)}"
    end
  end
end
