defmodule Tidewave.MCP.Tools.DesignCanvasTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  alias Tidewave.MCP.Tools.DesignCanvas

  @canvas_html "<!doctype html>\n<html>canvas</html>"
  @port 9101

  defmodule ClientPlug do
    @behaviour Plug

    import Plug.Conn

    @impl true
    def init(opts), do: opts

    @impl true
    def call(%{request_path: "/tc/data/canvas.json"} = conn, _opts) do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, Jason.encode!(%{html: "<!doctype html>\n<html>canvas</html>"}))
    end

    def call(conn, _opts), do: send_resp(conn, 404, "not found")
  end

  setup do
    start_supervised!({Bandit, plug: ClientPlug, port: @port, startup_log: false}, shutdown: 10)

    Application.put_env(:tidewave, :client_url, "http://localhost:#{@port}")
    on_exit(fn -> Application.delete_env(:tidewave, :client_url) end)

    :ok
  end

  describe "tools/0" do
    test "returns list of available tools" do
      tools = DesignCanvas.tools()

      assert is_list(tools)
      assert length(tools) == 1
      assert Enum.any?(tools, &(&1.name == "create_design_canvas"))
    end
  end

  describe "create_design_canvas/1" do
    @describetag :tmp_dir

    test "creates the canvas file, including parent directories", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "designs/canvas.html")

      assert {:ok, text} = DesignCanvas.create_design_canvas(%{"path" => path})
      assert text =~ "Design canvas created at: <path>#{path}</path>"
      assert File.read!(path) == @canvas_html
    end

    test "returns error for a relative path" do
      assert {:error, message} = DesignCanvas.create_design_canvas(%{"path" => "canvas.html"})
      assert message =~ "must be an absolute path"
    end

    test "returns error for a path without .html extension", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "canvas.txt")

      assert {:error, message} = DesignCanvas.create_design_canvas(%{"path" => path})
      assert message =~ "must be an absolute path with the .html file extension"
    end

    test "returns error when the file already exists", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "canvas.html")
      File.write!(path, "existing")

      assert {:error, message} = DesignCanvas.create_design_canvas(%{"path" => path})
      assert message =~ "the file already exists"
      assert File.read!(path) == "existing"
    end

    test "returns error when the template cannot be fetched", %{tmp_dir: tmp_dir} do
      Application.put_env(:tidewave, :client_url, "http://localhost:#{@port}/unknown")

      path = Path.join(tmp_dir, "canvas.html")

      assert {:error, message} = DesignCanvas.create_design_canvas(%{"path" => path})
      assert message =~ "Failed to fetch the design canvas template"
      refute File.exists?(path)
    end
  end
end
