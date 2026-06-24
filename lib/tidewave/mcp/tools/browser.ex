defmodule Tidewave.MCP.Tools.Browser do
  @moduledoc false

  alias Tidewave.BrowserSessions

  @control_path "/tidewave"

  def tools do
    [
      %{
        name: "browser_eval",
        description: description(),
        inputSchema: %{
          type: "object",
          properties: %{
            code: %{
              type: "string",
              description:
                "JavaScript that interacts with the page. It MUST use the global `browser` object API. Omit it on the first call to handshake and discover a session and the API."
            },
            sid: %{
              type: "string",
              description:
                "The session to target, e.g. \"nice-cactus#1\". Omit it to use a new primary session (returned to you as `sid`)."
            },
            timeout: %{
              type: "number",
              description: "Timeout in milliseconds. Defaults to 10000."
            }
          }
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

      %{"code" => ""} ->
        # the broadcast case is only expected to run for initial discovery
        broadcast("browser_eval", args, 5_000) |> broadcast_result(url)

      args when not is_map_key(args, "code") ->
        broadcast("browser_eval", args, 5_000) |> broadcast_result(url)

      _ ->
        {:error, "browser_eval requires a `sid` when `code` is not empty."}
    end
  end

  def browser_eval(_args, _assigns) do
    {:error, :invalid_arguments}
  end

  # A pure handshake (no code) has no side effects, so a missed first broadcast
  # is worth retrying once. We never retry code, which could run twice.
  defp broadcast(name, input, timeout) do
    if Map.get(input, "code", "") == "" do
      broadcast_with_retry(name, input, timeout)
    else
      BrowserSessions.broadcast_run(name, input, timeout)
    end
  end

  defp broadcast_with_retry(name, input, timeout) do
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
      ms when is_integer(ms) and ms > 0 -> min(ms + 5_000, 120_000)
      _ -> 15_000
    end
  end

  defp description do
    """
    Runs JavaScript in a real browser page that Tidewave controls (an iframe in your \
    application, on the same origin), to validate UI-affecting changes.

    Call it with NO arguments first: that connects to an open browser session and returns \
    its `sid` along with the full `browser` API documentation. Then call again with `code` \
    (and the `sid` you were given) to interact with the page.

    Requires a browser tab open at #{@control_path}. Use it to verify visibility, text, \
    state, and interactions — DO NOT use it to validate design, styles, or general CSS.
    """
  end
end
