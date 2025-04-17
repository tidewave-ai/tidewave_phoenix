defmodule Tidewave.MCP.Tools.Eval do
  @moduledoc false

  alias Tidewave.MCP

  def tools do
    [
      %{
        name: "project_eval",
        description: """
        Evaluates Elixir code in the context of the project.

        The current Elixir version is: #{System.version()}

        Includes IEx helpers in the evaluation context. Thus, to get documentation for a module or function,
        use this tool and execute the `h` helper, for example:

        h Enum.map/2

        The code is executed in the context of the user's project, therefore use this tool any
        time you need to evaluate code, for example to test the behavior of a function or to debug
        something. The tool also returns anything written to standard output.
        """,
        inputSchema: %{
          type: "object",
          required: ["code"],
          properties: %{
            code: %{
              type: "string",
              description: "The Elixir code to evaluate."
            }
          }
        },
        callback: &project_eval/1
      },
      %{
        name: "shell_eval",
        description: """
        Executes a shell command in the project root directory.

        Avoid using this tool for file operations. Instead, rely on dedicated file system tools, if available.

        The operating system is of flavor `#{inspect(:os.type())}`.

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
        callback: &shell_eval/1
      }
    ]
  end

  @doc """
  Evaluates Elixir code using Code.eval_string/2.

  Returns the formatted result of the evaluation.
  """
  def project_eval(args) do
    case args do
      %{"code" => code} ->
        result =
          case capture_io(fn ->
                 {result, _bindings} = Code.eval_string(code, [], env())
                 result
               end) do
            # this is returned by IEx helpers
            {:"do not show this result in output", io} -> io
            {result, ""} -> result
            {result, io} -> %{result: result, io: io}
          end

        {:ok, inspect(result, limit: :infinity, printable_limit: :infinity, pretty: true)}

      _ ->
        {:error, :invalid_arguments}
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
