defmodule Tidewave.ControlSocket do
  @moduledoc false

  # The `WebSock` handler behind `/tidewave/ws`. One process per connected
  # control page. The router upgrades the request to this handler via
  # `WebSockAdapter.upgrade/4`.
  #
  # On connect, the page sends a `hello` with its self-chosen name, which we
  # register with `Tidewave.BrowserSessions`. From then on the MCP request
  # process forwards `{:browser_eval, ...}` messages here; we push them to the
  # page as JSON frames and route the page's eventual `eval_reply` back to the
  # waiting request process, correlated by an integer `ref`.

  @behaviour WebSock

  alias Tidewave.BrowserSessions

  # Safety net so a request the page never answers doesn't keep a pending entry
  # forever. It is longer than any server-side wait; the request process has its
  # own (shorter) timeout.
  @drop_after 150_000

  @impl true
  def init(_opts) do
    {:ok, %{name: nil, pending: %{}}}
  end

  @impl true
  def handle_in({text, [opcode: :text]}, state) do
    case Jason.decode(text) do
      {:ok, message} -> handle_message(message, state)
      {:error, _} -> {:ok, state}
    end
  end

  def handle_in(_frame, state), do: {:ok, state}

  defp handle_message(%{"type" => "hello", "name" => name}, state) when is_binary(name) do
    case BrowserSessions.register_client(name) do
      :ok ->
        {:push, text_frame(%{type: "hello_ok", name: name}), %{state | name: name}}

      {:error, :name_taken} ->
        {:push, text_frame(%{type: "hello_error", reason: "name_taken"}), state}
    end
  end

  defp handle_message(%{"type" => "eval_reply", "ref" => ref} = message, state) do
    {:ok, reply_pending(state, ref, message["result"])}
  end

  defp handle_message(_other, state), do: {:ok, state}

  @impl true
  # An agent (via the MCP server) asked to run code. Push it to the page and
  # remember who is waiting for the reply.
  def handle_info({:browser_eval, request_ref, reply_to, sid, input}, state) do
    ref = System.unique_integer([:positive])
    Process.send_after(self(), {:drop_pending, ref}, @drop_after)
    state = put_in(state.pending[ref], {reply_to, request_ref})
    {:push, text_frame(%{type: "eval", ref: ref, sid: sid, input: input}), state}
  end

  def handle_info({:drop_pending, ref}, state) do
    {:ok, %{state | pending: Map.delete(state.pending, ref)}}
  end

  def handle_info(_message, state), do: {:ok, state}

  @impl true
  def terminate(_reason, _state), do: :ok

  defp reply_pending(state, ref, value) do
    {pending, rest} = Map.pop(state.pending, ref)

    case pending do
      {reply_to, request_ref} -> send(reply_to, {:browser_reply, request_ref, value})
      nil -> :ok
    end

    %{state | pending: rest}
  end

  defp text_frame(map), do: {:text, Jason.encode!(map)}
end
