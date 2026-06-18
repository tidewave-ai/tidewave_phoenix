defmodule Tidewave.MCP.Tools.Browser do
  @moduledoc false

  alias Tidewave.BrowserSessions

  # How long the control page is given to open an iframe and report it loaded.
  @open_timeout 30_000

  def tools do
    [
      %{
        name: "browser_session",
        description: """
        Opens a new browser session in the connected Tidewave control page.

        A browser session is an isolated iframe, in the same domain, navigated to
        the given path (defaults to "/"). The server assigns it a human-friendly
        name (such as "flying-circus") which you pass as the `session` argument
        to `browser_eval`.

        Requires a control page to be open at `/tidewave/control`.
        """,
        inputSchema: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Relative path to open the session at. Defaults to \"/\"."
            }
          }
        },
        callback: &browser_session/1
      },
      %{
        name: "browser_eval",
        description: browser_eval_description(),
        inputSchema: %{
          type: "object",
          required: ["code"],
          properties: %{
            code: %{
              type: "string",
              description:
                "JavaScript performing interactions with the page. It MUST ALWAYS use the global `browser` object API."
            },
            session: %{
              type: "string",
              description:
                "The browser session to run against (a human-friendly name such as \"flying-circus\"). Optional when exactly one session is open; required when several are open."
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

  def browser_session(args) do
    path =
      case args["path"] do
        path when is_binary(path) and path != "" -> path
        _ -> "/"
      end

    case BrowserSessions.open_session(path, @open_timeout) do
      {:ok, name} ->
        {:ok,
         "Opened browser session \"#{name}\" at #{path}. " <>
           "Pass session: \"#{name}\" to browser_eval to run code against it."}

      {:error, :no_control} ->
        {:error,
         "No Tidewave control page is connected. Open /tidewave/control in your browser to host browser sessions."}

      {:error, :name_unavailable} ->
        {:error, "Could not allocate a unique session name. Please try again."}

      {:error, :timeout} ->
        {:error, "Timed out waiting for the control page to open the session."}

      {:error, :disconnected} ->
        {:error, "The control page disconnected before the session was opened."}

      {:error, message} when is_binary(message) ->
        {:error, message}
    end
  end

  def browser_eval(%{"code" => _} = args) do
    session = args["session"]
    input = Map.take(args, ["code", "timeout"])

    case BrowserSessions.eval(session, input, eval_timeout(args)) do
      {:ok, result, name} ->
        {:ok, browser_eval_result(result, session, name)}

      {:error, :no_sessions} ->
        {:error,
         "No browser session is currently open. Use the browser_session tool to open one, or open /tidewave/control in your browser."}

      {:error, {:ambiguous, names}} ->
        {:error,
         "Multiple browser sessions are open. Pass the `session` argument set to one of: #{Enum.join(names, ", ")}."}

      {:error, {:unknown, name, []}} ->
        {:error, "No browser session named \"#{name}\" is open."}

      {:error, {:unknown, name, available}} ->
        {:error,
         "No browser session named \"#{name}\" is open. Available sessions: #{Enum.join(available, ", ")}."}

      {:error, :timeout} ->
        {:error, "browser_eval timed out waiting for the browser to respond."}

      {:error, :disconnected} ->
        {:error, "The browser session disconnected before responding."}
    end
  end

  def browser_eval(_args) do
    {:error, :invalid_arguments}
  end

  # Server-side wait: a little longer than the browser's own timeout so the
  # browser's result (or its own timeout) comes back before we give up.
  defp eval_timeout(args) do
    case args["timeout"] do
      ms when is_integer(ms) and ms > 0 -> min(ms + 5_000, 120_000)
      _ -> 15_000
    end
  end

  # The browser returns %{"text" => ..., "isError" => ...}.
  #
  # When the session was resolved implicitly (no `session` argument) we append
  # its name so the agent can target the same browser explicitly on later calls.
  defp browser_eval_result(result, requested_session, name) do
    text = result["text"] || ""

    text =
      if is_nil(requested_session) do
        text <>
          "\n\nSession name: #{name} — pass it as the `session` argument to target this browser explicitly."
      else
        text
      end

    %{
      content: [%{type: "text", text: text}],
      isError: result["isError"] == true
    }
  end

  defp browser_eval_description do
    """
    Performs a sequence of interactions with a connected application page in the browser.

    You write JavaScript that runs in an isolated environment in the browser and you MUST \
    ALWAYS use the global `browser` object to interact with the page. Use `console.log` to \
    surface information; NEVER return anything. The page state is kept across invocations.

    Use it to validate any UI-affecting change (visibility, text, state, interaction). DO NOT \
    use it to validate design, styles, or general CSS changes.

    ## The `browser` API

    - `browser.reload(path?)` — navigate to a path (or reload) and wait for load.
    - `browser.eval(fun, arg?)` — run a function on the page. It executes in a separate \
      context, so it MUST NOT reference outside variables; pass any data it needs as the \
      second argument. Use an async function and await any asynchronous work. Its return value \
      is available to your code.
    - `browser.wait(ms)` — wait for the given milliseconds.

    Always prioritize reading the source code first; only use this tool to fill gaps. DO NOT \
    include code comments in the code given to this tool.

    The `session` argument selects which open browser session to target. It is optional when \
    only one session is open.
    """
  end
end
