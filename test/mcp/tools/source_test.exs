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

  describe "get_docs/1" do
    test "returns error for invalid arguments" do
      result = Source.get_docs(%{})
      assert {:error, :invalid_arguments} = result
    end

    test "returns error for invalid reference" do
      result = Source.get_docs(%{"reference" => "invalid reference"})
      assert {:error, message} = result
      assert message =~ "Failed to parse reference"
    end

    test "returns error for non-existent module" do
      result = Source.get_docs(%{"reference" => "NonExistentModule"})
      assert {:error, message} = result
      assert message =~ "Could not load module"
    end

    test "returns error for missing module documentation" do
      result = Source.get_docs(%{"reference" => "Tidewave.MCP.Tools.Source"})
      assert {:error, message} = result
      assert message =~ "Documentation not found for Tidewave.MCP.Tools.Source"
    end

    test "returns error for missing function documentation" do
      assert Source.get_docs(%{"reference" => "Tidewave.MCP.Tools.Source.get_docs/1"}) ==
               {:error, "Documentation not found for Tidewave.MCP.Tools.Source.get_docs/1"}
    end

    test "returns error for missing function documentation for all arities" do
      assert Source.get_docs(%{"reference" => "Tidewave.MCP.Tools.Source.get_docs"}) ==
               {:error, "Documentation not found for Tidewave.MCP.Tools.Source.get_docs/*"}
    end

    test "handles modules" do
      result = Source.get_docs(%{"reference" => "Plug.Conn"})
      assert {:ok, text} = result
      assert text =~ "# Plug.Conn"
    end

    test "handles functions" do
      result = Source.get_docs(%{"reference" => "Plug.Conn.put_status/2"})
      assert {:ok, text} = result
      assert text =~ "# Plug.Conn.put_status/2"
    end

    test "handles Elixir modules" do
      result = Source.get_docs(%{"reference" => "Enum"})
      assert {:ok, text} = result
      assert text =~ "# Enum"
    end

    test "handles function with defaults" do
      result = Source.get_docs(%{"reference" => "Enum.map/2"})
      assert {:ok, text} = result
      assert text =~ "# Enum.map/2"
    end

    test "handles function with multiple arities" do
      result = Source.get_docs(%{"reference" => "Enum.reduce"})
      assert {:ok, text} = result
      assert text =~ "# Enum.reduce/2"
      assert text =~ "# Enum.reduce/3"
    end

    test "handles function with default" do
      result = Source.get_docs(%{"reference" => "GenServer.call/2"})
      assert {:ok, text} = result
      assert text =~ "# GenServer.call/3"
    end

    test "handles macro documentation" do
      result = Source.get_docs(%{"reference" => "Kernel.def/2"})
      assert {:ok, text} = result
      assert text =~ "# Kernel.def/2"
    end
  end
end
