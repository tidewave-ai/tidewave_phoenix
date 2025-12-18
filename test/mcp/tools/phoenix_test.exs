defmodule Tidewave.MCP.Tools.PhoenixTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Phoenix

  describe "tools/0" do
    test "returns list of 2 tools" do
      tools = Phoenix.tools()
      assert length(tools) == 2

      tool_names = Enum.map(tools, & &1.name)
      assert "get_module_functions" in tool_names
      assert "get_component_info" in tool_names
    end
  end

  describe "get_module_functions/1" do
    test "returns error for invalid arguments" do
      assert {:error, :invalid_arguments} = Phoenix.get_module_functions(%{})
    end

    test "returns error for non-existent module" do
      result = Phoenix.get_module_functions(%{"module" => "NonExistentModule"})
      assert {:error, message} = result
      assert message =~ "not found" or message =~ "Could not load"
    end

    test "returns functions for a valid module" do
      {:ok, text} = Phoenix.get_module_functions(%{"module" => "SampleApp.Accounts"})

      assert text =~ "SampleApp.Accounts"
      assert text =~ "get_user!"
      assert text =~ "list_users"
      assert text =~ "create_user"
      assert text =~ "update_user"
      assert text =~ "delete_user"
    end

    test "does not include private functions" do
      {:ok, text} = Phoenix.get_module_functions(%{"module" => "SampleApp.Blog"})

      assert text =~ "list_posts"
      assert text =~ "get_post!"
      assert text =~ "create_post"
      refute text =~ "validate_post"
    end

    test "works with Elixir standard library modules" do
      {:ok, text} = Phoenix.get_module_functions(%{"module" => "Enum"})

      assert text =~ "Enum"
      assert text =~ "map"
      assert text =~ "reduce"
      assert text =~ "filter"
    end

    test "works with dependency modules" do
      {:ok, text} = Phoenix.get_module_functions(%{"module" => "Jason"})

      assert text =~ "Jason"
      assert text =~ "encode"
      assert text =~ "decode"
    end
  end

  describe "get_component_info/1" do
    test "returns error for invalid arguments" do
      assert {:error, :invalid_arguments} = Phoenix.get_component_info(%{})
    end

    test "returns error for invalid reference format" do
      result = Phoenix.get_component_info(%{"component" => "InvalidFormat"})
      assert {:error, message} = result
      assert message =~ "Invalid component reference"
    end

    test "returns component info with attrs and slots" do
      {:ok, text} = Phoenix.get_component_info(%{"component" => "SampleAppWeb.CoreComponents.modal"})

      # Check header
      assert text =~ "SampleAppWeb.CoreComponents.modal"

      # Check attrs
      assert text =~ "Attributes"
      assert text =~ "`id`"
      assert text =~ ":string"
      assert text =~ "required"
      assert text =~ "`show`"
      assert text =~ ":boolean"

      # Check slots
      assert text =~ "Slots"
      assert text =~ "`inner_block`"
    end

    test "returns component info for button with multiple attrs" do
      {:ok, text} = Phoenix.get_component_info(%{"component" => "SampleAppWeb.CoreComponents.button"})

      assert text =~ "`type`"
      assert text =~ "`variant`"
      assert text =~ "`disabled`"
      assert text =~ "`class`"
    end

    test "returns component info for input with form field attr" do
      {:ok, text} = Phoenix.get_component_info(%{"component" => "SampleAppWeb.CoreComponents.input"})

      assert text =~ "`field`"
      assert text =~ "Phoenix.HTML.FormField"
      assert text =~ "required"
    end

    test "handles component without attrs gracefully" do
      {:ok, text} = Phoenix.get_component_info(%{"component" => "SampleAppWeb.ComponentWithoutAttrs.simple"})

      assert text =~ "SampleAppWeb.ComponentWithoutAttrs.simple"
      assert text =~ "No attributes defined"
    end
  end
end
