defmodule Tidewave.ControlPlaneTest do
  use ExUnit.Case, async: true

  import Plug.Test

  @moduletag :capture_log

  # The test environment enables the control plane (see config/config.exs).

  describe "/tidewave" do
    test "advertises the control plane via a meta tag when enabled" do
      conn = conn(:get, "/tidewave") |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200
      assert get_resp_header_value(conn, "content-type") =~ "text/html"
      assert conn.resp_body =~ ~s(<meta name="tidewave:control-plane" content="enabled" />)
      assert conn.resp_body =~ "/tc/tc.js"
    end
  end

  describe "/tidewave/ws" do
    test "rejects a websocket upgrade from a foreign origin" do
      conn =
        conn(:get, "/tidewave/ws")
        |> Plug.Conn.put_req_header("origin", "http://evil.example.com")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 403
    end
  end

  describe "tools" do
    test "browser_eval is registered when the control plane is enabled" do
      {_tools, dispatch} = Tidewave.MCP.Server.tools_and_dispatch()

      assert Map.has_key?(dispatch, "browser_eval")
      refute Map.has_key?(dispatch, "browser_session")
    end
  end

  defp get_resp_header_value(conn, key) do
    case Plug.Conn.get_resp_header(conn, key) do
      [value | _] -> value
      [] -> nil
    end
  end
end
