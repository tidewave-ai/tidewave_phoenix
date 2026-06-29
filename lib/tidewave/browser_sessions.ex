defmodule Tidewave.BrowserSessions do
  @moduledoc false

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
      [] -> {:error, :unknown_client}
    end
  end

  @doc """
  Runs the given tool against the client owning `sid` and waits for the reply.

  Returns `{:ok, result}` (the browser's response map) or `{:error, reason}`
  where reason is `:invalid_sid`, `:unknown_client`, `:timeout`, or
  `:disconnected`.
  """
  def run(sid, name, input, timeout) when is_binary(sid) do
    with {:ok, client} <- parse_sid(sid),
         {:ok, pid} <- lookup_client(client) do
      await_eval(pid, sid, name, input, timeout)
    end
  end

  @doc """
  Broadcasts the given tool to every connected client and returns the first reply.

  Used for the handshake (a `browser_eval` call with no `sid`). Returns
  `{:ok, result}`, `{:error, :no_clients}` when nobody is connected, or
  `{:error, :timeout}` when no client answered in time.
  """
  def broadcast_run(name, input, timeout) do
    case list_clients() do
      [] -> {:error, :no_clients}
      clients -> await_broadcast(clients, name, input, timeout)
    end
  end

  defp parse_sid(sid) do
    case String.split(sid, "#", parts: 2) do
      [name, suffix] when name != "" and suffix != "" -> {:ok, name}
      _ -> {:error, :invalid_sid}
    end
  end

  defp await_eval(pid, sid, name, input, timeout) do
    alias = Process.monitor(pid, alias: :reply_demonitor)
    send(pid, {:run_tool, alias, sid, name, input})

    receive do
      {:browser_reply, ^alias, value} -> {:ok, value}
      {:DOWN, ^alias, :process, ^pid, _reason} -> {:error, :disconnected}
    after
      timeout ->
        Process.demonitor(alias, [:flush])
        {:error, :timeout}
    end
  end

  defp await_broadcast(clients, name, input, timeout) do
    # we are only interested in the first response, so we use
    # an alias with :reply to ignore any late responses
    alias = :erlang.alias([:reply])
    Enum.each(clients, fn {_name, pid} -> send(pid, {:run_tool, alias, nil, name, input}) end)

    receive do
      {:browser_reply, ^alias, value} ->
        {:ok, value}
    after
      timeout ->
        {:error, :timeout}
    end
  end
end
