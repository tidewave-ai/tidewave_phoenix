defmodule Tidewave.BrowserSessions do
  @moduledoc false

  # Registry of connected browser control pages ("clients").
  #
  # This is the (deliberately thin) server side of Tidewave's control plane.
  # Each browser tab that opens `/tidewave` connects over a plain WebSocket
  # (`Tidewave.ControlSocket`) and registers its connection process under a
  # self-chosen, human-friendly name (e.g. `nice-cactus`) in a `:unique`
  # `Registry` (started under this module's name). The registry maps the name to
  # the connection process and prunes it automatically when that process dies;
  # everything about individual sessions (the iframes, their `@N` numbering,
  # primary vs. secondary) lives in the page's JavaScript. A `sid` has the shape
  # `name@N`; we route by splitting on `@` and treating the suffix as opaque.
  #
  # The MCP `browser_eval` tool callback runs in the request process and uses
  # `eval/3` (a `sid` was given) or `broadcast_eval/2` (none given, so we ask
  # every connected page and take the first to answer). Both block until a reply
  # arrives or the timeout elapses. The waiting is done in a throwaway task so a
  # late reply can never leak into the long-lived request process.

  @registry __MODULE__

  @doc """
  Registers the calling process as a client under `name`.

  Returns `:ok`, or `{:error, :name_taken}` if a different live client already
  uses that name (the page is expected to pick another name and retry).
  """
  def register_client(name) when is_binary(name) do
    case Registry.register(@registry, name, nil) do
      {:ok, _owner} -> :ok
      {:error, {:already_registered, pid}} when pid == self() -> :ok
      {:error, {:already_registered, _other}} -> {:error, :name_taken}
    end
  end

  @doc """
  Lists connected clients as `{name, pid}`, sorted by name.
  """
  def list_clients do
    @registry
    |> Registry.select([{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.sort()
  end

  @doc """
  Looks up the connection process for a client name.
  """
  def lookup_client(name) when is_binary(name) do
    case Registry.lookup(@registry, name) do
      [{pid, _value}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Runs `browser_eval` against the client owning `sid` and waits for the reply.

  Returns `{:ok, result}` (the browser's response map) or `{:error, reason}`
  where reason is `:invalid_sid`, `:unknown_client`, `:timeout`, or
  `:disconnected`.
  """
  def eval(sid, input, timeout) when is_binary(sid) do
    case parse_sid(sid) do
      {:ok, name} ->
        case lookup_client(name) do
          {:ok, pid} -> collect(fn -> await_eval(pid, sid, input) end, timeout)
          :error -> {:error, :unknown_client}
        end

      :error ->
        {:error, :invalid_sid}
    end
  end

  @doc """
  Broadcasts `browser_eval` to every connected client and returns the first reply.

  Used for the handshake (a `browser_eval` call with no `sid`). Returns
  `{:ok, result}`, `{:error, :no_clients}` when nobody is connected, or
  `{:error, :timeout}` when no client answered in time.
  """
  def broadcast_eval(input, timeout) do
    case client_pids() do
      [] -> {:error, :no_clients}
      pids -> collect(fn -> await_broadcast(pids, input) end, timeout)
    end
  end

  defp client_pids do
    for {_name, pid} <- list_clients(), do: pid
  end

  defp parse_sid(sid) do
    case String.split(sid, "@", parts: 2) do
      [name, suffix] when name != "" and suffix != "" -> {:ok, name}
      _ -> :error
    end
  end

  # Runs the blocking receive in a throwaway task so that, on timeout, the task
  # (and any stray late `:browser_reply` messages in its mailbox) is discarded
  # instead of polluting the caller, which on HTTP/1 keep-alive is reused across
  # requests.
  defp collect(fun, timeout) do
    task = Task.async(fun)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      _ -> {:error, :timeout}
    end
  end

  defp await_eval(pid, sid, input) do
    ref = make_ref()
    mon = Process.monitor(pid)
    send(pid, {:browser_eval, ref, self(), sid, input})

    receive do
      {:browser_reply, ^ref, value} -> {:ok, value}
      {:DOWN, ^mon, :process, ^pid, _reason} -> {:error, :disconnected}
    end
  end

  defp await_broadcast(pids, input) do
    ref = make_ref()
    Enum.each(pids, fn pid -> send(pid, {:browser_eval, ref, self(), nil, input}) end)

    receive do
      {:browser_reply, ^ref, value} -> {:ok, value}
    end
  end
end
