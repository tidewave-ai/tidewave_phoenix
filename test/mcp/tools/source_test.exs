defmodule Tidewave.MCP.Tools.SourceTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Source

  describe "get_source_location/1" do
    test "returns source code error handling" do
      {:error, message} =
        Source.get_source_location(%{"reference" => "NonExistentModule"})

      assert message =~ "Failed to get source location"
    end

    test "handles valid module" do
      result = Source.get_source_location(%{"reference" => "Tidewave"})
      assert {:ok, text} = result
      assert text =~ "tidewave.ex"
    end

    test "does not work for Elixir modules" do
      {:error, message} = Source.get_source_location(%{"reference" => "Enum"})
      assert message =~ "Cannot get source of core libraries"
    end

    test "handles valid module and function" do
      result =
        Source.get_source_location(%{
          "reference" => "Tidewave.MCP.Tools.Source.get_source_location"
        })

      assert {:ok, text} = result
      assert text =~ "source.ex"
    end

    test "handles valid mfa" do
      result =
        Source.get_source_location(%{
          "reference" => "Tidewave.MCP.Tools.Source.get_source_location/1"
        })

      assert {:ok, text} = result
      assert text =~ "source.ex"
    end
  end
end
