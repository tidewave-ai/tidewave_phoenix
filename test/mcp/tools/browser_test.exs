defmodule Tidewave.MCP.Tools.BrowserTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Browser

  @assigns %{url: "http://localhost:4000"}

  describe "browser_eval/2" do
    test "errors when code is given without a sid" do
      assert {:error, message} = Browser.browser_eval(%{"code" => "1+1"}, @assigns)
      assert message == "browser_eval requires a `sid` when `code` is not empty."
    end

    test "errors when code is given with a blank sid" do
      assert {:error, message} = Browser.browser_eval(%{"code" => "1+1", "sid" => ""}, @assigns)
      assert message == "browser_eval requires a `sid` when `code` is not empty."
    end
  end
end
