defmodule Tidewave.MCP.Tools.Logs do
  @moduledoc false

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
              type: "integer",
              description: "The number of log entries to return from the end of the log"
            },
            grep: %{
              type: "string",
              description:
                "Filter logs with the given regular expression (case insensitive). E.g. \"timeout\" to find timeout-related messages"
            },
            level: %{
              type: "string",
              enum: ~w(emergency alert critical error warning notice info debug),
              description: "Filter logs by log level (e.g. \"error\" for error logs only)"
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
        opts =
          [grep: Map.get(args, "grep"), level: Map.get(args, "level")]
          |> Enum.reject(fn {_k, v} -> is_nil(v) end)

        {:ok, Enum.join(Tidewave.MCP.Logger.get_logs(n, opts), "\n")}

      _ ->
        {:error, :invalid_arguments}
    end
  end
end
