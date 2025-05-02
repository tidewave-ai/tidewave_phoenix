defmodule Tidewave.MCP.Tools.HexTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Hex

  setup do
    Req.Test.set_req_test_from_context(%{})
    :ok
  end

  describe "package_docs_search/1" do
    test "successfully searches documentation" do
      Req.Test.stub(Tidewave.MCP.Tools.Hex, fn conn ->
        assert conn.query_params["filter_by"] =~ "plug"

        Req.Test.json(conn, %{
          "hits" => [
            %{
              "title" => "Phoenix.Controller",
              "doc" => "Controller functionality for Phoenix"
            }
          ]
        })
      end)

      assert {:ok, _} = Hex.package_docs_search(%{"q" => "controller"})
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
              "hits" => [
                %{
                  "title" => "Phoenix.Controller",
                  "doc" => "Controller functionality for Phoenix"
                }
              ]
            })
        end
      end)

      assert {:ok, _} =
               Hex.package_docs_search(%{
                 "q" => "controller",
                 "packages" => ["phoenix"]
               })
    end
  end

  describe "package_search/1" do
    test "successfully searches packages" do
      Req.Test.stub(Tidewave.MCP.Tools.Hex, fn conn ->
        Req.Test.json(conn, %{
          "packages" => [
            %{
              "name" => "phoenix",
              "description" => "Productive. Reliable. Fast.",
              "latest_version" => "1.8.0"
            }
          ]
        })
      end)

      assert {:ok, response} = Hex.package_search(%{"search" => "phoenix"})
      [phoenix] = Jason.decode!(response)
      assert phoenix == %{"name" => "phoenix", "latest_version" => "1.8.0"}
    end

    test "includes sort parameter when provided" do
      Req.Test.stub(Tidewave.MCP.Tools.Hex, fn conn ->
        assert conn.query_params["sort"] == "downloads"
        Req.Test.json(conn, %{"packages" => []})
      end)

      assert {:ok, _} = Hex.package_search(%{"search" => "phoenix", "sort" => "downloads"})
    end
  end
end
