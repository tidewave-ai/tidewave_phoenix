defmodule Tidewave.MCP.Tool do
  @moduledoc false

  # TODO: Trim description on creation
  defstruct [:name, :description, :input_schema, :callback]

  alias Tidewave.MCP.Tool

  def input_schema(%Tool{input_schema: input_schema}) do
    input_schema.(nil) |> Schemecto.to_json_schema()
  end

  def dispatch(%Tool{input_schema: schema, callback: callback}, params, extra) do
    dispatch({schema, callback}, params, extra)
  end

  def dispatch({schema, callback}, params, extra) do
    changeset = schema.(params)

    if changeset.valid? do
      callback.(Ecto.Changeset.apply_changes(changeset), extra)
    else
      {:error, changeset}
    end
  end

  def to_storage(%Tool{input_schema: schema, callback: callback}) do
    {schema, callback}
  end
end
