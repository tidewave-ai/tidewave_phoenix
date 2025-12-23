defmodule TidewaveTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  @moduletag :capture_log

  defmodule Endpoint do
    def struct_url, do: URI.parse("http://localhost:4000")
  end

  test "validates allowed origins for message requests with endpoint default" do
    # Default is "//localhost" (host only), so any port on localhost should work
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4001")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    # Should pass - same host, different port is allowed
    assert conn.status == 200
    assert conn.resp_body =~ "Could not parse message"

    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4000")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    # Should pass - same host and port
    assert conn.status == 200
    assert conn.resp_body =~ "Could not parse message"

    # Should fail - different host
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://example.com:4000")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 403
  end

  test "validates allowed origins with explicit configuration" do
    # Test exact match with scheme and port
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:3000")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["http://localhost:3000"]))

    assert conn.status == 200
    assert conn.resp_body =~ "Could not parse message"

    # Test rejection when origin doesn't match
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4000")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["http://localhost:3000"]))

    assert conn.status == 403
  end

  test "validates allowed origins with scheme-less patterns" do
    # Test scheme-less pattern matching
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:3000")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["//localhost:3000"]))

    assert conn.status == 200

    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "https://localhost:3000")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["//localhost:3000"]))

    assert conn.status == 200
  end

  test "validates allowed origins with port-less patterns" do
    # Test port-less pattern matching
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:3000")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["//localhost"]))

    assert conn.status == 200

    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "https://localhost:8080")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["//localhost"]))

    assert conn.status == 200
  end

  test "validates allowed origins with wildcard patterns" do
    # Test wildcard subdomain matching
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://app.example.com")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["//*.example.com"]))

    assert conn.status == 200

    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "https://api.example.com:8443")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["//*.example.com"]))

    assert conn.status == 200

    # Test exact domain match with wildcard
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://example.com")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["//*.example.com"]))

    assert conn.status == 200

    # Test rejection when wildcard doesn't match
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://evil.com")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["//*.example.com"]))

    assert conn.status == 403
  end

  test "validates allowed origins with multiple patterns" do
    allowed_origins = ["//localhost", "//*.test.com", "https://secure.example.org:443"]

    # Test first pattern
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:3000")
      |> Tidewave.call(Tidewave.init(allowed_origins: allowed_origins))

    assert conn.status == 200

    # Test second pattern
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://app.test.com")
      |> Tidewave.call(Tidewave.init(allowed_origins: allowed_origins))

    assert conn.status == 200

    # Test third pattern
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "https://secure.example.org:443")
      |> Tidewave.call(Tidewave.init(allowed_origins: allowed_origins))

    assert conn.status == 200

    # Test rejection
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://malicious.com")
      |> Tidewave.call(Tidewave.init(allowed_origins: allowed_origins))

    assert conn.status == 403
  end

  test "raises when no origin is configured and no endpoint set" do
    assert_raise RuntimeError,
                 ~r/You must manually configure the allowed origins/,
                 fn ->
                   conn(:post, "/tidewave/mcp")
                   |> put_req_header("origin", "http://localhost:4000")
                   |> Tidewave.call(Tidewave.init([]))
                 end

    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4000")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["//localhost:4000"]))

    # invalid JSON-RPC message (empty body)
    assert conn.status == 200
    assert conn.resp_body =~ "Could not parse message"
  end

  test "raises on invalid allowed origin configuration" do
    assert_raise ArgumentError,
                 ~r/invalid :allowed_origins value.*Expected an origin with a host/,
                 fn ->
                   conn(:post, "/tidewave/mcp")
                   |> put_req_header("origin", "http://localhost:4000")
                   |> Tidewave.call(Tidewave.init(allowed_origins: ["invalid-origin"]))
                 end

    assert_raise ArgumentError,
                 ~r/invalid :allowed_origins value.*Expected an origin with a host/,
                 fn ->
                   conn(:post, "/tidewave/mcp")
                   |> put_req_header("origin", "http://localhost:4000")
                   |> Tidewave.call(Tidewave.init(allowed_origins: ["/path/only"]))
                 end
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

  describe "/shell" do
    test "executes simple command and returns output with status" do
      body = %{command: "echo 'hello world'"}

      conn =
        conn(:post, "/tidewave/shell", Jason.encode!(body))
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200

      assert conn.resp_body ==
               <<0, 0, 0, 0, 12, "hello world\n", 1, 0, 0, 0, 12, ~S|{"status":0}|>>
    end

    test "handles command with non-zero exit status" do
      body = %{command: "exit 42"}

      conn =
        conn(:post, "/tidewave/shell", Jason.encode!(body))
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200

      assert conn.resp_body == <<1, 0, 0, 0, 13, ~S|{"status":42}|>>
    end

    test "handles multiline commands" do
      body = %{
        command: """
        echo 'line 1'
        sleep 0.1
        echo 'line 2'
        """
      }

      conn =
        conn(:post, "/tidewave/shell", Jason.encode!(body))
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200

      assert conn.resp_body ==
               <<0, 0, 0, 0, 7, "line 1\n", 0, 0, 0, 0, 7, "line 2\n", 1, 0, 0, 0, 12,
                 ~S|{"status":0}|>>
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
