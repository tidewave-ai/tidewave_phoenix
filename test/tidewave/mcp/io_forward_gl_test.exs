defmodule Tidewave.MCP.StandardErrorTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.StandardError

  defmacrop eventually(interval, tries, fun) do
    quote do
      assert Stream.interval(unquote(interval))
             |> Stream.take(unquote(tries))
             |> Enum.reduce_while(nil, fn _, _ ->
               if unquote(fun).() do
                 {:halt, true}
               else
                 {:cont, false}
               end
             end),
             "expected function to return true after #{unquote(tries)} attempts"
    end
  end

  test "cleans up when owner dies" do
    gl_pid = spawn_link(fn -> Process.sleep(:infinity) end)

    pid =
      spawn(fn ->
        Process.group_leader(self(), gl_pid)

        StandardError.forward(fn ->
          Process.sleep(10000)
        end)
      end)

    eventually(100, 10, fn ->
      Map.has_key?(:sys.get_state(:standard_error).targets, gl_pid)
    end)

    Process.exit(pid, :brutal_kill)

    eventually(100, 10, fn ->
      not Map.has_key?(:sys.get_state(:standard_error).targets, gl_pid)
    end)
  end
end
