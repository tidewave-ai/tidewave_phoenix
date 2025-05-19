# This file is based on mcp_sse: https://github.com/kEND/mcp_sse
#
# MIT License
#
# Copyright (c) 2025 kEND
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

defmodule Tidewave.MCP.Connection do
  @moduledoc false
  # Internal state management for SSE connections

  use GenServer
  require Logger

  import Plug.Conn

  # 30 seconds for initialization
  @init_timeout 30_000
  # 30 minutes in milliseconds
  @inactivity_timeout 30 * 60 * 1000

  # State transitions
  # :connected -> :initialized -> :ready

  @impl GenServer
  def init({session_id, conn}) do
    Logger.metadata(tidewave_mcp: true)
    # Start initialization timeout
    Process.send_after(self(), :init_timeout, @init_timeout)
    # Start inactivity timeout
    timeout_ref = Process.send_after(self(), :inactivity_timeout, @inactivity_timeout)

    :gen_server.enter_loop(__MODULE__, [], %{
      session_id: session_id,
      conn: conn,
      state: :connected,
      init_received: false,
      initialized_received: false,
      last_activity: System.monotonic_time(:millisecond),
      # Add reference to the timeout timer
      timeout_ref: timeout_ref,
      requests: %{},
      # We convert the configuration into the `assigns` map passed to tools
      assigns: conn.private.tidewave_config
    })
  end

  def handle_initialize(pid) do
    GenServer.call(pid, :handle_initialize)
  end

  def handle_initialized(pid) do
    GenServer.call(pid, :handle_initialized)
  end

  def ready?(pid) do
    GenServer.call(pid, :ready?)
  end

  def record_activity(pid) do
    GenServer.call(pid, :record_activity)
  end

  def check_activity_timeout(pid) do
    GenServer.call(pid, :check_activity_timeout)
  end

  def handle_result(pid, id) do
    GenServer.call(pid, {:handle_result, id})
  end

  def connect_params_and_opts(pid) do
    GenServer.call(pid, :connect_params_and_opts)
  end

  def dispatch(pid, callback, args) do
    GenServer.call(pid, {:dispatch, callback, args})
  end

  def send_sse_message(pid, message) do
    GenServer.cast(pid, {:send_sse_message, message})
  end

  @impl GenServer
  def handle_cast({:send_sse_message, message}, state) do
    case handle_sse_message(state.conn, state.session_id, message) do
      {:ok, conn} -> {:noreply, %{state | conn: conn}}
      {:error, reason} -> {:stop, {:shutdown, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:handle_initialize, _from, state) do
    new_state = %{state | init_received: true, last_activity: System.monotonic_time(:millisecond)}
    {:reply, :ok, new_state}
  end

  def handle_call(:handle_initialized, _from, %{init_received: true} = state) do
    new_state = %{
      state
      | initialized_received: true,
        state: :ready,
        last_activity: System.monotonic_time(:millisecond)
    }

    schedule_next_ping(state.assigns)

    {:reply, :ok, new_state}
  end

  def handle_call(:handle_initialized, _from, state) do
    {:reply, {:error, :not_initialized}, state}
  end

  def handle_call(:ready?, _from, %{state: :ready} = state) do
    {:reply, true, state}
  end

  def handle_call(:ready?, _from, state) do
    {:reply, false, state}
  end

  def handle_call(:record_activity, _from, state) do
    # Cancel existing timeout
    if state.timeout_ref, do: Process.cancel_timer(state.timeout_ref)
    # Schedule new timeout
    timeout_ref = Process.send_after(self(), :inactivity_timeout, @inactivity_timeout)

    new_state = %{
      state
      | last_activity: System.monotonic_time(:millisecond),
        timeout_ref: timeout_ref
    }

    {:reply, :ok, new_state}
  end

  def handle_call(:check_activity_timeout, _from, state) do
    current_time = System.monotonic_time(:millisecond)
    time_since_activity = current_time - state.last_activity

    if time_since_activity >= @inactivity_timeout do
      {:reply, {:error, :activity_timeout}, state}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call({:handle_result, id}, _from, state) do
    result =
      case Map.get(state.requests, id) do
        true -> :ok
        _ -> {:error, :not_found}
      end

    {:reply, result, %{state | requests: Map.delete(state.requests, id)}}
  end

  def handle_call(:connect_params_and_opts, _from, state) do
    {:reply, {state.conn.query_params, state.conn.assigns[:router_opts]}, state}
  end

  def handle_call({:dispatch, callback, args}, _from, state) do
    # tools that change the state are dispatched inside the Connection server
    # in order to synchronize state changes
    try do
      case callback.(args, state.assigns) do
        {:ok, result, new_assigns} ->
          {:reply, {:ok, result}, %{state | assigns: new_assigns}}

        {:ok, result, new_assigns, metadata} ->
          {:reply, {:ok, result, metadata}, %{state | assigns: new_assigns}}

        {:error, reason, new_assigns} ->
          {:reply, {:error, reason}, %{state | assigns: new_assigns}}

        other ->
          {:reply, other, state}
      end
    catch
      kind, reason ->
        {:error, "Failed to call tool: #{Exception.format(kind, reason, __STACKTRACE__)}"}
    end
  end

  @impl GenServer
  def handle_info(:init_timeout, %{state: :ready} = state) do
    {:noreply, state}
  end

  def handle_info(:init_timeout, %{session_id: session_id} = state) do
    Logger.warning("Initialization timeout for session #{session_id}")

    conn =
      close_connection(state.conn, state.session_id, "Initialization timeout after 30 seconds")

    {:stop, {:shutdown, :closed}, %{state | conn: conn}}
  end

  def handle_info(:inactivity_timeout, state) do
    conn =
      close_connection(
        state.conn,
        state.session_id,
        "Connection closed due to 5 minutes of inactivity"
      )

    {:stop, {:shutdown, :inactivity_timeout}, %{state | conn: conn}}
  end

  def handle_info(:send_ping, %{state: :ready} = state) do
    case handle_ping(state) do
      {:ok, state} ->
        schedule_next_ping(state.assigns)
        {:noreply, state}

      {:error, reason} ->
        {:stop, {:shutdown, reason}, state}
    end
  end

  def handle_info(:send_ping, state) do
    schedule_next_ping(state.assigns)
    {:noreply, state}
  end

  def handle_info({:plug_conn, :sent}, state) do
    {:noreply, state}
  end

  def handle_info(message, state) do
    Logger.error("Unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  defp schedule_next_ping(opts) do
    case Map.get(opts, :sse_keepalive_timeout, 15_000) do
      # Don't schedule next ping if disabled
      :infinity ->
        :ok

      timeout when is_integer(timeout) ->
        Process.send_after(self(), :send_ping, timeout)
    end
  end

  defp close_connection(conn, session_id, reason) do
    Logger.info("Closing SSE connection. Session ID: #{session_id}, Reason: #{reason}")

    case chunk(conn, "event: close\ndata: #{reason}\n\n") do
      {:ok, conn} -> halt(conn)
      {:error, _reason} -> halt(conn)
    end
  end

  defp handle_sse_message(conn, _session_id, msg) do
    sse_message = ["event: message\ndata: ", Jason.encode_to_iodata!(msg), "\n\n"]
    Logger.debug("Sending SSE message:\n#{sse_message}")

    case chunk(conn, sse_message) do
      {:ok, conn} -> {:ok, conn}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handle_ping(state) do
    ping_notification = %{
      id: System.unique_integer([:positive]),
      jsonrpc: "2.0",
      method: "ping"
    }

    state = %{state | requests: Map.put(state.requests, ping_notification.id, true)}

    case chunk(state.conn, [
           "event: message\ndata: ",
           Jason.encode_to_iodata!(ping_notification),
           "\n\n"
         ]) do
      {:ok, conn} -> {:ok, %{state | conn: conn}}
      {:error, reason} -> {:error, reason}
    end
  end
end
