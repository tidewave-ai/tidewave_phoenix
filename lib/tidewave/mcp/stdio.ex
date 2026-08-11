defmodule Tidewave.MCP.Stdio do
  @moduledoc false

  alias Tidewave.MCP.Handler

  def run(stdio) do
    assigns = Tidewave.init([])

    stdio
    |> IO.stream(:line)
    |> Enum.each(&handle_line(&1, stdio, assigns))
  end

  defp handle_line(line, stdio, assigns) do
    case Jason.decode(line) do
      {:ok, message} ->
        message
        |> Handler.handle_message(assigns, include_browser_tools: false)
        |> write_result(stdio)

      {:error, _error} ->
        write_result(
          {:reply,
           %{
             jsonrpc: "2.0",
             id: nil,
             error: %{code: -32700, message: "Parse error"}
           }},
          stdio
        )
    end
  end

  defp write_result(:notification, _stdio), do: :ok

  defp write_result({kind, response}, stdio) when kind in [:reply, :error] do
    IO.write(stdio, [Jason.encode_to_iodata!(response), ?\n])
  end
end
