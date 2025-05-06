defmodule Tidewave.MCP.Tools.Eval do
  @moduledoc false

  @compile {:no_warn_undefined, Phoenix.CodeReloader}

  alias Tidewave.MCP
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

        It also includes IEx helpers in the evaluation context. Thus,
        to get documentation for a module or function, use this tool
        and execute the `h` helper, for example:

        h Enum.map/2
        """,
        inputSchema: %{
          type: "object",
          required: ["code"],
          properties: %{
            code: %{
              type: "string",
              description: "The Elixir code to evaluate."
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
      },
      %{
        name: "shell_eval",
        description: """
        Executes a shell command in the project root directory.

        The operating system is of flavor `#{inspect(:os.type())}`.

        Avoid using this tool for manipulating project files.
        Instead rely on the tools with the name matching `*_project_files`.

        Do not use this tool to evaluate Elixir code. Use `project_eval` instead.

        Do not use this tool for commands that run indefinitely,
        such as servers (like `mix phx.server` or `npm run dev`),
        REPLs (`iex`) or file watchers.

        Only use this tool if other means are not available.
        """,
        inputSchema: %{
          type: "object",
          required: ["command"],
          properties: %{
            command: %{
              type: "string",
              description:
                "The shell command to execute. Avoid using this for file operations; use dedicated file system tools instead."
            }
          }
        },
        callback: &shell_eval/1,
        # for now, only include the shell tool if FS tools are also enabled
        listable: fn connect_params -> not is_nil(connect_params["include_fs_tools"]) end
      }
    ]
  end

  @doc """
  Evaluates Elixir code using Code.eval_string/2.

  Returns the formatted result of the evaluation.
  """
  def project_eval(args, assigns) do
    case args do
      %{"code" => code} -> eval_code(code, Map.get(args, "timeout", 30_000), assigns)
      _ -> {:error, :invalid_arguments}
    end
  end

  defp eval_code(code, timeout, assigns) do
    parent = self()

    if endpoint = assigns[:phoenix_endpoint] do
      Phoenix.CodeReloader.reload(endpoint)
    end

    {pid, ref} =
      spawn_monitor(fn ->
        # we need to set the logger metadata again
        Logger.metadata(tidewave_mcp: true)
        send(parent, {:result, eval_with_captured_io(code, assigns.inspect_opts)})
      end)

    receive do
      {:result, result} ->
        {:ok, result, assigns}

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

  defp eval_with_captured_io(code, inspect_opts) do
    result =
      capture_io(fn ->
        IOForwardGL.with_forwarded_io(:standard_error, fn ->
          try do
            {result, _bindings} = Code.eval_string(code, [], env())
            result
          catch
            kind, reason -> Exception.format(kind, reason, __STACKTRACE__)
          end
        end)
      end)

    case result do
      # this is returned by IEx helpers
      {:"do not show this result in output", io} -> io
      {result, ""} -> inspect(result, inspect_opts)
      {result, io} -> "IO:\n\n#{io}\n\nResult:\n\n#{inspect(result, inspect_opts)}"
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

  @doc """
  Executes a shell command in the project root directory.

  Returns the output of the command.
  """
  def shell_eval(args) do
    case args do
      %{"command" => "iex " <> _} ->
        {:error,
         "Do not use shell_eval to evaluate Elixir code, use the project_eval tool instead"}

      %{"command" => command} ->
        case System.shell(command, stderr_to_stdout: true, cd: MCP.root()) do
          {output, 0} ->
            {:ok, output}

          {output, status} ->
            {:error, "Command failed with status #{status}:\n\n#{output}"}
        end

      _ ->
        {:error, :invalid_arguments}
    end
  end
end
