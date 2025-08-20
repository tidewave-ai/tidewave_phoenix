defmodule TidewaveTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  @moduletag :capture_log

  defmodule Endpoint do
    def url, do: "http://localhost:4000"
  end

  defmodule TestOriginValidator do
    def check_origin(_conn, origin, allowed_port) do
      origin == "http://localhost:#{allowed_port}"
    end

    def always_allow(_conn, _origin), do: true
    def always_deny(_conn, _origin), do: false
  end

  test "validates allowed origins for message requests" do
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4001")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 403

    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4000")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    # invalid JSON-RPC message (empty body)
    assert conn.status == 200
    assert conn.resp_body =~ "Could not parse message"
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
      |> Tidewave.call(Tidewave.init(allowed_origins: ["http://localhost:4000"]))

    # invalid JSON-RPC message (empty body)
    assert conn.status == 200
    assert conn.resp_body =~ "Could not parse message"
  end

  test "allows requests with no origin header" do
    conn =
      conn(:post, "/tidewave/mcp")
      |> Tidewave.call(Tidewave.init([]))

    # invalid JSON-RPC message (empty body)
    assert conn.status == 200
    assert conn.resp_body =~ "Could not parse message"
  end

  test "validates origins with regex patterns" do
    # Should reject non-matching origin
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://example.com")
      |> Tidewave.call(Tidewave.init(allowed_origins: [~r/^https?:\/\/localhost/]))

    assert conn.status == 403

    # Should accept matching origin
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4001")
      |> Tidewave.call(Tidewave.init(allowed_origins: [~r/^https?:\/\/localhost/]))

    # invalid JSON-RPC message (empty body)
    assert conn.status == 200
    assert conn.resp_body =~ "Could not parse message"
  end

  test "validates origins with MFA tuples" do
    # MFA with additional arguments
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:5000")
      |> Tidewave.call(
        Tidewave.init(
          allowed_origins: [{TidewaveTest.TestOriginValidator, :check_origin, [5000]}]
        )
      )

    assert conn.status == 200

    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4000")
      |> Tidewave.call(
        Tidewave.init(
          allowed_origins: [{TidewaveTest.TestOriginValidator, :check_origin, [5000]}]
        )
      )

    assert conn.status == 403

    # MFA without additional arguments  
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://anything.com")
      |> Tidewave.call(
        Tidewave.init(allowed_origins: [{TidewaveTest.TestOriginValidator, :always_allow, []}])
      )

    assert conn.status == 200

    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://anything.com")
      |> Tidewave.call(
        Tidewave.init(allowed_origins: [{TidewaveTest.TestOriginValidator, :always_deny, []}])
      )

    assert conn.status == 403
  end

  test "validates origins with mixed patterns" do
    allowed_origins = [
      "http://localhost:4000",
      ~r/^https:\/\/.*\.example\.com$/,
      {TidewaveTest.TestOriginValidator, :always_allow, []}
    ]

    # Should accept exact string match
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4000")
      |> Tidewave.call(Tidewave.init(allowed_origins: allowed_origins))

    assert conn.status == 200

    # Should accept regex match
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "https://app.example.com")
      |> Tidewave.call(Tidewave.init(allowed_origins: allowed_origins))

    assert conn.status == 200

    # Should accept MFA match
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://anything.test")
      |> Tidewave.call(Tidewave.init(allowed_origins: allowed_origins))

    assert conn.status == 200

    # Should reject non-matching origin
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://evil.com")
      |> Tidewave.call(
        Tidewave.init(
          allowed_origins: [
            "http://localhost:4000",
            ~r/^https:\/\/.*\.example\.com$/,
            {TidewaveTest.TestOriginValidator, :always_deny, []}
          ]
        )
      )

    assert conn.status == 403
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

  describe "/mcp" do
    test "405 when GETing" do
      conn =
        conn(:get, "/tidewave/mcp")
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 405
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
end
