defmodule Tidewave.MCP.Tool do
  @moduledoc false

  # TODO: Make name atoms
  defstruct [:name, :description, :input_schema, :callback]

  alias Tidewave.MCP.Tool

  def input_schema(%Tool{input_schema: input_schema}) do
    input_schema.(nil) |> Schemecto.to_json_schema()
  end

  def dispatch(%Tool{input_schema: fun, callback: callback}, params, extra) do
    changeset = fun.(params)

    if changeset.valid? do
      callback.(Ecto.Changeset.apply_changes(changeset), extra)
    else
      {:error, changeset}
    end
  end
end
