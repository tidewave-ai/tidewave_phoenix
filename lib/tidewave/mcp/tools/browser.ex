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
        callback: &browser_eval/1
      }
    ]
  end

  def browser_eval(args) when is_map(args) do
    input = %{code: to_code(args["code"])}
    timeout = eval_timeout(args)

    case args["sid"] do
      sid when is_binary(sid) and sid != "" ->
        BrowserSessions.run(sid, "browser_eval", input, timeout) |> direct_result(sid)

      _ ->
        broadcast_with_retry("browser_eval", input, timeout) |> broadcast_result()
    end
  end

  def browser_eval(_args) do
    {:error, :invalid_arguments}
  end

  defp to_code(code) when is_binary(code), do: code
  defp to_code(_), do: ""

  # A pure handshake (no code) has no side effects, so a missed first broadcast
  # is worth retrying once. We never retry code, which could run twice.
  defp broadcast_with_retry(name, input, timeout) do
    case BrowserSessions.broadcast_run(name, input, timeout) do
      {:error, :timeout} when input.code == "" ->
        BrowserSessions.broadcast_run(name, input, timeout)

      other ->
        other
    end
  end

  defp direct_result({:ok, result}, _sid), do: {:ok, relay(result)}

  defp direct_result({:error, :invalid_sid}, sid) do
    {:error, "Invalid sid \"#{sid}\". A sid looks like \"nice-cactus#1\"."}
  end

  defp direct_result({:error, :unknown_client}, sid) do
    {:error,
     "No connected browser owns sid \"#{sid}\". It may have disconnected — " <>
       "call browser_eval with no arguments to discover a live session."}
  end

  defp direct_result({:error, :timeout}, _sid) do
    {:error, "browser_eval timed out waiting for the browser to respond."}
  end

  defp direct_result({:error, :disconnected}, _sid) do
    {:error, "The browser disconnected before responding."}
  end

  defp broadcast_result({:ok, result}), do: {:ok, relay(result)}
  defp broadcast_result({:error, :no_clients}), do: {:error, no_browser_message()}
  defp broadcast_result({:error, :timeout}), do: {:error, no_browser_message()}

  defp no_browser_message do
    "No browser is connected to the Tidewave control page. " <>
      "Open #{@control_path} in your browser and try again."
  end

  # The browser composes the full response text (session hints, the new-session
  # notice, the handshake docs); we simply relay it.
  defp relay(result) do
    %{
      content: [%{type: "text", text: result["text"] || ""}],
      isError: result["isError"] == true
    }
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
