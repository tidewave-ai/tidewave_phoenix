defmodule Tidewave.MCP.Tools.EctoTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Ecto

  describe "tools/0" do
    test "returns list of tools when repos are configured" do
      assert tools = Ecto.tools()
      assert execute_sql_query = Enum.find(tools, &(&1.name == "execute_sql_query"))
      assert execute_sql_query.inputSchema.properties.repo.description =~ "MockRepo"
      assert [execute_sql_query] == tools
    end
  end

  describe "execute_sql_query/3" do
    test "uses first repo from list of configured repos when no repo is passed" do
      assert {:ok, _} =
               Ecto.execute_sql_query(
                 %{"query" => "SELECT 1", "arguments" => []},
                 Tidewave.init([])
               )
    end

    test "successfully executes a query" do
      {:ok, text} =
        Ecto.execute_sql_query(
          %{
            "repo" => "MockRepo",
            "query" => "SELECT 1",
            "arguments" => []
          },
          Tidewave.init([])
        )

      assert text =~ "rows: [[1]]"
      assert text =~ "columns: [\"?column?\"]"
    end

    test "handles query with parameters" do
      {:ok, text} =
        Ecto.execute_sql_query(
          %{
            "repo" => "MockRepo",
            "query" => "SELECT $1::text",
            "arguments" => ["test"]
          },
          Tidewave.init([])
        )

      assert text =~ "rows: [[\"test\"]]"
    end

    test "truncates rows" do
      {:ok, text} =
        Ecto.execute_sql_query(
          %{
            "repo" => "MockRepo",
            "query" => "SELECT lotsofrows",
            "arguments" => []
          },
          Tidewave.init([])
        )

      assert text =~ "Query returned 100 rows. Only the first 50 rows are included in the result."
      assert text =~ "42"
    end

    test "returns error for failed query" do
      {:error, message} =
        Ecto.execute_sql_query(
          %{
            "repo" => "MockRepo",
            "query" => "ERROR",
            "arguments" => []
          },
          Tidewave.init([])
        )

      assert message =~ "Failed to execute query"
      assert message =~ "Query error"
    end

    test "prints charlists as lists by default" do
      {:ok, text} =
        Ecto.execute_sql_query(
          %{
            "repo" => "MockRepo",
            "query" => "SELECT charlist",
            "arguments" => []
          },
          Tidewave.init([])
        )

      assert text =~ "rows: [97, 98, 99]"
    end

    test "inspect_opts" do
      {:ok, text} =
        Ecto.execute_sql_query(
          %{
            "repo" => "MockRepo",
            "query" => "SELECT lotsofrows",
            "arguments" => []
          },
          Tidewave.init([])
        )

      assert text =~ "Query returned 100 rows. Only the first 50 rows are included in the result."
      refute text =~ "51"
    end
  end
end
