defmodule Mix.Tasks.Tidewave.Mcp do
  @shortdoc "Runs the Tidewave MCP server over stdio"

  @moduledoc """
  Runs the Tidewave MCP server over standard input and standard output.

      mix tidewave.mcp

  Browser tools are not available through this transport.
  """

  use Mix.Task

  @requirements ["loadpaths"]

  @impl Mix.Task
  def run(argv) do
    {opts, _args} = OptionParser.parse!(argv, strict: [logger_redirect: :boolean])
    stdio = Process.group_leader()

    if Keyword.get(opts, :logger_redirect, true) do
      redirect_logs_to_stderr()
    end

    redirect_io_to_stderr()
    start_mcp!()

    Tidewave.MCP.Stdio.run(stdio)
  end

  defp start_mcp! do
    case Tidewave.MCP.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> raise "failed to start Tidewave MCP: #{inspect(reason)}"
    end
  end

  defp redirect_io_to_stderr do
    Process.group_leader(self(), Process.whereis(:standard_error))
  end

  defp redirect_logs_to_stderr do
    case :logger.get_handler_config(:default) do
      {:ok, %{module: module} = handler_config} ->
        :ok = :logger.remove_handler(:default)

        handler_config =
          handler_config
          |> Map.drop([:id, :module])
          |> put_in([:config, :type], :standard_error)

        :ok = :logger.add_handler(:default, module, handler_config)

      {:error, _reason} ->
        :ok
    end
  end
end
