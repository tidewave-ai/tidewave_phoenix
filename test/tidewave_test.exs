defmodule TidewaveTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  @moduletag :capture_log

  defmodule Endpoint do
    def struct_url, do: URI.parse("http://localhost:4000")
  end

  test "/mcp refuses requests with origin header" do
    # /mcp should refuse any request with origin header
    conn =
      conn(:post, "/tidewave/mcp")
      |> put_req_header("origin", "http://localhost:4001")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 403
  end

  test "/config allows requests with origin header + CORS" do
    # /config should allow any request with origin header
    conn =
      conn(:get, "/tidewave/config")
      |> put_req_header("origin", "http://localhost:4001")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 200
    assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
  end

  test "/ services entrypoint if given" do
    conn =
      conn(:get, "/tidewave?entrypoint=foo")
      |> put_private(:phoenix_endpoint, Endpoint)
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 200
    assert conn.resp_body =~ "tc.js"
  end

  test "/ (root) allows any origin" do
    # / should allow any origin
    conn =
      conn(:get, "/tidewave")
      |> put_req_header("origin", "http://example.com")
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 302

    conn =
      conn(:get, "/tidewave")
      |> put_req_header("origin", "http://localhost:4000")
      |> Tidewave.call(Tidewave.init([]))

    assert conn.status == 302
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

    assert conn.status == 302

    conn =
      conn(:get, "/tidewave")
      |> Map.put(:remote_ip, {192, 168, 1, 1})
      |> Tidewave.call(Tidewave.init(allow_remote_access: true))

    assert conn.status == 302
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
               "tmp_dir" => "tmp",
               "tidewave_version" => _
             } = Jason.decode!(conn.resp_body)
    end
  end

  describe "/upload" do
    test "validates filenames" do
      upload_dir = Path.expand("tmp/tidewave/screenshots")
      valid_filename = "screenshot-123_abc.jpg"

      on_exit(fn ->
        File.rm_rf(Path.expand("tmp/tidewave"))
      end)

      conn = router_upload_conn(valid_filename)

      assert conn.status == 200

      assert Jason.decode!(conn.resp_body) == %{
               "status" => "ok",
               "path" => "tmp/tidewave/screenshots/#{valid_filename}"
             }

      assert File.read!(Path.join(upload_dir, valid_filename)) == valid_jpg()

      assert_raise Plug.Conn.WrapperError,
                   ~r/filename must only contain numbers, letters, hyphens, and underscores: \.\.\/screenshot\.png/,
                   fn ->
                     router_upload_conn("../screenshot.png")
                   end

      assert_raise Plug.Conn.WrapperError,
                   ~r/filename must only contain numbers, letters, hyphens, and underscores: screenshot png\.jpg/,
                   fn ->
                     router_upload_conn("screenshot png.jpg")
                   end

      assert_raise Plug.Conn.WrapperError,
                   ~r/filename must have a valid extension \(\.png, \.jpg, \.jpeg, \.webm\): screenshot\.gif/,
                   fn ->
                     router_upload_conn("screenshot.gif")
                   end
    end

    test "validates file magic bytes" do
      conn = router_upload_conn("screenshot.jpg", "not an image")

      assert conn.status == 400
      assert conn.resp_body == "Bad Request: missing or invalid file parameter"
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

  defp router_upload_conn(filename, file_contents \\ valid_jpg()) do
    upload_source = Path.join(System.tmp_dir!(), "tidewave-upload-source")
    File.write!(upload_source, file_contents)

    conn(:post, "/upload", %{
      "type" => "screenshot",
      "file" => %Plug.Upload{
        path: upload_source,
        filename: filename,
        content_type: "image/jpeg"
      }
    })
    |> put_private(:tidewave_config, Tidewave.init([]))
    |> Tidewave.Router.call([])
  end

  defp valid_jpg do
    <<0xFF, 0xD8, 0xFF, 0xE0, "JFIF", 0xFF, 0xD9>>
  end
end
