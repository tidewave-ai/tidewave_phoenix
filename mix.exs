defmodule Tidewave.MixProject do
  use Mix.Project

  @source_url "https://github.com/tidewave-ai/tidewave_phoenix"
  @homepage_url "https://tidewave.ai/"
  @version "0.8.2"

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
      {:plug, "~> 1.18"},
      {:jason, "~> 1.4"},
      {:circular_buffer, "~> 0.4 or ~> 1.0"},
      {:igniter, "~> 0.6", optional: true},

      # Required for the browser control page to upgrade /tidewave/ws to a
      # plain WebSocket. Works with both Bandit and Plug.Cowboy.
      {:websock_adapter, "~> 0.5"},

      # We require v1.6.1 to detect if phoenix live reload is running too early or late
      {:phoenix_live_reload, ">= 1.6.1", optional: true},

      # We require 2.9 for get_sock_data
      {:plug_cowboy, "~> 2.9", optional: true},

      # Dev deps
      {:bandit, "~> 1.10", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:makeup_syntect, ">= 0.0.0", only: :dev}
    ]
  end

  defp docs do
    [
      api_reference: false,
      main: "welcome",
      logo: "logo.svg",
      footer: false,
      assets: %{"pages/assets" => "assets"},
      filter_modules: fn mod, _ ->
        raise "you forgot to add \"@moduledoc false\" to #{inspect(mod)}"
      end,
      extras: [
        "pages/welcome.md",
        "pages/ide/installation.md",
        "pages/ide/browser_app.md",
        "pages/ide/code_review.md",
        "pages/ide/containers.md",
        "pages/ide/custom_domains.md",
        "pages/ide/figma.md",
        "pages/ide/git.md",
        "pages/ide/https.md",
        "pages/ide/mermaid.md",
        "pages/ide/notifications.md",
        "pages/ide/providers.md",
        "pages/ide/remote_access.md",
        "pages/ide/spaces.md",
        "pages/ide/task_board.md",
        "pages/ide/voice_input.md",
        "pages/features/accessibility.md",
        "pages/features/connect.md",
        "pages/features/inspector.md",
        "pages/features/ui_variants.md",
        "pages/features/vision_mode.md",
        "pages/references/editors.md",
        "pages/references/frontend.md",
        "pages/references/teams.md",
        "pages/references/security.md",
        "pages/mcp/mcp.md",
        "pages/mcp/mcp_claude_code.md",
        "pages/mcp/mcp_cursor.md",
        "pages/mcp/mcp_neovim.md",
        "pages/mcp/mcp_codex.md",
        "pages/mcp/mcp_opencode.md",
        "pages/mcp/mcp_vscode.md"
      ],
      groups_for_extras: [
        Welcome: "pages/welcome.md",
        Tidewave: ~r/(pages\/features\/.?)/,
        "Tidewave MCP": ~r/pages\/mcp\/.?/,
        "Tidewave IDE": ~r/(pages\/ide\/.?)/,
        References: ~r/(pages\/references\/.?)/
      ],
      redirects: %{
        "react" => "frontend",
        "vue" => "frontend",
        "mcp_troubleshooting" => "mcp",
        "subdomains" => "custom_domains"
      },
      before_closing_head_tag: fn _ ->
        # Hide version nodes to avoid confusion between TidewaveApp and TidewavePhoenix.
        # But we still keep go to latest.
        "<style>.sidebar-projectVersion form label { display: none; }</style>"
      end
    ]
  end
end
