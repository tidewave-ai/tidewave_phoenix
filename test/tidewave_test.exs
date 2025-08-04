defmodule TidewaveTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  defmodule Endpoint do
    def url, do: "http://localhost:4000"
  end

  test "validates allowed origins for message requests" do
    conn =
      conn(:post, "/tidewave/mcp/message")
      |> put_req_header("origin", "http://localhost:4001")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 403

    conn =
      conn(:post, "/tidewave/mcp/message")
      |> put_req_header("origin", "http://localhost:4000")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    # missing session id
    assert conn.status == 400
  end

  test "raises when no origin is configured and no endpoint set" do
    assert_raise RuntimeError,
                 ~r/You must manually configure the allowed origins/,
                 fn ->
                   conn(:post, "/tidewave/mcp/message")
                   |> put_req_header("origin", "http://localhost:4000")
                   |> Tidewave.call(Tidewave.init([]))
                 end

    conn =
      conn(:post, "/tidewave/mcp/message")
      |> put_req_header("origin", "http://localhost:4000")
      |> Tidewave.call(Tidewave.init(allowed_origins: ["http://localhost:4000"]))

    assert conn.status == 400
  end

  test "allows requests with no origin header" do
    conn =
      conn(:post, "/tidewave/mcp/message")
      |> Tidewave.call(Tidewave.init([]))

    # missing session id
    assert conn.status == 400
  end

  test "validates content type" do
    assert_raise Plug.Conn.WrapperError, ~r/Plug.Parsers.UnsupportedMediaTypeError/, fn ->
      conn(:post, "/tidewave/mcp/message")
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
    test "405 when POSTing" do
      conn =
        conn(:post, "/tidewave/mcp")
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

      assert conn.resp_body == """
             hello world

             <tidewave_done>{"status":0}\
             """
    end

    test "handles command with non-zero exit status" do
      body = %{command: "exit 42"}

      conn =
        conn(:post, "/tidewave/shell", Jason.encode!(body))
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200

      assert conn.resp_body == """

             <tidewave_done>{"status":42}\
             """
    end

    test "handles multiline commands" do
      body = %{
        command: """
        echo 'line 1'
        echo 'line 2'
        """
      }

      conn =
        conn(:post, "/tidewave/shell", Jason.encode!(body))
        |> Tidewave.call(Tidewave.init([]))

      assert conn.status == 200

      assert conn.resp_body == """
             line 1
             line 2

             <tidewave_done>{"status":0}\
             """
    end
  end
end
