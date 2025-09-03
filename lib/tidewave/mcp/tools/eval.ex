defmodule Tidewave.MCP.Tools.Eval do
  @moduledoc false

  @compile {:no_warn_undefined, Phoenix.CodeReloader}

  alias Tidewave.MCP.IOForwardGL

  def tools do
    [
      %{
        name: "project_eval",
        description: """
        Evaluates Elixir code in the context of the project.

        The current Elixir version is: #{System.version()}

        Use this tool every time you need to evaluate Elixir code,
        including to test the behaviour of a function or to debug
        something. The tool also returns anything written to standard
        output. DO NOT use shell tools to evaluate Elixir code.

        It also includes IEx helpers in the evaluation context.
        For example, to get all functions in a module, call
        `exports(String)`.
        """,
        inputSchema: %{
          type: "object",
          required: ["code"],
          properties: %{
            code: %{
              type: "string",
              description: "The Elixir code to evaluate."
            },
            arguments: %{
              type: "array",
              description:
                "The arguments to pass to evaluation. They are available inside the evaluated code as `arguments`.",
              items: %{type: ["array", "boolean", "null", "number", "object", "string"]}
            },
            timeout: %{
              type: "integer",
              description: """
              Optional. A timeout in milliseconds after which the execution stops if it did not finish yet.
              Defaults to 30000 (30 seconds).
              """
            }
          }
        },
        callback: &project_eval/2
      }
    ]
  end

  @doc """
  Evaluates Elixir code using Code.eval_string/2.

  Returns the formatted result of the evaluation.
  """
  def project_eval(args, assigns) do
    case args do
      %{"code" => code} ->
        arguments = Map.get(args, "arguments", [])
        timeout = Map.get(args, "timeout", 30_000)
        json? = Map.get(args, "json", false)
        eval_code(code, arguments, timeout, json?, assigns)

      _ ->
        {:error, :invalid_arguments}
    end
  end

  defp eval_code(code, arguments, timeout, json?, assigns) do
    parent = self()

    if endpoint = assigns[:phoenix_endpoint] do
      Phoenix.CodeReloader.reload(endpoint)
    end

    inspect_opts = assigns.inspect_opts

    {pid, ref} =
      spawn_monitor(fn ->
        # we need to set the logger metadata again
        Logger.metadata(tidewave_mcp: true)
        send(parent, {:result, eval_with_captured_io(code, arguments, json?, inspect_opts)})
      end)

    receive do
      {:result, result} ->
        {:ok, result}

      {:DOWN, ^ref, :process, ^pid, reason} ->
        {:error,
         "Failed to evaluate code. Process exited with reason: #{Exception.format_exit(reason)}"}
    after
      timeout ->
        Process.demonitor(ref, [:flush])
        Process.exit(pid, :brutal_kill)
        {:error, "Evaluation timed out after #{timeout} milliseconds."}
    end
  end

  defp eval_with_captured_io(code, arguments, json?, inspect_opts) do
    {{success?, result}, io} =
      capture_io(fn ->
        IOForwardGL.with_forwarded_io(:standard_error, fn ->
          try do
            {result, _bindings} = Code.eval_string(code, [arguments: arguments], env())
            {true, result}
          catch
            kind, reason -> {false, Exception.format(kind, reason, __STACKTRACE__)}
          end
        end)
      end)

    case result do
      _ when json? -> Jason.encode!(%{result: result, success: success?, stdout: io, stderr: ""})
      :"do not show this result in output" -> io
      _ when io == "" -> inspect(result, inspect_opts)
      _ -> "IO:\n\n#{io}\n\nResult:\n\n#{inspect(result, inspect_opts)}"
    end
  end

  defp env do
    import IEx.Helpers, warn: false
    __ENV__
  end

  defp capture_io(fun) do
    {:ok, pid} = StringIO.open("")
    original = Application.get_env(:elixir, :ansi_enabled)
    Application.put_env(:elixir, :ansi_enabled, false)
    original_group_leader = Process.group_leader()
    Process.group_leader(self(), pid)

    try do
      result = fun.()
      {_, content} = StringIO.contents(pid)
      {result, content}
    after
      Process.group_leader(self(), original_group_leader)
      StringIO.close(pid)
      Application.put_env(:elixir, :ansi_enabled, original)
    end
  end
end
