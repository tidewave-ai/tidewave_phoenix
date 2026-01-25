defmodule Tidewave.MCP.Logger do
  @moduledoc false

  use GenServer

  @levels Map.new(~w[emergency alert critical error warning notice info debug]a, &{"#{&1}", &1})

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def get_logs(n, opts \\ []) do
    grep = Keyword.get(opts, :grep)
    regex = grep && Regex.compile!(grep, "iu")
    level = Keyword.get(opts, :level)
    level_atom = level && Map.fetch!(@levels, level)
    GenServer.call(__MODULE__, {:get_logs, n, regex, level_atom})
  end

  def clear_logs do
    GenServer.call(__MODULE__, :clear_logs)
  end

  # Erlang/OTP log handler
  def log(%{meta: meta, level: level} = event, config) do
    if meta[:tidewave_mcp] do
      :ok
    else
      %{formatter: {formatter_mod, formatter_config}} = config
      chardata = formatter_mod.format(event, formatter_config)
      GenServer.cast(__MODULE__, {:log, level, IO.chardata_to_string(chardata)})
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

  def handle_call({:get_logs, n, regex, level_filter}, _from, state) do
    logs = CircularBuffer.to_list(state.cb)

    logs =
      if level_filter do
        Stream.filter(logs, fn {level, _message} -> level == level_filter end)
      else
        logs
      end

    logs =
      if regex do
        Stream.filter(logs, fn {_level, message} -> Regex.match?(regex, message) end)
      else
        logs
      end

    messages = Stream.map(logs, &elem(&1,1))

    {:reply, Enum.take(messages, -n), state}
  end

  def handle_call(:clear_logs, _from, state) do
    cb = CircularBuffer.new(1024)
    {:reply, :ok, %{state | cb: cb}}
  end
end
