# This file is based on: https://github.com/livebook-dev/livebook/blob/main/lib/livebook/runtime/erl_dist/io_forward_gl.ex
# licensed under Apache License 2.0
# https://github.com/livebook-dev/livebook/blob/main/LICENSE

defmodule Tidewave.MCP.StandardError do
  @moduledoc false

  # A replacement for standard error that allows multple captires.
  #
  # We register this device as `:standard_error` in order to capture
  # compile errors etc., but still forward them to the real stderr.
  #
  # The process implements [The Erlang I/O Protocol](https://erlang.org/doc/apps/stdlib/io_protocol.html)
  # and can be thought of as a virtual IO device.

  use GenServer

  @doc """
  Starts the IO device.
  """
  def start_link(_) do
    previous = Process.whereis(:standard_error)

    if previous do
      Process.unregister(:standard_error)
    end

    with {:ok, pid} <- GenServer.start_link(__MODULE__, previous, name: :standard_error) do
      :persistent_term.put(__MODULE__, pid)
      {:ok, pid}
    end
  end

  @doc """
  Forwards standard error in the given function to group leader.
  """
  def forward(fun) do
    group_leader = Process.group_leader()
    # We go through the persistent term in case someone else hijacked standard error
    pid = :persistent_term.get(__MODULE__)
    ref = GenServer.call(pid, {:add_target, self(), group_leader})

    try do
      fun.()
    after
      GenServer.call(pid, {:remove_target, ref, group_leader})
    end
  end

  @impl true
  def init(previous) do
    Process.flag(:trap_exit, true)
    {:ok, %{previous: previous, targets: %{}}}
  end

  @impl true
  def handle_call({:add_target, owner, target}, _from, state) do
    ref = Process.monitor(owner, tag: {:DOWN, :target, target})
    {:reply, ref, %{state | targets: add_target(state.targets, target)}}
  end

  @impl true
  def handle_call({:remove_target, ref, target}, _from, state) do
    Process.demonitor(ref, [:flush])
    {:reply, :ok, %{state | targets: drop_target(state.targets, target)}}
  end

  @impl true
  def handle_info({:io_request, from, reply_as, req}, state) do
    # by default, we just forward to the original target
    send(state.previous, {:io_request, from, reply_as, req})

    Enum.each(state.targets, fn {target, _count} ->
      # forward to all explicitly registered targets, using self()
      # to discard replies
      send(target, {:io_request, self(), reply_as, req})
    end)

    {:noreply, state}
  end

  def handle_info({:io_reply, _reply_as, _reply}, state) do
    {:noreply, state}
  end

  def handle_info({{:DOWN, :target, target}, _ref, :process, _pid, _reason}, state) do
    {:noreply, %{state | targets: drop_target(state.targets, target)}}
  end

  @impl true
  def terminate(_, %{previous: previous}) do
    Process.unregister(:standard_error)
    Process.register(previous, :standard_error)
    :ok
  end

  defp add_target(targets, target) do
    Map.update(targets, target, 1, fn count -> count + 1 end)
  end

  defp drop_target(targets, target) do
    case Map.update!(targets, target, fn count -> count - 1 end) do
      %{^target => 0} -> Map.delete(targets, target)
      targets -> targets
    end
  end
end
