defmodule Tidewave.BrowserChannel do
  @moduledoc false

  # The channel a Tidewave control page (`/tidewave/control`) joins. Each joined
  # channel is registered with `Tidewave.BrowserSessions` as a control page that
  # can host browser sessions (iframes).
  #
  # `Tidewave.BrowserSessions` forwards requests to this process as plain
  # messages; we push them to the page and route the page's eventual reply back
  # to the waiting request process, correlated by an integer `ref`.

  use Phoenix.Channel

  alias Tidewave.BrowserSessions

  # How long to keep a pending request around before discarding it, so the map
  # doesn't grow unbounded if the page never replies. The waiting request
  # process has its own (shorter) timeout.
  @drop_after 130_000

  @impl true
  def join("tidewave:browser", _params, socket) do
    BrowserSessions.register_control(self())
    {:ok, assign(socket, :pending, %{})}
  end

  @impl true
  # An agent asked (via the MCP server) to open a new session. Push the request
  # to the page and remember who is waiting for the "session_opened" reply.
  def handle_info({:open_session, request_ref, reply_to, name, path}, socket) do
    ref = System.unique_integer([:positive])
    push(socket, "open_session", %{ref: ref, name: name, path: path})
    {:noreply, track_pending(socket, ref, reply_to, request_ref)}
  end

  # An agent asked to run browser_eval against one of this page's sessions.
  def handle_info({:browser_eval, request_ref, reply_to, name, input}, socket) do
    ref = System.unique_integer([:positive])
    push(socket, "browser_eval", %{ref: ref, session: name, input: input})
    {:noreply, track_pending(socket, ref, reply_to, request_ref)}
  end

  # Safety net so a never-answered request doesn't leak.
  def handle_info({:drop_pending, ref}, socket) do
    {:noreply, assign(socket, :pending, Map.delete(socket.assigns.pending, ref))}
  end

  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  @impl true
  # The page confirms an iframe was opened (or reports why it couldn't).
  def handle_in("session_opened", %{"ref" => ref} = payload, socket) do
    status = if error = payload["error"], do: {:error, error}, else: :ok
    {:noreply, reply_pending(socket, ref, status)}
  end

  # The page's result for a browser_eval we pushed.
  def handle_in("browser_eval_reply", %{"ref" => ref} = payload, socket) do
    {:noreply, reply_pending(socket, ref, payload["result"])}
  end

  defp track_pending(socket, ref, reply_to, request_ref) do
    Process.send_after(self(), {:drop_pending, ref}, @drop_after)
    assign(socket, :pending, Map.put(socket.assigns.pending, ref, {reply_to, request_ref}))
  end

  defp reply_pending(socket, ref, value) do
    {pending, rest} = Map.pop(socket.assigns.pending, ref)

    case pending do
      {reply_to, request_ref} -> send(reply_to, {:browser_reply, request_ref, value})
      nil -> :ok
    end

    assign(socket, :pending, rest)
  end
end
