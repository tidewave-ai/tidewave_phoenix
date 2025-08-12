defmodule Tidewave.MixProject do
  use Mix.Project

  def project do
    [
      app: :tidewave,
      version: "0.3.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      aliases: [
        tidewave:
          "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4000) end)'"
      ],

      # Docs
      name: "Tidewave",
      source_url: "https://github.com/tidewave-ai/tidewave_phoenix",
      homepage_url: "https://tidewave.ai/",
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
      links: %{"Tidewave" => "https://tidewave.ai"}
    ]
  end

  defp deps do
    [
      {:plug, "~> 1.17"},
      {:jason, "~> 1.4"},
      {:circular_buffer, "~> 0.4 or ~> 1.0"},
      {:req, "~> 0.5"},
      {:igniter, "~> 0.6", optional: true},
      {:bandit, "~> 1.6", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :docs},
      {:makeup_json, ">= 0.0.0", only: :docs}
    ]
  end

  defp docs do
    [
      api_reference: false,
      main: "installation",
      logo: "logo.svg",
      assets: %{"pages/assets" => "assets"},
      extras: [
        "pages/installation.md",
        "pages/guides/containers.md",
        "pages/guides/security.md",
        "pages/mcp/mcp.md",
        "pages/mcp/mcp_proxy.md",
        "pages/mcp/mcp_troubleshooting.md",
        "pages/mcp/claude_code.md",
        "pages/mcp/claude.md",
        "pages/mcp/cursor.md",
        "pages/mcp/neovim.md",
        "pages/mcp/opencode.md",
        "pages/mcp/vscode.md",
        "pages/mcp/windsurf.md",
        "pages/mcp/zed.md"
      ],
      groups_for_extras: [
        Guides: ~r/(pages\/guides\/.?)/,
        MCP: ~r/pages\/mcp\/.?/
      ]
    ]
  end
end
