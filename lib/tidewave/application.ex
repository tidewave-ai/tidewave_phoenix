defmodule Tidewave.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    tools = Application.get_env(:tidewave, :tools, [])

    children = [
      {Tidewave.MCP, tools: tools}
    ]

    opts = [strategy: :one_for_one, name: Tidewave.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
