defmodule Tidewave.BrowserSessionsTest do
  # The registry is a globally-named singleton, so these tests share it and
  # cannot run concurrently with each other.
  use ExUnit.Case, async: false

  alias Tidewave.BrowserSessions

  setup do
    # Each test starts from a clean slate; the previous test's `on_exit`
    # cleanup is given a moment to be processed by the registry.
    wait_until(fn ->
      BrowserSessions.list_controls() == [] and BrowserSessions.list_sessions() == []
    end)

    :ok
  end

  describe "open_session/2" do
    test "assigns a friendly name and is discoverable" do
      start_control()

      assert {:ok, name} = BrowserSessions.open_session("/", 1_000)
      assert name =~ ~r/^[a-z]+-[a-z]+$/

      assert [%{name: ^name}] = BrowserSessions.list_sessions()
      assert {:ok, %{name: ^name}} = BrowserSessions.lookup(name)
    end

    test "errors when no control page is connected" do
      assert {:error, :no_control} = BrowserSessions.open_session("/", 100)
    end

    test "propagates a browser error and forgets the reservation" do
      start_control(:error_open)

      assert {:error, "boom"} = BrowserSessions.open_session("/", 1_000)
      assert BrowserSessions.list_sessions() == []
    end

    test "leaves the registry when the control page dies" do
      pid = start_control()
      assert {:ok, name} = BrowserSessions.open_session("/", 1_000)
      assert {:ok, _} = BrowserSessions.lookup(name)

      stop_control(pid)

      wait_until(fn -> BrowserSessions.lookup(name) == :error end)
      assert BrowserSessions.list_sessions() == []
    end
  end

  describe "resolve_session/1" do
    test "errors when none are connected" do
      assert {:error, :no_sessions} = BrowserSessions.resolve_session()
    end

    test "returns the sole session when one is open" do
      start_control()
      {:ok, name} = BrowserSessions.open_session("/", 1_000)

      assert {:ok, %{name: ^name}} = BrowserSessions.resolve_session()
    end

    test "is ambiguous when several are open" do
      start_control()
      {:ok, name1} = BrowserSessions.open_session("/", 1_000)
      {:ok, name2} = BrowserSessions.open_session("/other", 1_000)

      assert {:error, {:ambiguous, names}} = BrowserSessions.resolve_session()
      assert Enum.sort(names) == Enum.sort([name1, name2])
    end

    test "reports the available names for an unknown session" do
      start_control()
      {:ok, name} = BrowserSessions.open_session("/", 1_000)

      assert {:error, {:unknown, "missing-name", [^name]}} =
               BrowserSessions.resolve_session("missing-name")
    end
  end

  describe "eval/3" do
    test "routes to the sole open session and returns its name" do
      start_control(fn _name, input ->
        %{"text" => "ran: " <> input["code"], "isError" => false}
      end)

      {:ok, name} = BrowserSessions.open_session("/", 1_000)

      assert {:ok, %{"text" => "ran: 1 + 1", "isError" => false}, ^name} =
               BrowserSessions.eval(nil, %{"code" => "1 + 1"}, 1_000)
    end

    test "routes to the named session" do
      start_control(fn name, _input -> %{"text" => name, "isError" => false} end)

      {:ok, name1} = BrowserSessions.open_session("/", 1_000)
      {:ok, name2} = BrowserSessions.open_session("/two", 1_000)

      assert {:ok, %{"text" => ^name1}, ^name1} =
               BrowserSessions.eval(name1, %{"code" => "x"}, 1_000)

      assert {:ok, %{"text" => ^name2}, ^name2} =
               BrowserSessions.eval(name2, %{"code" => "x"}, 1_000)
    end

    test "surfaces the ambiguous error without a session" do
      start_control()
      BrowserSessions.open_session("/", 1_000)
      BrowserSessions.open_session("/two", 1_000)

      assert {:error, {:ambiguous, _names}} =
               BrowserSessions.eval(nil, %{"code" => "x"}, 1_000)
    end

    test "times out when the browser does not reply" do
      pid = start_control(:silent)
      # The control never acks, so register the session directly.
      name = create_session(pid)

      assert {:error, :timeout} = BrowserSessions.eval(name, %{"code" => "x"}, 50)
    end

    test "reports a disconnect when the control dies mid-request" do
      pid = start_control(:die)
      name = create_session(pid)

      assert {:error, :disconnected} = BrowserSessions.eval(name, %{"code" => "x"}, 1_000)
    end
  end

  # ── helpers ───────────────────────────────────────────────────────────────

  # Spawns a process that registers itself as a control page and services
  # open_session/browser_eval requests according to `behavior`:
  #
  #   * a function `(name, input) -> result` — used for browser_eval replies;
  #     open_session is acked with `:ok`
  #   * `:error_open` — replies to open_session with `{:error, "boom"}`
  #   * `:silent`     — never replies (to exercise timeouts)
  #   * `:die`        — exits on the first request (to exercise disconnects)
  defp start_control(behavior \\ fn _name, _input -> %{"text" => "ok", "isError" => false} end) do
    test = self()

    pid =
      spawn(fn ->
        BrowserSessions.register_control()
        send(test, {:control_ready, self()})
        control_loop(behavior)
      end)

    on_exit(fn -> stop_control(pid) end)

    assert_receive {:control_ready, ^pid}, 1_000
    pid
  end

  # Registers a session directly (bypassing the open_session round-trip), for
  # behaviors that never ack an open. The given control must be the most
  # recently registered, since the registry picks that one.
  defp create_session(_control_pid, path \\ "/") do
    {:ok, name, _pid} = GenServer.call(BrowserSessions, {:create_session, path})
    name
  end

  defp stop_control(pid) do
    if Process.alive?(pid) do
      ref = Process.monitor(pid)
      send(pid, :stop)

      receive do
        {:DOWN, ^ref, :process, ^pid, _} -> :ok
      after
        1_000 -> :ok
      end
    end

    wait_until(fn -> pid not in BrowserSessions.list_controls() end)
  end

  defp control_loop(behavior) do
    receive do
      {:open_session, ref, reply_to, _name, _path} ->
        case behavior do
          :silent -> :ok
          :die -> exit(:boom)
          :error_open -> send(reply_to, {:browser_reply, ref, {:error, "boom"}})
          _ -> send(reply_to, {:browser_reply, ref, :ok})
        end

        control_loop(behavior)

      {:browser_eval, ref, reply_to, name, input} ->
        case behavior do
          :silent ->
            :ok

          :die ->
            exit(:boom)

          fun when is_function(fun) ->
            send(reply_to, {:browser_reply, ref, fun.(name, input)})

          _ ->
            send(reply_to, {:browser_reply, ref, %{"text" => "ok", "isError" => false}})
        end

        control_loop(behavior)

      :stop ->
        :ok
    end
  end

  defp wait_until(fun, attempts \\ 100) do
    cond do
      fun.() -> :ok
      attempts == 0 -> flunk("condition was not met in time")
      true -> Process.sleep(10) && wait_until(fun, attempts - 1)
    end
  end
end
