defmodule Tidewave.ControlPlaneTest do
  use ExUnit.Case, async: true

  import Plug.Test

  @moduletag :capture_log

  defmodule Endpoint do
    def config(:url), do: [host: "app.example.com"]
  end

  describe "/tidewave" do
    test "uses the control entrypoint" do
      conn = conn(:get, "/tidewave") |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200
      assert get_resp_header_value(conn, "content-type") =~ "text/html"
      assert conn.resp_body =~ "/tc/tc.js?entrypoint=control"
    end
  end

  describe "/tidewave/ws" do
    test "allows a websocket upgrade from an allowed origin" do
      conn =
        ws_conn()
        |> Plug.Conn.put_req_header("origin", "http://control.example.com")
        |> Tidewave.call(Tidewave.init(allowed_origins: ["control.example.com"]))

      assert conn.status == nil
    end

    test "falls back to the phoenix endpoint url host" do
      conn =
        ws_conn()
        |> Plug.Conn.put_req_header("origin", "http://app.example.com")
        |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == nil
    end

    test "rejects a websocket upgrade from a foreign origin" do
      conn =
        conn(:get, "/tidewave/ws")
        |> Plug.Conn.put_req_header("origin", "http://evil.example.com")
        |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 403
    end

    test "raises when no allowed origins or phoenix endpoint are configured" do
      assert_raise RuntimeError, ~r/allowed_origins/, fn ->
        conn(:get, "/tidewave/ws")
        |> Plug.Conn.put_req_header("origin", "http://app.example.com")
        |> Tidewave.call(Tidewave.init([]))
      end
    end
  end

  defp get_resp_header_value(conn, key) do
    case Plug.Conn.get_resp_header(conn, key) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp ws_conn do
    conn(:get, "http://localhost/tidewave/ws")
    |> Map.update!(:req_headers, &[{"host", "localhost"} | &1])
    |> Plug.Conn.put_req_header("connection", "upgrade")
    |> Plug.Conn.put_req_header("upgrade", "websocket")
    |> Plug.Conn.put_req_header("sec-websocket-key", "test-key")
    |> Plug.Conn.put_req_header("sec-websocket-version", "13")
  end
end
