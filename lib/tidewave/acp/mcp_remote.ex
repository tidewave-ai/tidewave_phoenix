defmodule Tidewave.ACP.MCPRemote do
  @behaviour WebSock

  require Logger

  @impl true
  def init(_) do
    {:ok, %{awaiting_answers: %{}}}
  end

  @impl true
  def handle_in({"ping", opcode: :text}, state) do
    {:push, {:text, "pong"}, state}
  end

  def handle_in({"register-" <> session_id, opcode: :text}, state) do
    Registry.register(Tidewave.ACP.MCPRegistry, session_id, nil)
    {:push, {:text, "registered-#{session_id}"}, state}
  end

  def handle_in({message, opcode: :text}, state) do
    json = JSON.decode!(message)

    case json do
      %{"sessionId" => session_id, "jsonRpcMessage" => %{"id" => id} = reply} ->
        maybe_handle_reply(session_id, id, reply, state)

      %{"jsonRpcMessage" => message} ->
        Logger.info("Ignoring notification from browser: #{inspect(message)}")
        {:ok, state}
    end
  end

  def handle_in(_, state) do
    {:ok, state}
  end

  defp maybe_handle_reply(session_id, id, reply, state)
       when is_map_key(state.awaiting_answers, {session_id, id}) do
    {pid, ref} = state.awaiting_answers[{session_id, id}]

    send(pid, {ref, reply})

    {:ok, state}
  end

  defp maybe_handle_reply(session_id, _id, reply, state) do
    Logger.error(
      "Did not expect a reply (or request) for session #{session_id}: #{inspect(reply)}"
    )

    {:ok, state}
  end

  @impl true
  def handle_info({:mcp_message, {pid, ref}, session_id, params}, state) do
    if params["id"] do
      state =
        update_in(state.awaiting_answers, &Map.put(&1, {session_id, params["id"]}, {pid, ref}))

      {:push, {:text, JSON.encode!(%{sessionId: session_id, jsonRpcMessage: params})}, state}
    else
      # not a request, no need to answer
      send(pid, {ref, nil})
      {:push, {:text, JSON.encode!(%{sessionId: session_id, jsonRpcMessage: params})}, state}
    end
  end

  @impl true
  def handle_info({:EXIT, port, reason}, %{port: port} = state) do
    {:stop, {:shutdown, reason}, state}
  end

  def handle_info(message, state) do
    dbg(message)
    {:ok, state}
  end
end
