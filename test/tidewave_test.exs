defmodule TidewaveTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  @moduletag :capture_log

  defmodule Endpoint do
    def url, do: "http://localhost:4000"
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
