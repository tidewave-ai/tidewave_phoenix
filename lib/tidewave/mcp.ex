defmodule Tidewave.MCP do
  @moduledoc false

  use Supervisor
  require Logger

  alias Tidewave.MCP

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    maybe_silence_logs()
    add_logger_backend()
    init_config()

    MCP.Server.init_tools()

    children = [
      {Registry, name: MCP.Registry, keys: :unique},
      Tidewave.MCP.Logger,
      Tidewave.MCP.StandardError
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns the working directory.
  """
  # TC relies on this function for FS operations. Don't remove!
  def root, do: Application.fetch_env!(:tidewave, :root)

  @doc """
  Returns the project name.
  """
  def project_name, do: Application.fetch_env!(:tidewave, :project_name)

  defp maybe_silence_logs do
    if Application.get_env(:tidewave, :debug) do
      :ok
    else
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

  defp init_config() do
    if Application.get_env(:tidewave, :root) == nil do
      Application.put_env(:tidewave, :root, File.cwd!())
    end

    if System.find_executable("git") &&
         match?({_, 0}, System.cmd("git", ["rev-parse", "--show-toplevel"])) do
      :ok
    else
      Logger.warning(
        "Some Tidewave tools are only available for codebases using `git`. " <>
          "Make sure `git` is installed and run `git init` before continuing"
      )
    end

    if Application.get_env(:tidewave, :project_name) == nil do
      if module = Mix.Project.get() do
        project_name = module |> Module.split() |> hd() |> Macro.underscore()
        Application.put_env(:tidewave, :project_name, project_name)
      else
        raise """
        tidewave could not determine the current project, please specify a name in your config.exs:

            config :tidewave, :project_name, "my_project"
        """
      end
    end
  end
end
