defmodule TidewaveTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  @moduletag :capture_log

  defmodule Endpoint do
    def struct_url, do: URI.parse("http://localhost:4000")
  end

  test "/mcp and /config refuse requests with origin header" do
    # /mcp should refuse any request with origin header
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4001")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 403

    # /config should refuse any request with origin header
    conn =
      conn(:get, "/tidewave/config")
      |> put_req_header("origin", "http://localhost:4000")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 403
  end

  test "/ (root) allows any origin" do
    # / should allow any origin
    conn =
      conn(:get, "/tidewave")
      |> put_req_header("origin", "http://example.com")
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 200

    conn =
      conn(:get, "/tidewave")
      |> put_req_header("origin", "http://localhost:4000")
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 200
  end

  test "allows requests with no origin header" do
    conn =
      conn(:post, "/tidewave/mcp")
      |> Tidewave.call(Tidewave.init([]))

    # invalid JSON-RPC message (empty body)
    assert conn.status == 200
    assert conn.resp_body =~ "Could not parse message"
  end

  test "validates content type" do
    assert_raise Plug.Conn.WrapperError, ~r/Plug.Parsers.UnsupportedMediaTypeError/, fn ->
      conn(:post, "/tidewave/mcp")
      |> put_req_header("content-type", "multipart/form-data")
      |> Tidewave.call(Tidewave.init([]))
    end
  end

  test "does not allow remote connections by default" do
    conn =
      conn(:get, "/tidewave")
      |> Map.put(:remote_ip, {192, 168, 1, 1})
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 403

    assert conn.resp_body =~
             "For security reasons, Tidewave does not accept remote connections by default."

    conn =
      conn(:get, "/tidewave")
      |> Map.put(:remote_ip, {127, 0, 0, 1})
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 200

    conn =
      conn(:get, "/tidewave")
      |> Map.put(:remote_ip, {192, 168, 1, 1})
      |> Tidewave.call(Tidewave.init(allow_remote_access: true))

    assert conn.status == 200
  end

  test "removes X-Frame-Options headers if set" do
    conn =
      conn(:get, "/foo")
      |> Plug.Conn.put_resp_header("x-frame-options", "DENY")
      |> Tidewave.call(Tidewave.init([]))
      |> Plug.Conn.send_resp(200, "foo")

    assert Plug.Conn.get_resp_header(conn, "x-frame-options") == []
  end

  test "updates CSP header if set" do
    conn =
      conn(:get, "/foo")
      |> Plug.Conn.put_resp_header(
        "content-security-policy",
        "default-src 'self' http://example.com; connect-src 'none'; script-src 'self'; frame-ancestors 'none'"
      )
      |> Tidewave.call(Tidewave.init([]))
      |> Plug.Conn.send_resp(200, "foo")

    assert Plug.Conn.get_resp_header(conn, "content-security-policy") == [
             "default-src 'self' http://example.com; connect-src 'none'; script-src 'unsafe-eval' 'self'"
           ]
  end

  test "updates CSP headers with flags and trailing space" do
    conn =
      conn(:get, "/foo")
      |> Plug.Conn.put_resp_header(
        "content-security-policy",
        "upgrade-insecure-requests; script-src 'self'; frame-ancestors 'none';   "
      )
      |> Tidewave.call(Tidewave.init([]))
      |> Plug.Conn.send_resp(200, "foo")

    assert Plug.Conn.get_resp_header(conn, "content-security-policy") ==
             ["upgrade-insecure-requests; script-src 'unsafe-eval' 'self'; "]
  end

  describe "/mcp" do
    test "405 when GETing" do
      conn =
        conn(:get, "/tidewave/mcp")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 405
    end

    test "404 for .well-known resources lookup" do
      conn =
        conn(:get, "/tidewave/mcp/.well-known/openid-configuration")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 404
    end
  end

  describe "/config" do
    test "returns config" do
      conn = conn(:get, "/tidewave/config") |> Tidewave.call(Tidewave.init([]))

      assert %{
               "framework_type" => "phoenix",
               "project_name" => "tidewave",
               "team" => %{},
               "tidewave_version" => _
             } = Jason.decode!(conn.resp_body)
    end
  end

  describe "clear_logs/0" do
    test "clears all captured logs" do
      require Logger

      Logger.info("log before clear")
      logs = Tidewave.MCP.Logger.get_logs(10)
      assert Enum.any?(logs, &String.contains?(&1, "log before clear"))

      assert :ok = Tidewave.clear_logs()

      logs = Tidewave.MCP.Logger.get_logs(10)
      refute Enum.any?(logs, &String.contains?(&1, "log before clear"))
      assert logs == []
    end

    test "allows fresh logs after clearing" do
      require Logger

      Logger.info("old log")
      Tidewave.clear_logs()
      Logger.info("new log")

      logs = Tidewave.MCP.Logger.get_logs(10)
      refute Enum.any?(logs, &String.contains?(&1, "old log"))
      assert Enum.any?(logs, &String.contains?(&1, "new log"))
    end
  end
end
