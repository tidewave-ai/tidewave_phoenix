defmodule Tidewave.MCP.Tools.BrowserTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Browser

  @assigns %{url: "http://localhost:4000"}

  describe "browser_eval/2" do
    test "errors when no sid is given and no browser is connected" do
      assert {:error, message} = Browser.browser_eval(%{"action" => "help"}, @assigns)

      assert message =~
               "No browser is connected to the Tidewave control page. Use the `open` command"
    end

    test "broadcasts when the sid is blank" do
      assert {:error, message} =
               Browser.browser_eval(%{"action" => "eval", "sid" => ""}, @assigns)

      assert message =~ "No browser is connected"
    end
  end
end
