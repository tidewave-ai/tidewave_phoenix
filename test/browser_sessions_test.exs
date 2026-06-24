defmodule Tidewave.BrowserSessionsTest do
  # The registry is a globally-named singleton, so these tests share it and
  # cannot run concurrently with each other.
  use ExUnit.Case, async: false

  alias Tidewave.BrowserSessions

  defmodule TestClient do
    use Task

    def start_link(arg) do
      Task.start_link(__MODULE__, :run, [arg])
    end

    def run(args) do
      test = Keyword.fetch!(args, :test)
      name = Keyword.fetch!(args, :name)

      behavior =
        Keyword.get(args, :behavior, fn _sid, _name, _input ->
          %{"text" => "ok", "isError" => false}
        end)

      :ok = BrowserSessions.register_client(name)
      send(test, {:ready, self()})
      client_loop(behavior)
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
  end

  describe "register_client/2" do
    test "registers and is discoverable" do
      pid = start_supervised!({TestClient, test: self(), name: "nice-cactus"})

      receive do
        {:ready, ^pid} -> :ok
      end

      assert {:ok, ^pid} = BrowserSessions.lookup_client("nice-cactus")
      assert [{"nice-cactus", ^pid}] = BrowserSessions.list_clients()
    end

    test "rejects a duplicate name from another process" do
      pid = start_supervised!({TestClient, test: self(), name: "nice-cactus"})

      receive do
        {:ready, ^pid} -> :ok
      end

      assert {:error, :name_taken} = BrowserSessions.register_client("nice-cactus")
    end

    test "is idempotent for the same process" do
      assert :ok = BrowserSessions.register_client("nice-cactus")
      assert :ok = BrowserSessions.register_client("nice-cactus")
    end

    test "forgets a client when it dies" do
      pid = start_supervised!({TestClient, test: self(), name: "nice-cactus"})

      receive do
        {:ready, ^pid} -> :ok
      end

      assert {:ok, ^pid} = BrowserSessions.lookup_client("nice-cactus")

      Process.exit(pid, :kill)

      wait_until(fn -> BrowserSessions.lookup_client("nice-cactus") == :error end)
      assert BrowserSessions.list_clients() == []
    end
  end

  describe "run/4" do
    test "routes to the client owning the sid" do
      pid =
        start_supervised!(
          {TestClient,
           test: self(),
           name: "nice-cactus",
           behavior: fn sid, name, input ->
             %{"text" => "ran #{name} with #{input.code} in #{sid}", "isError" => false}
           end}
        )

      receive do
        {:ready, ^pid} -> :ok
      end

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
      pid = start_supervised!({TestClient, test: self(), name: "slow-otter", behavior: :silent})

      receive do
        {:ready, ^pid} -> :ok
      end

      assert {:error, :timeout} =
               BrowserSessions.run("slow-otter#1", "browser_eval", %{code: ""}, 50)
    end

    test "reports a disconnect when the client dies mid-request" do
      pid = start_supervised!({TestClient, test: self(), name: "dying-comet", behavior: :die})

      receive do
        {:ready, ^pid} -> :ok
      end

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
      start_supervised!(
        {TestClient,
         test: self(),
         name: "first-robin",
         behavior: fn sid, _name, _input ->
           %{"text" => "from #{sid || "handshake"}", "isError" => false, "sid" => "first-robin#1"}
         end}
      )

      assert {:ok, %{"text" => "from handshake", "sid" => "first-robin#1"}} =
               BrowserSessions.broadcast_run("browser_eval", %{code: ""}, 1_000)
    end

    test "times out when clients are silent" do
      pid = start_supervised!({TestClient, test: self(), name: "quiet-fjord", behavior: :silent})

      receive do
        {:ready, ^pid} -> :ok
      end

      assert {:error, :timeout} = BrowserSessions.broadcast_run("browser_eval", %{code: ""}, 50)
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
