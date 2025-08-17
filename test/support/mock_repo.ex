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
