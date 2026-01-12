defmodule Tidewave.MCP.Tools.Logs do
  @moduledoc false

  def get_logs_tool do
    %Tidewave.MCP.Tool{
      name: "get_logs",
      description: """
      Returns all log output, excluding logs that were caused by other tool calls.

      Use this tool to check for request logs or potentially logged errors.
      """,
      input_schema: fn params ->
        [
          %{
            name: :tail,
            type: :integer,
            description: "The number of log entries to return from the end of the log"
          },
          %{
            name: :grep,
            type: :string,
            description:
              "Filter logs with the given regular expression (case insensitive). E.g. \"error\" when you want to capture errors in particular"
          }
        ]
        |> Schemecto.new(params)
        |> Ecto.Changeset.validate_required([:tail])
      end,
      callback: &__MODULE__.get_logs/2
    }
  end

  def tools do
    [
      get_logs_tool()
    ]
  end

  def get_logs(%{tail: n} = args, _assigns) do
    grep = Map.get(args, :grep)
    {:ok, Enum.join(Tidewave.MCP.Logger.get_logs(n, grep), "\n")}
  end
end
