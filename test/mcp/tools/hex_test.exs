defmodule Tidewave.MCP.Tools.HexTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tool
  alias Tidewave.MCP.Tools.Hex

  setup do
    Req.Test.set_req_test_from_context(%{})
    :ok
  end

  describe "search_package_docs/1" do
    test "successfully searches documentation" do
      Req.Test.stub(Tidewave.MCP.Tools.Hex, fn conn ->
        assert conn.query_params["filter_by"] =~ "plug"

        Req.Test.json(conn, %{
          "found" => 1,
          "hits" => [
            %{
              "document" => %{
                "title" => "Phoenix.Controller",
                "package" => "phoenix-1.8.0",
                "ref" => "Phoenix.Controller.html",
                "doc" => "Controller functionality for Phoenix"
              }
            }
          ]
        })
      end)

      assert {:ok, result} =
               Tool.dispatch(
                 Hex.search_package_docs_tool(),
                 %{"q" => "controller"},
                 Tidewave.init([])
               )

      assert result == """
             Results: 1

             <result index="0" package="phoenix-1.8.0" ref="Phoenix.Controller.html" title="Phoenix.Controller">
             Controller functionality for Phoenix
             </result>
             """
    end

    test "can provide list of packages" do
      Req.Test.stub(Tidewave.MCP.Tools.Hex, fn conn ->
        case conn.host do
          "hex.pm" ->
            Req.Test.json(conn, %{
              "releases" => [%{"version" => "1.7.29"}, %{"version" => "1.7.35"}]
            })

          "search.hexdocs.pm" ->
            assert conn.query_params["filter_by"] == "package:=[phoenix-1.7.35]"

            Req.Test.json(conn, %{
              "found" => 1,
              "hits" => [
                %{
                  "document" => %{
                    "title" => "Phoenix.Controller",
                    "package" => "phoenix-1.8.0",
                    "ref" => "Phoenix.Controller.html",
                    "doc" => "Controller functionality for Phoenix"
                  }
                }
              ]
            })
        end
      end)

      assert {:ok, _} =
               Tool.dispatch(
                 Hex.search_package_docs_tool(),
                 %{
                   "q" => "controller",
                   "packages" => ["phoenix"]
                 },
                 Tidewave.init([])
               )
    end
  end
end
