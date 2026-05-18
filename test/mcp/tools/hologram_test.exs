defmodule Tidewave.MCP.Tools.HologramTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Hologram

  describe "tools/0" do
    test "returns [] when Hologram.Reflection is not loaded" do
      # tidewave does not depend on :hologram, so the guard short-circuits.
      # Integration coverage for the populated branch belongs in a downstream
      # project that depends on both packages.
      refute Code.ensure_loaded?(Hologram.Reflection)
      assert Hologram.tools() == []
    end
  end

  describe "dispatch_command/2 (input validation)" do
    # These exercise the input-validation paths that don't require Hologram
    # to be loaded — they fail before any reflection call.

    test "returns an error string when required args are missing" do
      assert {:error, "module and command are required"} =
               Hologram.dispatch_command(%{}, %{inspect_opts: []})
    end

    test "returns an error when the module string is unparseable" do
      assert {:error, "Unknown module: " <> _} =
               Hologram.dispatch_command(
                 %{"module" => "not a module", "command" => "noop"},
                 %{inspect_opts: []}
               )
    end

    test "returns an error when the command atom does not exist" do
      assert {:error, "Unknown atom: " <> _} =
               Hologram.dispatch_command(
                 %{
                   "module" => "Tidewave.MCP.Tools.HologramTest",
                   "command" => "definitely_not_an_existing_atom_xyz123"
                 },
                 %{inspect_opts: []}
               )
    end

    test "returns an error when the module does not export command/3" do
      assert {:error, msg} =
               Hologram.dispatch_command(
                 %{
                   "module" => "Tidewave.MCP.Tools.HologramTest",
                   "command" => "tools"
                 },
                 %{inspect_opts: []}
               )

      assert msg =~ "does not define a `command/3` callback"
    end
  end
end
