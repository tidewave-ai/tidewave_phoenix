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
              type: "number",
              description: "The number of log entries to return from the end of the log"
            },
            grep: %{
              type: "string",
              description:
                "Filter logs with the given regular expression. E.g. \"error\" when you to capture errors in particular"
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
        grep = Map.get(args, "grep")
        {:ok, Enum.join(Tidewave.MCP.Logger.get_logs(n, grep), "\n")}

      _ ->
        {:error, :invalid_arguments}
    end
  end
end
