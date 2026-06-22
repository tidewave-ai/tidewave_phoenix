defmodule Tidewave.ControlSocketTest do
  use ExUnit.Case, async: true

  alias Tidewave.ControlSocket

  test "init starts with no name and no pending requests" do
    assert {:ok, %{name: nil, pending: pending}} = ControlSocket.init(%{})
    assert pending == %{}
  end

  test "forwards a run_tool frame and tracks who is waiting" do
    {:ok, state} = ControlSocket.init(%{})
    reply_to = self()

    assert {:push, {:text, json}, state} =
             ControlSocket.handle_info(
               {:run_tool, reply_to, "nice-cactus#1", "browser_eval", %{code: "x"}},
               state
             )

    message = Jason.decode!(json)
    assert message["type"] == "run_tool"
    assert message["name"] == "browser_eval"
    assert message["sid"] == "nice-cactus#1"
    assert message["input"] == %{"code" => "x"}

    assert [{ref, ^reply_to}] = Map.to_list(state.pending)
    assert message["ref"] == ref
  end

  test "routes a tool_reply back to the waiting process" do
    {:ok, state} = ControlSocket.init(%{})
    reply_to = :erlang.alias([:reply])

    {:push, {:text, json}, state} =
      ControlSocket.handle_info({:run_tool, reply_to, "a#1", "browser_eval", %{code: "x"}}, state)

    ref = Jason.decode!(json)["ref"]
    reply = ~s({"type":"tool_reply","ref":#{ref},"result":{"text":"hi","isError":false}})

    assert {:ok, state} = ControlSocket.handle_in({reply, [opcode: :text]}, state)
    assert state.pending == %{}
    assert_receive {:browser_reply, ^reply_to, %{"text" => "hi", "isError" => false}}
  end

  test "ignores tool_reply for an unknown ref" do
    {:ok, state} = ControlSocket.init(%{})
    reply = ~s({"type":"tool_reply","ref":999,"result":{}})

    assert {:ok, ^state} = ControlSocket.handle_in({reply, [opcode: :text]}, state)
  end

  test "ignores malformed and non-text frames" do
    {:ok, state} = ControlSocket.init(%{})

    assert {:ok, ^state} = ControlSocket.handle_in({"not json", [opcode: :text]}, state)
    assert {:ok, ^state} = ControlSocket.handle_in({<<0, 1>>, [opcode: :binary]}, state)
  end
end
