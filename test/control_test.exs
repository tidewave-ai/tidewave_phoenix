defmodule Tidewave.ControlTest do
  use ExUnit.Case, async: true

  import Plug.Test

  @moduletag :capture_log

  defmodule Endpoint do
    def config(:url), do: [host: "app.example.com"]
  end

  describe "/tidewave/connect" do
    test "uses the control entrypoint" do
      conn = conn(:get, "http://localhost/tidewave/connect") |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200
      assert get_resp_header_value(conn, "content-type") =~ "text/html"

      assert get_resp_header_value(conn, "content-security-policy") ==
               "base-uri 'self'; frame-ancestors 'self';"

      assert conn.resp_body =~ "/tc/control.js"
    end
  end

  describe "/tidewave/ws" do
    test "allows a websocket upgrade from an allowed origin" do
      conn =
        ws_conn()
        |> Plug.Conn.put_req_header("origin", "http://control.example.com")
        |> Tidewave.call(Tidewave.init(allowed_origins: ["//control.example.com"]))

      assert conn.status == nil
    end

    test "allows a websocket upgrade from an allowed full origin" do
      conn =
        ws_conn()
        |> Plug.Conn.put_req_header("origin", "http://control.example.com:4000")
        |> Tidewave.call(Tidewave.init(allowed_origins: ["http://control.example.com:4000"]))

      assert conn.status == nil
    end

    test "allows a websocket upgrade from the same host as an allowed port-less origin" do
      conn =
        ws_conn()
        |> Plug.Conn.put_req_header("origin", "http://control.example.com:5173")
        |> Tidewave.call(Tidewave.init(allowed_origins: ["//control.example.com"]))

      assert conn.status == nil
    end

    test "allows a websocket upgrade from a wildcard origin" do
      conn =
        ws_conn()
        |> Plug.Conn.put_req_header("origin", "http://control.example.com")
        |> Tidewave.call(Tidewave.init(allowed_origins: ["//*.example.com"]))

      assert conn.status == nil
    end

    test "allows a websocket upgrade from the same origin" do
      conn =
        ws_conn("localhost:4000")
        |> Plug.Conn.put_req_header("origin", "http://localhost:4000")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == nil

      conn =
        ws_conn("localhost")
        |> Plug.Conn.put_req_header("origin", "http://localhost")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == nil

      conn =
        ws_conn("[::1]:4000")
        |> Plug.Conn.put_req_header("origin", "http://[::1]:4000")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == nil
    end

    test "allows a websocket upgrade with sec-fetch-site same-origin" do
      # Origin and Host may differ when a proxy rewrites the Host header
      conn =
        ws_conn("localhost:4000")
        |> Plug.Conn.put_req_header("origin", "http://localhost:5173")
        |> Plug.Conn.put_req_header("sec-fetch-site", "same-origin")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == nil
    end

    test "rejects a websocket upgrade from another port on the same host" do
      conn =
        ws_conn("localhost:4000")
        |> Plug.Conn.put_req_header("origin", "http://localhost:5173")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 403

      conn =
        ws_conn("localhost")
        |> Plug.Conn.put_req_header("origin", "https://localhost")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 403
    end

    test "rejects a websocket upgrade with sec-fetch-site other than same-origin" do
      for site <- ["same-site", "cross-site", "none"] do
        conn =
          ws_conn("localhost:4000")
          |> Plug.Conn.put_req_header("origin", "http://localhost:4000")
          |> Plug.Conn.put_req_header("sec-fetch-site", site)
          |> Tidewave.call(Tidewave.init([]))

        assert conn.status == 403, "expected #{site} to be rejected"
      end
    end

    test "rejects a websocket upgrade from a foreign origin" do
      conn =
        ws_conn()
        |> Plug.Conn.put_req_header("origin", "http://evil.example.com")
        |> Plug.Conn.put_private(:phoenix_endpoint, Endpoint)
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 403

      conn =
        ws_conn()
        |> Plug.Conn.put_req_header("origin", "null")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 403
    end

    test "raises when no allowed origins or phoenix endpoint are configured" do
      assert_raise RuntimeError, ~r/allowed_origins/, fn ->
        conn(:get, "http://app.example.com/tidewave/ws")
        |> Plug.Conn.put_req_header("origin", "http://app.example.com")
        |> Tidewave.call(Tidewave.init([]))
      end
    end

    test "raises on invalid allowed origin configuration" do
      assert_raise ArgumentError,
                   ~r/invalid :allowed_origins value.*Expected an origin with a host/,
                   fn ->
                     ws_conn()
                     |> Plug.Conn.put_req_header("origin", "http://app.example.com")
                     |> Tidewave.call(Tidewave.init(allowed_origins: ["invalid-origin"]))
                   end
    end
  end

  describe "/tidewave/upload" do
    test "rejects uploads from another port on the same host" do
      conn =
        conn(:post, "http://localhost:4000/tidewave/upload")
        |> Map.update!(:req_headers, &[{"host", "localhost:4000"} | &1])
        |> Plug.Conn.put_req_header("origin", "http://localhost:5173")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 403
    end
  end

  defp get_resp_header_value(conn, key) do
    case Plug.Conn.get_resp_header(conn, key) do
      [value | _] -> value
      [] -> nil
    end
  end

  defp ws_conn(host \\ "localhost") do
    conn(:get, "http://#{host}/tidewave/ws")
    |> Map.update!(:req_headers, &[{"host", host} | &1])
    |> Plug.Conn.put_req_header("connection", "upgrade")
    |> Plug.Conn.put_req_header("upgrade", "websocket")
    |> Plug.Conn.put_req_header("sec-websocket-key", "test-key")
    |> Plug.Conn.put_req_header("sec-websocket-version", "13")
  end
end
