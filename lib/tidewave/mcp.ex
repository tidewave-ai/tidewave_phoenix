defmodule Tidewave.MCP do
  @moduledoc false

  use Supervisor

  alias Tidewave.MCP

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    maybe_silence_logs()
    add_logger_backend()

    if Application.get_env(:tidewave, :root) == nil do
      Application.put_env(:tidewave, :root, File.cwd!())
    end

    MCP.Server.init_tools()

    children = [
      {Registry, name: MCP.Registry, keys: :unique},
      Tidewave.MCP.Logger,
      {Tidewave.MCP.IOForwardGL, name: :standard_error}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns the working directory.
  """
  def root, do: Application.fetch_env!(:tidewave, :root)

  defp maybe_silence_logs do
    if Application.get_env(:tidewave, :debug) do
      :ok
    else
      Logger.put_module_level(MCP.SSE, :none)
      Logger.put_module_level(MCP.Connection, :none)
      Logger.put_module_level(MCP.Server, :none)
    end
  end

  defp add_logger_backend() do
    :ok =
      :logger.add_handler(
        MCP.Logger,
        MCP.Logger,
        %{formatter: Logger.default_formatter(colors: [enabled: false])}
      )
  end
end
