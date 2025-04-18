defmodule Tidewave.MixProject do
  use Mix.Project

  def project do
    [
      app: :tidewave,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

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

  defp deps do
    [
      {:plug, "~> 1.17"},
      {:jason, "~> 1.4"},
      {:circular_buffer, "~> 0.4"},
      {:req, "~> 0.5"},
      {:bandit, "~> 1.6", only: :test},
      {:ex_doc, ">= 0.0.0", only: :docs}
    ]
  end

  defp docs do
    [
      api_reference: false,
      main: "installation",
      logo: "logo.svg",
      extras: [
        "pages/installation.md",
        "pages/editors/mcp.md",
        "pages/editors/claude.md",
        "pages/editors/cursor.md",
        "pages/editors/windsurf.md",
        "pages/editors/zed.md",
        "pages/guides/mcp_proxy.md",
        "pages/guides/security.md"
      ],
      groups_for_extras: [
        "Editors & Assistants": ~r/pages\/editors\/.?/,
        Guides: ~r/pages\/guides\/.?/
      ]
    ]
  end
end
