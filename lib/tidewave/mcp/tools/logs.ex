defmodule Tidewave.MCP.Tools.Logs do
  @moduledoc false
  @known_levels ~w(emergency alert critical error warning notice info debug)

  def tools do
    [
      %{
        name: "get_logs",
        description: """
        Returns all log output, excluding logs that were caused by other tool calls.

        Use this tool to check for request logs or potentially logged errors.
        """,
        inputSchema: %{
          type: "object",
          required: ["tail"],
          properties: %{
            tail: %{
              type: "number",
              description: "The number of log entries to return from the end of the log"
            },
            level: %{
              type: "string",
              description:
                "Filter logs with the given level and above. Use \"error\" when you to capture errors in particular",
              enum: @known_levels
            }
          }
        },
        callback: &get_logs/1
      }
    ]
  end

  def get_logs(args) do
    case args do
      %{"tail" => n} ->
        level =
          case args do
            %{"level" => level} when level in @known_levels -> String.to_atom(level)
            _ -> :debug
          end

        {:ok, Enum.join(Tidewave.MCP.Logger.get_logs(n, level), "\n")}

      _ ->
        {:error, :invalid_arguments}
    end
  end
end
