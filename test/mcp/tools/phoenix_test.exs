# Create a mock LiveView module for testing
defmodule Phoenix.LiveView.Socket do
  defstruct [:assigns, :view]
end

defmodule Tidewave.MCP.Tools.PhoenixTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Phoenix

  describe "tools/0" do
    test "returns list of available tools" do
      tools = Phoenix.tools()

      assert is_list(tools)
      assert length(tools) == 1
      assert Enum.any?(tools, &(&1.name == "list_liveview_pages"))
    end
  end

  describe "list_liveview_pages/1" do
    test "returns a formatted list of LiveView channels" do
      # The actual implementation depends on running LiveView processes
      # which is difficult to test, so we'll just verify the function runs
      # and returns the expected format
      assert {:ok, "There are no LiveView processes connected!"} =
               Phoenix.list_liveview_pages(%{}, Tidewave.init([]))

      parent = self()

      pid =
        spawn_link(fn ->
          {:ok, lv_pid} =
            Agent.start_link(fn ->
              Process.put(:"$initial_call", {FakeLiveView, :mount, []})

              %{socket: %Elixir.Phoenix.LiveView.Socket{view: __MODULE__, assigns: %{}}}
            end)

          send(parent, {:ready, lv_pid})
        end)

      Process.register(pid, __MODULE__.Phoenix.LiveView.Socket)

      lv_pid =
        receive do
          {:ready, lv_pid} -> lv_pid
        end

      {:ok, text} = Phoenix.list_liveview_pages(%{}, Tidewave.init([]))

      assert text =~ inspect(lv_pid)
      assert text =~ "view: Tidewave.MCP.Tools.PhoenixTest"
    end
  end
end
