defmodule Tidewave.MCP.Tools.EctoTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tool
  alias Tidewave.MCP.Tools.Ecto

  describe "tools/0" do
    test "returns list of tools when repos are configured" do
      assert tools = Ecto.tools()
      assert Enum.find(tools, &(&1.name == "get_ecto_schemas"))

      assert execute_sql_query = Enum.find(tools, &(&1.name == "execute_sql_query"))
      Tool.input_schema(execute_sql_query)["properties"]["repo"]["description"] =~ "MockRepo"
    end
  end

  describe "execute_sql_query/3" do
    test "uses first repo from list of configured repos when no repo is passed" do
      assert {:ok, _} =
               Tool.dispatch(
                 Ecto.execute_sql_query_tool(),
                 %{"query" => "SELECT 1", "arguments" => []},
                 Tidewave.init([])
               )
    end

    test "successfully executes a query" do
      {:ok, text} =
        Tool.dispatch(
          Ecto.execute_sql_query_tool(),
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
        Tool.dispatch(
          Ecto.execute_sql_query_tool(),
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
        Tool.dispatch(
          Ecto.execute_sql_query_tool(),
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
        Tool.dispatch(
          Ecto.execute_sql_query_tool(),
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
        Tool.dispatch(
          Ecto.execute_sql_query_tool(),
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
        Tool.dispatch(
          Ecto.execute_sql_query_tool(),
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

  describe "get_ecto_schemas/1" do
    test "returns list of Ecto schema modules and their file path" do
      assert {:error, "No Ecto schemas found in the project"} =
               Tool.dispatch(Ecto.get_ecto_schemas_tool(), %{}, Tidewave.init([]))

      {:module, _, bin, _} =
        defmodule Elixir.TestSchema do
          def __changeset__ do
            %{}
          end
        end

      compile_path = Mix.Project.compile_path()
      File.write!("#{compile_path}/Elixir.TestSchema.beam", bin)

      on_exit(fn ->
        File.rm("#{compile_path}/Elixir.TestSchema.beam")
      end)

      {:ok, text} = Tool.dispatch(Ecto.get_ecto_schemas_tool(), %{}, Tidewave.init([]))
      assert text == "* TestSchema at test/mcp/tools/ecto_test.exs"
    end
  end
end
