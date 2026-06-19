defmodule Tidewave.ControlSocketTest do
  use ExUnit.Case, async: true

  alias Tidewave.ControlSocket

  test "init starts with no name and no pending requests" do
    assert {:ok, %{name: nil, pending: pending}} = ControlSocket.init(%{})
    assert pending == %{}
  end

  test "forwards a browser_eval as an eval frame and tracks who is waiting" do
    {:ok, state} = ControlSocket.init(%{})
    request_ref = make_ref()

    assert {:push, {:text, json}, state} =
             ControlSocket.handle_info(
               {:browser_eval, request_ref, self(), "nice-cactus@1", %{code: "x"}},
               state
             )

    message = Jason.decode!(json)
    assert message["type"] == "eval"
    assert message["sid"] == "nice-cactus@1"
    assert message["input"] == %{"code" => "x"}

    assert [{ref, {reply_to, ^request_ref}}] = Map.to_list(state.pending)
    assert reply_to == self()
    assert message["ref"] == ref
  end

  test "routes an eval_reply back to the waiting process" do
    {:ok, state} = ControlSocket.init(%{})
    request_ref = make_ref()

    {:push, {:text, json}, state} =
      ControlSocket.handle_info({:browser_eval, request_ref, self(), "a@1", %{code: "x"}}, state)

    ref = Jason.decode!(json)["ref"]
    reply = ~s({"type":"eval_reply","ref":#{ref},"result":{"text":"hi","isError":false}})

    assert {:ok, state} = ControlSocket.handle_in({reply, [opcode: :text]}, state)
    assert state.pending == %{}
    assert_receive {:browser_reply, ^request_ref, %{"text" => "hi", "isError" => false}}
  end

  test "ignores eval_reply for an unknown ref" do
    {:ok, state} = ControlSocket.init(%{})
    reply = ~s({"type":"eval_reply","ref":999,"result":{}})

    assert {:ok, ^state} = ControlSocket.handle_in({reply, [opcode: :text]}, state)
  end

  test "ignores malformed and non-text frames" do
    {:ok, state} = ControlSocket.init(%{})

    assert {:ok, ^state} = ControlSocket.handle_in({"not json", [opcode: :text]}, state)
    assert {:ok, ^state} = ControlSocket.handle_in({<<0, 1>>, [opcode: :binary]}, state)
  end
end
