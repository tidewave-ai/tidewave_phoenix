defmodule Tidewave.MCP.Tools.SourceTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tool
  alias Tidewave.MCP.Tools.Source

  describe "get_source_location/1" do
    test "returns source code error handling" do
      {:error, message} =
        Tool.dispatch(
          Source.get_source_location_tool(),
          %{"reference" => "NonExistentModule"},
          Tidewave.init([])
        )

      assert message =~ "Failed to get source location"
    end

    test "handles valid module" do
      result =
        Tool.dispatch(
          Source.get_source_location_tool(),
          %{"reference" => "Tidewave"},
          Tidewave.init([])
        )
      assert {:ok, text} = result
      assert text =~ "tidewave.ex"
    end

    test "does not work for Elixir modules" do
      {:error, message} =
        Tool.dispatch(
          Source.get_source_location_tool(),
          %{"reference" => "Enum"},
          Tidewave.init([])
        )
      assert message =~ "Cannot get source of core libraries"
    end

    test "handles valid module and function" do
      result =
        Tool.dispatch(
          Source.get_source_location_tool(),
          %{
            "reference" => "Tidewave.MCP.Tools.Source.get_source_location"
          },
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "source.ex"
    end

    test "handles valid mfa" do
      result =
        Tool.dispatch(
          Source.get_source_location_tool(),
          %{
            "reference" => "Tidewave.MCP.Tools.Source.get_source_location/1"
          },
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "source.ex"
    end

    test "returns the doc location whenever possible" do
      {:ok, text} =
        Tool.dispatch(
          Source.get_source_location_tool(),
          %{"reference" => "Plug.forward"},
          Tidewave.init([])
        )

      [file, line] = String.split(text, ":")

      assert File.read!(file)
             |> String.split("\n")
             |> Enum.fetch!(String.to_integer(line) - 1) =~
               "@doc \"\"\""
    end
  end

  describe "get_source_location/1 with dep: prefix" do
    test "returns the location of a specific dependency" do
      result =
        Tool.dispatch(
          Source.get_source_location_tool(),
          %{"reference" => "dep:plug_crypto"},
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "deps/plug_crypto"
    end

    test "returns an error if the dependency is not found" do
      result =
        Tool.dispatch(
          Source.get_source_location_tool(),
          %{"reference" => "dep:non_existent_dependency"},
          Tidewave.init([])
        )

      assert {:error, text} = result
      assert text =~ "Package non_existent_dependency not found"
    end
  end

  describe "get_docs/1" do
    test "returns error for invalid arguments" do
      result = Tool.dispatch(Source.get_docs_tool(), %{}, Tidewave.init([]))
      assert {:error, _changeset} = result
    end

    test "returns error for invalid reference" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "invalid reference"},
          Tidewave.init([])
        )

      assert {:error, message} = result
      assert message =~ "Failed to parse reference"
    end

    test "returns error for non-existent module" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "NonExistentModule"},
          Tidewave.init([])
        )

      assert {:error, message} = result
      assert message =~ "Could not load module"
    end

    test "returns error for missing module documentation" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "Tidewave.MCP.Tools.Source"},
          Tidewave.init([])
        )

      assert {:error, message} = result
      assert message =~ "Documentation not found for Tidewave.MCP.Tools.Source"
    end

    test "returns error for missing function documentation" do
      assert Tool.dispatch(
               Source.get_docs_tool(),
               %{"reference" => "Tidewave.MCP.Tools.Source.get_docs/1"},
               Tidewave.init([])
             ) ==
               {:error, "Documentation not found for Tidewave.MCP.Tools.Source.get_docs/1"}
    end

    test "returns error for missing function documentation for all arities" do
      assert Tool.dispatch(
               Source.get_docs_tool(),
               %{"reference" => "Tidewave.MCP.Tools.Source.get_docs"},
               Tidewave.init([])
             ) ==
               {:error, "Documentation not found for Tidewave.MCP.Tools.Source.get_docs/*"}
    end

    test "handles modules" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "Plug.Conn"},
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "# Plug.Conn"
    end

    test "handles functions" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "Plug.Conn.put_status/2"},
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "# Plug.Conn.put_status/2"
    end

    test "handles Elixir modules" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "Enum"},
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "# Enum"
    end

    test "handles function with defaults" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "Enum.map/2"},
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "# Enum.map/2"
    end

    test "handles function with multiple arities" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "Enum.reduce"},
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "# Enum.reduce/2"
      assert text =~ "# Enum.reduce/3"
    end

    test "handles function with default" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "GenServer.call/2"},
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "# GenServer.call/3"
    end

    test "handles macro documentation" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "Kernel.def/2"},
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "# Kernel.def/2"
    end

    test "handles callback documentation" do
      result =
        Tool.dispatch(
          Source.get_docs_tool(),
          %{"reference" => "c:GenServer.handle_call/3"},
          Tidewave.init([])
        )

      assert {:ok, text} = result
      assert text =~ "# c:GenServer.handle_call/3"
    end
  end
end
