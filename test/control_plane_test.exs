defmodule Tidewave.ControlPlaneTest do
  use ExUnit.Case, async: true

  import Plug.Test

  @moduletag :capture_log

  # The test environment enables the control plane (see config/config.exs).

  describe "/tidewave/control" do
    test "serves the control page" do
      conn = conn(:get, "/tidewave/control") |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200
      assert get_resp_header_value(conn, "content-type") =~ "text/html"
      assert conn.resp_body =~ "Tidewave Control"
      assert conn.resp_body =~ ~s|new Socket("/tidewave/socket")|
      assert conn.resp_body =~ ~s|src="/tidewave/phoenix.js"|
    end
  end

  describe "/tidewave/phoenix.js" do
    test "serves the bundled phoenix.js" do
      conn = conn(:get, "/tidewave/phoenix.js") |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200
      assert get_resp_header_value(conn, "content-type") =~ "text/javascript"
      assert conn.resp_body =~ "Phoenix"
    end
  end

  describe "tools" do
    test "browser tools are registered when the control plane is enabled" do
      {_tools, dispatch} = Tidewave.MCP.Server.tools_and_dispatch()

      assert Map.has_key?(dispatch, "browser_session")
      assert Map.has_key?(dispatch, "browser_eval")
    end
  end

  defp get_resp_header_value(conn, key) do
    case Plug.Conn.get_resp_header(conn, key) do
      [value | _] -> value
      [] -> nil
    end
  end
end
