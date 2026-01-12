defmodule Tidewave.MCP.Tool do
  @moduledoc false

  # TODO: Trim description on creation
  defstruct [:name, :description, :input_schema, :callback]

  alias Tidewave.MCP.Tool

  @doc """
  Convert the tool into its MCP definition.
  """
  def to_definition(%Tool{name: name, description: description, input_schema: input_schema}) do
    %{
      name: name,
      description: String.trim(description),
      inputSchema: input_schema.(nil) |> Schemecto.to_json_schema()
    }
  end

  @doc """
  Dispatch the tool with the given `params` and `extra` arguments.
  """
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

  @doc """
  Converts the tool to a minimum format that can be stored and dispatched to.
  """
  def to_storage(%Tool{input_schema: schema, callback: callback}) do
    {schema, callback}
  end
end
