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
      |> Tidewave.call([])

    assert conn.status == 403

    conn =
      conn(:post, "/tidewave/mcp/message")
      |> put_req_header("origin", "http://localhost:4000")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call([])

    # missing session id
    assert conn.status == 400
  end

  test "raises when no origin is configured and no endpoint set" do
    assert_raise RuntimeError,
                 ~r/You must manually configure the allowed origins/,
                 fn ->
                   conn(:post, "/tidewave/mcp/message")
                   |> put_req_header("origin", "http://localhost:4000")
                   |> Tidewave.call([])
                 end

    conn =
      conn(:post, "/tidewave/mcp/message")
      |> put_req_header("origin", "http://localhost:4000")
      |> Tidewave.call(allowed_origins: ["http://localhost:4000"])

    assert conn.status == 400
  end

  test "allows requests with no origin header" do
    conn =
      conn(:post, "/tidewave/mcp/message")
      |> Tidewave.call([])

    # missing session id
    assert conn.status == 400
  end

  test "validates content type" do
    assert_raise Plug.Conn.WrapperError, ~r/Plug.Parsers.UnsupportedMediaTypeError/, fn ->
      conn(:post, "/tidewave/mcp/message")
      |> put_req_header("content-type", "multipart/form-data")
      |> Tidewave.call([])
    end
  end

  test "does not allow remote connections by default" do
    conn =
      conn(:get, "/tidewave")
      |> Map.put(:remote_ip, {192, 168, 1, 1})
      |> Tidewave.call([])

    assert conn.status == 403

    assert conn.resp_body =~
             "For security reasons, Tidewave does not accept remote connections by default."

    conn =
      conn(:get, "/tidewave")
      |> Map.put(:remote_ip, {127, 0, 0, 1})
      |> Tidewave.call([])

    assert conn.status == 200

    conn =
      conn(:get, "/tidewave")
      |> Map.put(:remote_ip, {192, 168, 1, 1})
      |> Tidewave.call(allow_remote_access: true)

    assert conn.status == 200
  end

  test "405 when POSTing to /mcp" do
    conn =
      conn(:post, "/tidewave/mcp")
      |> Tidewave.call([])

    assert conn.status == 405
  end
end
