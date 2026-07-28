defmodule Tidewave.MCP.Tools.BrowserTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Browser

  @assigns %{url: "http://localhost:4000"}

  describe "browser_eval/2" do
    test "errors when eval action is given without a sid" do
      assert {:error, message} =
               Browser.browser_eval(%{"action" => "eval", "code" => "1+1"}, @assigns)

      assert message == ~s|browser_eval requires a "sid" for action "eval".|
    end

    test "errors when eval action is given with a blank sid" do
      assert {:error, message} =
               Browser.browser_eval(%{"action" => "eval", "code" => "1+1", "sid" => ""}, @assigns)

      assert message == ~s|browser_eval requires a "sid" for action "eval".|
    end

    test "errors when help action finds no connected browser" do
      assert {:error, message} = Browser.browser_eval(%{"action" => "help"}, @assigns)

      assert message ==
               "No browser is connected to the Tidewave control page. " <>
                 "Open http://localhost:4000/tidewave in your browser and try again."
    end
  end
end
