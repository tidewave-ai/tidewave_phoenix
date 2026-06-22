defmodule Tidewave.BrowserSessionsTest do
  # The registry is a globally-named singleton, so these tests share it and
  # cannot run concurrently with each other.
  use ExUnit.Case, async: false

  alias Tidewave.BrowserSessions

  setup do
    # Each test starts from a clean slate; the previous test's cleanup is given
    # a moment to be processed by the registry.
    wait_until(fn -> BrowserSessions.list_clients() == [] end)
    :ok
  end

  describe "register_client/2" do
    test "registers and is discoverable" do
      pid = start_client("nice-cactus")

      assert {:ok, ^pid} = BrowserSessions.lookup_client("nice-cactus")
      assert [{"nice-cactus", ^pid}] = BrowserSessions.list_clients()
    end

    test "rejects a duplicate name from another process" do
      start_client("nice-cactus")
      parent = self()

      pid =
        spawn(fn ->
          send(parent, {:result, BrowserSessions.register_client("nice-cactus")})
          receive do: (:stop -> :ok)
        end)

      on_exit(fn -> stop_client(pid) end)
      assert_receive {:result, {:error, :name_taken}}
    end

    test "is idempotent for the same process" do
      parent = self()

      pid =
        spawn(fn ->
          send(parent, {:r1, BrowserSessions.register_client("nice-cactus")})
          send(parent, {:r2, BrowserSessions.register_client("nice-cactus")})
          receive do: (:stop -> :ok)
        end)

      on_exit(fn -> stop_client(pid) end)
      assert_receive {:r1, :ok}
      assert_receive {:r2, :ok}
    end

    test "forgets a client when it dies" do
      pid = start_client("nice-cactus")
      assert {:ok, ^pid} = BrowserSessions.lookup_client("nice-cactus")

      stop_client(pid)

      wait_until(fn -> BrowserSessions.lookup_client("nice-cactus") == :error end)
      assert BrowserSessions.list_clients() == []
    end
  end

  describe "run/4" do
    test "routes to the client owning the sid" do
      start_client("nice-cactus", fn sid, name, input ->
        %{"text" => "ran #{name} with #{input.code} in #{sid}", "isError" => false}
      end)

      assert {:ok, %{"text" => "ran browser_eval with 1+1 in nice-cactus#1"}} =
               BrowserSessions.run("nice-cactus#1", "browser_eval", %{code: "1+1"}, 1_000)
    end

    test "errors on a malformed sid" do
      assert {:error, :invalid_sid} =
               BrowserSessions.run("no-hash", "browser_eval", %{code: ""}, 100)
    end

    test "errors when no client owns the sid" do
      assert {:error, :unknown_client} =
               BrowserSessions.run("ghost#1", "browser_eval", %{code: ""}, 100)
    end

    test "times out when the client never replies" do
      start_client("slow-otter", :silent)

      assert {:error, :timeout} =
               BrowserSessions.run("slow-otter#1", "browser_eval", %{code: ""}, 50)
    end

    test "reports a disconnect when the client dies mid-request" do
      start_client("dying-comet", :die)

      assert {:error, :disconnected} =
               BrowserSessions.run("dying-comet#1", "browser_eval", %{code: ""}, 1_000)
    end
  end

  describe "broadcast_run/3" do
    test "errors when no client is connected" do
      assert {:error, :no_clients} =
               BrowserSessions.broadcast_run("browser_eval", %{code: ""}, 100)
    end

    test "returns the first reply and passes a nil sid" do
      start_client("first-robin", fn sid, _name, _input ->
        %{"text" => "from #{sid || "handshake"}", "isError" => false, "sid" => "first-robin#1"}
      end)

      assert {:ok, %{"text" => "from handshake", "sid" => "first-robin#1"}} =
               BrowserSessions.broadcast_run("browser_eval", %{code: ""}, 1_000)
    end

    test "times out when clients are silent" do
      start_client("quiet-fjord", :silent)
      assert {:error, :timeout} = BrowserSessions.broadcast_run("browser_eval", %{code: ""}, 50)
    end
  end

  # ── helpers ───────────────────────────────────────────────────────────────

  # Spawns a process that registers itself as a client and services
  # run_tool requests according to `behavior`:
  #
  #   * a function `(sid, input) -> result` — replies with its return value
  #   * `:silent` — never replies (to exercise timeouts)
  #   * `:die`    — exits on the first request (to exercise disconnects)
  defp start_client(
         name,
         behavior \\ fn _sid, _name, _input -> %{"text" => "ok", "isError" => false} end
       ) do
    test = self()

    pid =
      spawn(fn ->
        :ok = BrowserSessions.register_client(name)
        send(test, {:ready, self()})
        client_loop(behavior)
      end)

    on_exit(fn -> stop_client(pid) end)

    assert_receive {:ready, ^pid}, 1_000
    pid
  end

  defp client_loop(behavior) do
    receive do
      {:run_tool, reply_to, sid, name, input} ->
        case behavior do
          :silent ->
            :ok

          :die ->
            exit(:boom)

          fun when is_function(fun) ->
            send(reply_to, {:browser_reply, reply_to, fun.(sid, name, input)})
        end

        client_loop(behavior)

      :stop ->
        :ok
    end
  end

  defp stop_client(pid) do
    if Process.alive?(pid) do
      ref = Process.monitor(pid)
      send(pid, :stop)

      receive do
        {:DOWN, ^ref, :process, ^pid, _} -> :ok
      after
        1_000 -> :ok
      end
    end

    wait_until(fn -> pid not in client_pids() end)
  end

  defp client_pids do
    BrowserSessions.list_clients() |> Enum.map(fn {_name, pid} -> pid end)
  end

  defp wait_until(fun, attempts \\ 100) do
    cond do
      fun.() -> :ok
      attempts == 0 -> flunk("condition was not met in time")
      true -> Process.sleep(10) && wait_until(fun, attempts - 1)
    end
  end
end
