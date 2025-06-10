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
        {:ok, Enum.join(Tidewave.MCP.Logger.get_logs(n), "\n")}

      _ ->
        {:error, :invalid_arguments}
    end
  end
end
