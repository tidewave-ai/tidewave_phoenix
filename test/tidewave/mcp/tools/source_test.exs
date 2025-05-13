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

    test "fuzzy suggestions" do
      assert {:error, "Did not find exact match. Did you mean: Tidewave.MCP"} =
               Source.get_source_location(%{"reference" => "Tidewav.MCP"})

      assert {:error, "Did not find exact match. Did you mean: Tidewave.MCP.init/1"} =
               Source.get_source_location(%{"reference" => "Tidewave.MCP.iniz"})

      assert {:error, "Did not find exact match. Did you mean: Tidewave.MCP.init/1"} =
               Source.get_source_location(%{"reference" => "Tidewave.MCP.init/2"})

      # finds aliases (prefers same project)
      assert {:error, "Did not find exact match. Did you mean: Tidewave.MCP.Tools.Source"} =
                Source.get_source_location(%{"reference" => "Source"})

      # prefers short matches (there's also Inspect.Plug.Conn)
      assert {:error, "Did not find exact match. Did you mean: Plug.Conn"} =
                  Source.get_source_location(%{"reference" => "Plug.Con"})
    end
  end

  describe "get_package_location/1" do
    test "returns all top-level dependencies" do
      result = Source.get_package_location(%{})
      assert {:ok, text} = result
      assert text =~ "plug"
      assert text =~ "req"
      refute text =~ "plug_crypto"
    end

    test "returns the location of a specific dependency" do
      result = Source.get_package_location(%{"package" => "plug_crypto"})
      assert {:ok, text} = result
      assert text =~ "deps/plug_crypto"
    end

    test "returns an error if the dependency is not found" do
      result = Source.get_package_location(%{"package" => "non_existent_dependency"})
      assert {:error, text} = result
      assert text =~ "Package non_existent_dependency not found"
      assert text =~ "The overall dependency path is #{Mix.Project.deps_path()}"
    end
  end
end
