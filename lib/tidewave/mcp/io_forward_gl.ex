# This file is based on: https://github.com/livebook-dev/livebook/blob/main/lib/livebook/runtime/erl_dist/io_forward_gl.ex
# licensed under Apache License 2.0
# https://github.com/livebook-dev/livebook/blob/main/LICENSE

defmodule Tidewave.MCP.IOForwardGL do
  @moduledoc false

  # An IO device process forwarding all requests to sender's group
  # leader.
  #
  # We register this device as `:standard_error` in order to capture
  # compile errors etc., but still forward them to the real stderr.
  #
  # The process implements [The Erlang I/O Protocol](https://erlang.org/doc/apps/stdlib/io_protocol.html)
  # and can be thought of as a virtual IO device.

  use GenServer

  @doc """
  Starts the IO device.

  ## Options

    * `:name` - the name to register the process under. Optional.
      If the name is already used, it will be unregistered before
      starting the process and registered back when the server
      terminates

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = opts[:name]

    if previous = name && Process.whereis(name) do
      Process.unregister(name)
    end

    GenServer.start_link(__MODULE__, {name, previous}, opts)
  end

  @impl true
  def init({name, previous}) do
    Process.flag(:trap_exit, true)
    {:ok, %{name: name, previous: previous, targets: %{}}}
  end

  def with_forwarded_io(name, fun) do
    group_leader = Process.group_leader()
    ref = GenServer.call(name, {:add_target, self(), group_leader})

    try do
      fun.()
    after
      GenServer.call(name, {:remove_target, ref, group_leader})
    end
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
  def terminate(_, %{name: name, previous: previous}) do
    if name && previous do
      Process.unregister(name)
      Process.register(previous, name)
    end

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
