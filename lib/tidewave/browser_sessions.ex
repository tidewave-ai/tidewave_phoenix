defmodule Tidewave.BrowserSessions do
  @moduledoc false

  # Registry of connected browser control pages and the browser sessions
  # (iframes) they host.
  #
  # This is the server side of Tidewave's control plane. A control page
  # (`/tidewave/control`) connects over `Tidewave.BrowserChannel` and registers
  # itself here as a "control". Agents calling the `browser_session` MCP tool
  # ask us to open a new iframe in such a page; we assign it a human-friendly
  # name (e.g. `flying-circus`) which becomes the `session` identifier the
  # `browser_eval` tool targets.
  #
  # The MCP tool callbacks run in the request process and use `open_session/2`
  # and `eval/3`, which forward to the owning channel process and block until it
  # replies. The channel is monitored so a disconnect unblocks the caller
  # instead of waiting out the full timeout.

  use GenServer

  # How many times to retry friendly-name generation on a collision before
  # giving up. With thousands of combinations this is effectively never hit.
  @name_attempts 25

  @adjectives ~w(
    amber autumn brave bright calm clever cosmic crimson curious dawn
    eager electric ember fancy flying gentle golden happy hidden humble
    icy jolly keen lively lucky lunar maroon mellow merry mighty misty
    noble polar proud quiet rapid royal rustic scarlet shy silent silver
    smooth solar spry stellar sunny swift teal tidal vivid wandering wild
    witty zesty
  )

  @nouns ~w(
    aurora badger beacon birch bison brook canyon cedar circus cobra
    comet coral cosmos cricket delta dune ember falcon fern fjord
    galaxy garden geyser glacier harbor heron island jaguar lagoon
    lantern ledger lichen lotus meadow nebula otter pebble petal pine
    prairie quail quartz ridge river robin saffron sparrow spruce summit
    thicket tundra valley willow zephyr
  )

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, name: Keyword.get(opts, :name, __MODULE__))
  end

  ## Control pages

  @doc """
  Registers the calling process (a `Tidewave.BrowserChannel`) as a control page.
  """
  def register_control(pid \\ self()) do
    GenServer.call(__MODULE__, {:register_control, pid})
  end

  @doc """
  Lists the pids of the connected control pages.
  """
  def list_controls do
    GenServer.call(__MODULE__, :list_controls)
  end

  ## Browser sessions

  @doc """
  Lists all registered browser sessions as `%{name:, pid:, meta:}`, sorted by name.
  """
  def list_sessions do
    GenServer.call(__MODULE__, :list_sessions)
  end

  @doc """
  Looks up a single session by name.

  Returns `{:ok, %{name:, pid:, meta:}}` or `:error`.
  """
  def lookup(name) when is_binary(name) do
    GenServer.call(__MODULE__, {:lookup, name})
  end

  @doc """
  Forgets a session (used to roll back a reservation that never opened).
  """
  def remove_session(name) when is_binary(name) do
    GenServer.cast(__MODULE__, {:remove_session, name})
  end

  @doc """
  Resolves which session a call should target.

  Returns `{:ok, session}` or one of `{:error, :no_sessions}`,
  `{:error, {:ambiguous, names}}`, `{:error, {:unknown, name, available_names}}`.
  """
  def resolve_session(name \\ nil)

  def resolve_session(nil) do
    case list_sessions() do
      [] -> {:error, :no_sessions}
      [session] -> {:ok, session}
      sessions -> {:error, {:ambiguous, Enum.map(sessions, & &1.name)}}
    end
  end

  def resolve_session(name) when is_binary(name) do
    case lookup(name) do
      {:ok, session} ->
        {:ok, session}

      :error ->
        available = list_sessions() |> Enum.map(& &1.name)
        {:error, {:unknown, name, available}}
    end
  end

  @doc """
  Opens a new browser session (iframe) at `path` and waits for the control page
  to confirm it loaded.

  Returns `{:ok, name}` or `{:error, reason}` where reason is `:no_control`,
  `:name_unavailable`, `:timeout`, `:disconnected`, or a binary from the browser.
  """
  def open_session(path, timeout) do
    case GenServer.call(__MODULE__, {:create_session, path}) do
      {:ok, name, pid} ->
        case call_channel(pid, {:open_session, name, path}, timeout) do
          {:ok, :ok} ->
            {:ok, name}

          {:ok, {:error, message}} ->
            remove_session(name)
            {:error, message}

          {:error, reason} ->
            remove_session(name)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Runs `browser_eval` against a session and waits for the reply.

  Resolves `name` via `resolve_session/1`, forwards the request to the owning
  channel process, and blocks until it replies or `timeout` (ms) elapses.

  Returns `{:ok, result, session_name}` where `result` is a map with `"text"`
  and `"isError"`, or `{:error, reason}` (a `resolve_session/1` error, or
  `:timeout`/`:disconnected`).
  """
  def eval(name, input, timeout) do
    with {:ok, session} <- resolve_session(name),
         {:ok, result} <- call_channel(session.pid, {:browser_eval, session.name, input}, timeout) do
      {:ok, result, session.name}
    end
  end

  # Sends a request to a channel process and awaits its reply. The channel
  # replies with `{:browser_reply, ref, value}` once the browser responds. We
  # monitor it so a disconnect unblocks us instead of waiting out the timeout.
  defp call_channel(pid, {:open_session, name, path}, timeout) do
    await_reply(pid, fn ref -> {:open_session, ref, self(), name, path} end, timeout)
  end

  defp call_channel(pid, {:browser_eval, name, input}, timeout) do
    await_reply(pid, fn ref -> {:browser_eval, ref, self(), name, input} end, timeout)
  end

  defp await_reply(pid, build_message, timeout) do
    ref = make_ref()
    monitor_ref = Process.monitor(pid)
    send(pid, build_message.(ref))

    receive do
      {:browser_reply, ^ref, value} ->
        Process.demonitor(monitor_ref, [:flush])
        {:ok, value}

      {:DOWN, ^monitor_ref, :process, ^pid, _reason} ->
        {:error, :disconnected}
    after
      timeout ->
        Process.demonitor(monitor_ref, [:flush])
        {:error, :timeout}
    end
  end

  ## Server

  @impl true
  def init(:ok) do
    {:ok, %{controls: [], sessions: %{}, monitors: %{}}}
  end

  @impl true
  def handle_call({:register_control, pid}, _from, state) do
    if pid in state.controls do
      {:reply, :ok, state}
    else
      monitor_ref = Process.monitor(pid)

      state = %{
        state
        | controls: [pid | state.controls],
          monitors: Map.put(state.monitors, monitor_ref, pid)
      }

      {:reply, :ok, state}
    end
  end

  def handle_call({:create_session, path}, _from, state) do
    case state.controls do
      [] ->
        {:reply, {:error, :no_control}, state}

      [pid | _] ->
        case generate_unique_name(state.sessions) do
          {:ok, name} ->
            session = %{name: name, pid: pid, meta: %{path: path}}
            state = put_in(state.sessions[name], session)
            {:reply, {:ok, name, pid}, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call(:list_controls, _from, state) do
    {:reply, state.controls, state}
  end

  def handle_call(:list_sessions, _from, state) do
    sessions = state.sessions |> Map.values() |> Enum.sort_by(& &1.name)
    {:reply, sessions, state}
  end

  def handle_call({:lookup, name}, _from, state) do
    {:reply, Map.fetch(state.sessions, name), state}
  end

  @impl true
  def handle_cast({:remove_session, name}, state) do
    {:noreply, %{state | sessions: Map.delete(state.sessions, name)}}
  end

  @impl true
  def handle_info({:DOWN, monitor_ref, :process, pid, _reason}, state) do
    sessions = for {name, s} <- state.sessions, s.pid != pid, into: %{}, do: {name, s}

    state = %{
      state
      | controls: List.delete(state.controls, pid),
        sessions: sessions,
        monitors: Map.delete(state.monitors, monitor_ref)
    }

    {:noreply, state}
  end

  defp generate_unique_name(sessions, attempts \\ @name_attempts)

  defp generate_unique_name(_sessions, 0), do: {:error, :name_unavailable}

  defp generate_unique_name(sessions, attempts) do
    name = "#{Enum.random(@adjectives)}-#{Enum.random(@nouns)}"

    if Map.has_key?(sessions, name) do
      generate_unique_name(sessions, attempts - 1)
    else
      {:ok, name}
    end
  end
end
