defmodule Mix.Tasks.Tidewave.Proxy do
  @shortdoc "Proxies Tidewave MCP requests over stdio"

  @moduledoc """
  Proxies Tidewave MCP requests from standard input to a running Phoenix application.

      mix tidewave.proxy

  Each advertised tool includes a required `port` argument. Tool calls are
  forwarded to the Phoenix application listening on that port at `127.0.0.1`.

  Browser tools are included by default. Pass `--no-browser-tools` to exclude
  them from the advertised tools.
  """

  use Mix.Task

  @requirements ["loadpaths"]

  @impl Mix.Task
  def run(argv) do
    {opts, _args} =
      OptionParser.parse!(argv,
        strict: [logger_redirect: :boolean, browser_tools: :boolean]
      )

    stdio = Process.group_leader()

    if Keyword.get(opts, :logger_redirect, true) do
      redirect_logs_to_stderr()
    end

    redirect_io_to_stderr()
    start_mcp!()
    Mix.ensure_application!(:inets)
    {:ok, _apps} = Application.ensure_all_started(:inets)

    Tidewave.MCP.Stdio.run(stdio,
      proxy: true,
      browser_tools: Keyword.get(opts, :browser_tools, true)
    )
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
