defmodule Tidewave.Application do
  @moduledoc false
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children =
      if Application.spec(:mix, :vsn) do
        [Tidewave.MCP, {Registry, name: Tidewave.ACP.MCPRegistry, keys: :unique}]
      else
        Logger.warning("application :tidewave is not starting because Mix is not running")
        []
      end

    opts = [strategy: :one_for_one, name: Tidewave.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
