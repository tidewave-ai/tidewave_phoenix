defmodule Tidewave.MCP.Logger do
  @moduledoc false

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_logs(n, level \\ :debug) do
    GenServer.call(__MODULE__, {:get_logs, n, level})
  end

  # Erlang/OTP log handler
  def log(%{meta: meta, level: level} = event, config) do
    if meta[:tidewave_mcp] do
      :ok
    else
      %{formatter: {formatter_mod, formatter_config}} = config
      chardata = formatter_mod.format(event, formatter_config)

      GenServer.cast(__MODULE__, {:log, level, IO.iodata_to_binary(chardata)})
    end
  end

  def init(_) do
    {:ok, %{cb: CircularBuffer.new(1024)}}
  end

  def handle_cast({:log, level, message}, state) do
    # There is a built-in way for MCPs to expose log messages,
    # but we currently don't use it, as the client support isn't really there.
    # https://spec.modelcontextprotocol.io/specification/2024-11-05/server/utilities/logging/
    cb = CircularBuffer.insert(state.cb, {level, message})

    {:noreply, %{state | cb: cb}}
  end

  def handle_call({:get_logs, n, level}, _from, state) do
    logs =
      CircularBuffer.to_list(state.cb)
      |> Stream.reject(fn {log_level, _} -> Logger.compare_levels(log_level, level) == :lt end)
      |> Enum.take(-n)
      |> Enum.map(&elem(&1, 1))

    {:reply, logs, state}
  end
end
