defmodule Tidewave.ACP do
  @behaviour WebSock

  @impl true
  def init(%{command: command}) do
    port = Port.open({:spawn, command}, [:binary])

    {:ok, %{command: command, port: port}}
  end

  @impl true
  def handle_in({"ping", opcode: :text}, state) do
    {:push, {:text, "pong"}, state}
  end

  def handle_in({message, opcode: :text}, state) do
    Port.command(state.port, message <> "\n")
    {:ok, state}
  end

  def handle_in(_, state) do
    {:ok, state}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    {:push, {:text, data}, state}
  end

  def handle_info(message, state) do
    dbg(message)
    {:ok, state}
  end
end
