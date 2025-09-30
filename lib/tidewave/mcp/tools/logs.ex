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
                "Filter logs with the given regular expression (case insensitive). E.g. \"error\" when you want to capture errors in particular"
            }
          }
        },
        callback: &get_logs/1
      },
      %{
        name: "clear_logs",
        description: """
        Clears all captured logs.

        Use this before executing code to ensure that subsequent get_logs calls only return fresh logs.
        Useful pattern: clear_logs() → project_eval(code) → get_logs() to see exactly what was logged.
        """,
        inputSchema: %{
          type: "object",
          properties: %{}
        },
        callback: &clear_logs/1
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

  def clear_logs(_args) do
    :ok = Tidewave.MCP.Logger.clear_logs()
    {:ok, "Logs cleared"}
  end
end
