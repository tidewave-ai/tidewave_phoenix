defmodule Tidewave.MCP.Tools.EctoTest do
  use ExUnit.Case, async: true

  alias Tidewave.MCP.Tools.Ecto

  # Create a mock repo module for testing
  defmodule MockRepo do
    def __adapter__ do
      Ecto.Adapters.Postgres
    end

    def query("SELECT 1", []) do
      {:ok, %{rows: [[1]], columns: ["?column?"]}}
    end

    def query("SELECT $1::text", ["test"]) do
      {:ok, %{rows: [["test"]], columns: ["?column?"]}}
    end

    def query("ERROR", _) do
      {:error, %{message: "Query error"}}
    end

    def query("SELECT lotsofrows", _) do
      {:ok, %{rows: Enum.to_list(1..100), num_rows: 100, columns: ["?column?"]}}
    end

    def query("SELECT charlist", _) do
      {:ok, %{rows: ~c"abc", num_rows: 3, columns: ["?column?"]}}
    end
  end

  describe "tools/0" do
    test "returns empty list when no repos are configured" do
      assert Ecto.tools() == []
    end

    test "returns list of tools when repos are configured" do
      Application.put_env(:tidewave, :ecto_repos, [MockRepo])

      on_exit(fn ->
        Application.delete_env(:tidewave, :ecto_repos)
      end)

      assert tools = Ecto.tools()
      assert execute_sql_query = Enum.find(tools, &(&1.name == "execute_sql_query"))
      assert execute_sql_query.inputSchema.properties.repo.description =~ "MockRepo"

      assert Enum.find(tools, &(&1.name == "get_ecto_schemas"))
    end
  end

  describe "execute_sql_query/3" do
    test "uses first repo from list of configured repos when no repo is passed" do
      Application.put_env(:tidewave, :ecto_repos, [MockRepo])

      on_exit(fn ->
        Application.delete_env(:tidewave, :ecto_repos)
      end)

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
            "repo" => "Tidewave.MCP.Tools.EctoTest.MockRepo",
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
            "repo" => "Tidewave.MCP.Tools.EctoTest.MockRepo",
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
            "repo" => "Tidewave.MCP.Tools.EctoTest.MockRepo",
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
            "repo" => "Tidewave.MCP.Tools.EctoTest.MockRepo",
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
            "repo" => "Tidewave.MCP.Tools.EctoTest.MockRepo",
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
            "repo" => "Tidewave.MCP.Tools.EctoTest.MockRepo",
            "query" => "SELECT lotsofrows",
            "arguments" => []
          },
          Tidewave.init(inspect_opts: [limit: 10])
        )

      assert text =~ "Query returned 100 rows. Only the first 10 rows are included in the result."
      assert text =~ "6, 7, 8"
    end
  end

  describe "get_ecto_schemas/1" do
    test "returns list of Ecto schema modules and their file path" do
      assert {:error, "No Ecto schemas found in the project"} = Ecto.get_ecto_schemas(%{})

      [{_mod, bin}] =
        Code.compile_quoted(
          quote do
            defmodule TestSchema do
              def __changeset__ do
                %{}
              end
            end
          end
        )

      compile_path = Mix.Project.compile_path()
      File.write!("#{compile_path}/Elixir.TestSchema.beam", bin)

      on_exit(fn ->
        File.rm("#{compile_path}/Elixir.TestSchema.beam")
      end)

      {:ok, text} = Ecto.get_ecto_schemas(%{})
      assert text =~ "TestSchema"
    end
  end
end
