defmodule Tidewave.MixProject do
  use Mix.Project

  @source_url "https://github.com/tidewave-ai/tidewave_phoenix"
  @homepage_url "https://tidewave.ai/"
  @version "0.5.4"

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
      {:igniter, "~> 0.6", optional: true},

      # We require v1.6.1 to detect if phoenix live reload is running too early or late
      {:phoenix_live_reload, ">= 1.6.1", optional: true},

      # Dev deps
      {:bandit, "~> 1.10", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:makeup_syntect, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      api_reference: false,
      main: "installation",
      logo: "logo.svg",
      footer: false,
      assets: %{"pages/assets" => "assets"},
      filter_modules: fn mod, _ ->
        raise "you forgot to add \"@moduledoc false\" to #{inspect(mod)}"
      end,
      extras: [
        "pages/installation.md",
        "pages/features/accessibility.md",
        "pages/features/agentsmd.md",
        "pages/features/inspector.md",
        "pages/features/notifications.md",
        "pages/features/providers.md",
        "pages/features/teams.md",
        "pages/features/viewport.md",
        "pages/integrations/claude_code.md",
        "pages/integrations/codex.md",
        "pages/integrations/editors.md",
        "pages/integrations/figma.md",
        "pages/integrations/frontend.md",
        "pages/integrations/supabase.md",
        "pages/guides/containers.md",
        "pages/guides/https.md",
        "pages/guides/security.md",
        "pages/guides/subdomains.md",
        "pages/guides/tips_and_tricks.md",
        "pages/mcp/mcp.md",
        "pages/mcp/mcp_troubleshooting.md",
        "pages/mcp/mcp_claude_code.md",
        "pages/mcp/mcp_codex.md",
        "pages/mcp/mcp_cursor.md",
        "pages/mcp/mcp_neovim.md",
        "pages/mcp/mcp_opencode.md",
        "pages/mcp/mcp_vscode.md",
        "pages/mcp/mcp_windsurf.md",
        "pages/mcp/mcp_zed.md",
        "pages/mcp/mcp_proxy.md"
      ],
      groups_for_extras: [
        Features: ~r/(pages\/features\/.?)/,
        Integrations: ~r/(pages\/integrations\/.?)/,
        Guides: ~r/(pages\/guides\/.?)/,
        MCP: ~r/pages\/mcp\/.?/
      ],
      redirects: %{
        "react" => "frontend",
        "vue" => "frontend"
      }
    ]
  end
end
