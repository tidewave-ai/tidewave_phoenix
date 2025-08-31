defmodule Tidewave.MixProject do
  use Mix.Project

  @source_url "https://github.com/tidewave-ai/tidewave_phoenix"
  @homepage_url "https://tidewave.ai/"
  @version "0.4.1"

  def project do
    [
      app: :tidewave,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      elixirc_paths: if(Mix.env() == :test, do: ["lib", "test/support"], else: ["lib"]),
      aliases: [
        tidewave:
          "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4000) end)'"
      ],

      # Docs
      name: "Tidewave",
      source_url: @source_url,
      homepage_url: @homepage_url,
      docs: &docs/0
    ]
  end

  def application do
    [
      mod: {Tidewave.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      description: "Tidewave for Phoenix",
      maintainers: ["Steffen Deusch"],
      licenses: ["Apache-2.0"],
      links: %{
        "Tidewave" => @homepage_url,
        "Changelog" => "https://hexdocs.pm/tidewave/changelog.html",
        "GitHub" => @source_url
      }
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.17"},
      {:jason, "~> 1.4"},
      {:circular_buffer, "~> 0.4 or ~> 1.0"},
      {:req, "~> 0.5"},
      {:phoenix_live_reload, ">= 1.6.1", optional: true},
      {:igniter, "~> 0.6", optional: true},
      {:bandit, "~> 1.6", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :docs},
      {:makeup_syntect, ">= 0.0.0", only: :docs}
    ]
  end

  defp docs do
    [
      api_reference: false,
      main: "installation",
      logo: "logo.svg",
      assets: %{"pages/assets" => "assets"},
      filter_modules: fn mod, _ ->
        raise "you forgot to add \"@moduledoc false\" to #{inspect(mod)}"
      end,
      extras: [
        "pages/installation.md",
        "pages/features/agentsmd.md",
        "pages/features/editors.md",
        "pages/features/inspector.md",
        "pages/features/notifications.md",
        "pages/features/react.md",
        "pages/guides/containers.md",
        "pages/guides/security.md",
        "pages/guides/tips_and_tricks.md",
        "pages/mcp/mcp.md",
        "pages/mcp/mcp_proxy.md",
        "pages/mcp/mcp_troubleshooting.md",
        "pages/mcp/claude_code.md",
        "pages/mcp/cursor.md",
        "pages/mcp/neovim.md",
        "pages/mcp/opencode.md",
        "pages/mcp/vscode.md",
        "pages/mcp/windsurf.md",
        "pages/mcp/zed.md"
      ],
      groups_for_extras: [
        Features: ~r/(pages\/features\/.?)/,
        Guides: ~r/(pages\/guides\/.?)/,
        MCP: ~r/pages\/mcp\/.?/
      ]
    ]
  end
end
