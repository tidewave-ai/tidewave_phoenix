# This file is based on: https://github.com/livebook-dev/livebook/blob/main/lib/livebook/runtime/erl_dist/io_forward_gl.ex
# licensed under Apache License 2.0
# https://github.com/livebook-dev/livebook/blob/main/LICENSE

defmodule Tidewave.MCP.IOForwardGL do
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
    {:ok, %{name: name, previous: previous, targets: []}}
  end

  def with_forwarded_io(name, fun) do
    GenServer.call(name, {:add_target, self()})

    try do
      fun.()
    after
      GenServer.call(name, {:remove_target, self()})
    end
  end

  @impl true
  def handle_call({:add_target, target}, _from, state) do
    {:reply, :ok, %{state | targets: [target | state.targets]}}
  end

  @impl true
  def handle_call({:remove_target, target}, _from, state) do
    {:reply, :ok, %{state | targets: List.delete(state.targets, target)}}
  end

  @impl true
  def handle_info({:io_request, from, reply_as, req}, state) do
    # by default, we just forward to the original target
    send(state.previous, {:io_request, from, reply_as, req})

    Enum.each(state.targets, fn target ->
      # forward to all explicitly registered targets, using self()
      # to discard replies
      case Process.info(target, :group_leader) do
        {:group_leader, group_leader} ->
          send(group_leader, {:io_request, self(), reply_as, req})

        _ ->
          :ok
      end
    end)

    {:noreply, state}
  end

  def handle_info({:io_reply, _reply_as, _reply}, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_, %{name: name, previous: previous}) do
    if name && previous do
      Process.unregister(name)
      Process.register(previous, name)
    end

    :ok
  end
end
