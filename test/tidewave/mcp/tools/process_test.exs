defmodule Tidewave.MCP.Tools.ProcessTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Process, as: ProcessTool

  defp dead_pid do
    parent = self()
    pid = spawn(fn -> receive(do: (_ -> send(parent, :ok))) end)
    send(pid, :ok)

    receive do
      :ok -> :ok
    end

    pid
  end

  describe "tools/0" do
    test "returns list of available tools" do
      tools = ProcessTool.tools()

      assert is_list(tools)
      assert length(tools) >= 1

      # Verify all expected tools are present
      assert Enum.any?(tools, &(&1.name == "get_process_info"))
    end
  end

  describe "get_process_info/1" do
    setup do
      # Start a test process
      {:ok, agent} = Agent.start_link(fn -> %{} end)

      %{agent: agent}
    end

    test "returns info of a process", %{agent: agent} do
      {:ok, text} = ProcessTool.get_process_info(%{"pid" => inspect(agent)})

      assert text =~ "Current function:"
      assert text =~ "Status:"
      assert text =~ "Message queue length:"
      assert text =~ "Stacktrace:"
    end

    test "handles invalid pid format" do
      assert {:error, message} =
               ProcessTool.get_process_info(%{"pid" => "invalid"})

      assert message =~ "Process not found"
    end

    test "handles registered process" do
      Process.register(self(), :my_process)

      assert {:ok, text} =
               ProcessTool.get_process_info(%{"name" => "my_process"})

      assert text =~ "Current function:"
    end

    test "handles non-existent process" do
      pid = dead_pid()

      assert {:error, "Process is not alive"} =
               ProcessTool.get_process_info(%{"pid" => inspect(pid)})

      assert {:error, "Process not found"} =
               ProcessTool.get_process_info(%{"name" => "idonotexist"})
    end
  end

  describe "trace_process" do
    @describetag :trace_process

    test "returns all messages sent or received by a process" do
      pid1 =
        spawn(fn ->
          Stream.repeatedly(fn ->
            receive do
              {:ping, from} -> send(from, {:pong, self()})
              :bye -> :bye
            end
          end)
          |> Enum.take_while(&(&1 != :bye))
        end)

      pid2 =
        spawn(fn ->
          Stream.repeatedly(fn ->
            receive do
              {:pong, from} -> send(from, {:ping, self()})
              :bye -> :bye
            end
          end)
          |> Enum.take_while(&(&1 != :bye))
        end)

      # start ping pong loop
      send(pid1, {:ping, pid2})

      {:ok, result} =
        ProcessTool.trace_process(
          %{"pid" => inspect(pid1), "message_count" => 3},
          Tidewave.init([])
        )

      lines = String.split(result, "\n")

      assert length(lines) == 3
      assert Enum.any?(lines, fn line -> line =~ "received {:ping, #{inspect(pid2)}}" end)

      assert Enum.any?(lines, fn line ->
               line =~ "sent {:pong, #{inspect(pid1)}} to #{inspect(pid2)}"
             end)
    end

    test "handles timeout" do
      pid = spawn_link(fn -> Process.sleep(:infinity) end)

      assert {:ok, text} =
               ProcessTool.trace_process(
                 %{
                   "pid" => inspect(pid),
                   "message_count" => 10,
                   "timeout" => 50
                 },
                 Tidewave.init([])
               )

      assert text =~ "Timed out waiting for more messages"
    end
  end
end
