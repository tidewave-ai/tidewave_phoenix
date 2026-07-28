defmodule Tidewave.MCP.Tools.Browser do
  @moduledoc false

  alias Tidewave.BrowserSessions

  def tools do
    [
      %{
        name: "browser_eval",
        description: """
        Runs JavaScript in a real browser interacting with the application.

        You MUST use "help" action first to learn the full API.
        """,
        inputSchema: %{
          type: "object",
          properties: %{
            action: %{
              type: "string",
              enum: ["help", "eval"]
            },
            code: %{
              type: "string",
              description:
                "JavaScript that interacts with the page. It MUST use the global `browser` object API."
            },
            sid: %{
              type: "string",
              description: ~S|The session to target, e.g. "nice-cactus#1".|
            },
            timeout: %{
              type: "number",
              description: "Timeout in milliseconds. Defaults to 45000."
            }
          },
          required: ["action"]
        },
        callback: &browser_eval/2
      }
    ]
  end

  def browser_eval(args, assigns) when is_map(args) do
    url = assigns.url

    case args do
      %{"sid" => sid} when is_binary(sid) and sid != "" ->
        BrowserSessions.run(sid, "browser_eval", args, eval_timeout(args))
        |> direct_result(sid, url)

      %{"action" => "help"} ->
        # the broadcast case is only expected to run for initial discovery
        broadcast("browser_eval", args, 5_000) |> broadcast_result(url)

      %{"action" => action} ->
        {:error, ~s|browser_eval requires a "sid" for action "#{action}".|}
    end
  end

  def browser_eval(_args, _assigns) do
    {:error, :invalid_arguments}
  end

  # Broadcast is only used for the first handshake. We can safely retry
  # once if the first attempt times out.
  defp broadcast(name, input, timeout) do
    case BrowserSessions.broadcast_run(name, input, timeout) do
      {:error, :timeout} ->
        BrowserSessions.broadcast_run(name, input, timeout)

      other ->
        other
    end
  end

  defp direct_result({:ok, result}, _sid, _url), do: {:ok, result}

  defp direct_result({:error, :invalid_sid}, sid, _url) do
    {:error, "Invalid sid \"#{sid}\". A sid looks like \"nice-cactus#1\"."}
  end

  defp direct_result({:error, :unknown_client}, sid, _url) do
    {:error,
     "No connected browser owns sid \"#{sid}\". It may have disconnected — " <>
       "call browser_eval with no arguments to discover a live session."}
  end

  defp direct_result({:error, :timeout}, _sid, _url) do
    {:error, "browser_eval timed out waiting for the browser to respond."}
  end

  defp direct_result({:error, :disconnected}, _sid, url) do
    {:error,
     "The browser disconnected before responding. Open #{url}/tidewave in your browser to open a new session."}
  end

  defp broadcast_result({:ok, result}, _url), do: {:ok, result}
  defp broadcast_result({:error, :no_clients}, url), do: {:error, no_browser_message(url)}
  defp broadcast_result({:error, :timeout}, url), do: {:error, no_browser_message(url)}

  defp no_browser_message(url) do
    "No browser is connected to the Tidewave control page. " <>
      "Open #{url}/tidewave in your browser and try again."
  end

  # Server-side wait: a little longer than the browser's own timeout so the
  # browser's result (or its own timeout) comes back before we give up.
  defp eval_timeout(args) do
    case args["timeout"] do
      ms when is_integer(ms) and ms > 0 -> min(ms + 5_000, 60_000)
      _ -> 15_000
    end
  end
end
