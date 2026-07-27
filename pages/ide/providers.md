# Providers

Tidewave IDE supports multiple coding-agent providers. You can connect them from the Providers tab in Tidewave IDE settings.

## Official providers

### Claude Code

You can connect Tidewave IDE directly to [Claude Code](https://www.claude.com/product/claude-code).

Simply open up Tidewave IDE settings, choose the Providers tab, choose "Claude Code" and click "Connect". Next we will automatically download and install Claude for you.

Once connected, we will automatically configure Claude to also use Tidewave MCP. You may disable this option if (and only if) you have already customized Claude Code to use Tidewave MCP.

> #### Custom `claude-agent-acp` and `claude` installation {: .info}
>
> Tidewave IDE talks to Claude Code using the [Claude Agent ACP](https://github.com/zed-industries/claude-agent-acp) project. It is possible to use custom `claude-agent-acp` and `claude` executables by setting the `TIDEWAVE_CLAUDE_AGENT_ACP_EXECUTABLE` and `CLAUDE_CODE_EXECUTABLE` environment variables when starting your web application. This is rarely needed in practice but it may be required in some operating systems such as NixOS. See [customizing your environment](#customizing-your-environment).

### GitHub Copilot

You can connect Tidewave IDE directly to [GitHub Copilot CLI](https://github.com/features/copilot/cli). The [GitHub Copilot subscription](https://github.com/features/copilot) will give you access to models from Anthropic, OpenAI, xAI, and other providers.

Simply open up Tidewave IDE settings, choose the Providers tab, choose "GitHub Copilot" and click "Connect". Next we will automatically download and install the Copilot CLI for you. Once connected, we will automatically configure the Copilot CLI to use Tidewave MCP. You may disable this option if (and only if) you have already customized the Copilot CLI to use Tidewave MCP.

You can control which Copilot models are available to Tidewave IDE in [your GitHub Copilot settings](https://github.com/settings/copilot).

> #### Custom `copilot-cli` installation {: .info}
>
> It is possible to use a custom `copilot` executable by setting the `TIDEWAVE_COPILOT_CLI_EXECUTABLE` environment variable when starting your web application. This is rarely needed in practice but it may be required in some operating systems like NixOS.

> #### BYOK not supported {: .warn}
>
> While GitHub Copilot does support [bringing your own key (BYOK)](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models), this functionality is not available via ACP (the protocol Tidewave IDE uses to communicate with the `copilot` CLI) at the moment. Consider using OpenCode or Codex instead.

### OpenAI Codex

You can connect Tidewave IDE directly to [OpenAI Codex CLI](https://developers.openai.com/codex/cli) by following the steps below:

Simply open up Tidewave IDE settings, choose the Providers tab, choose "Codex" and click "Connect". Next we will automatically download and install Codex for you.

Once connected, we will automatically configure Codex to also use Tidewave MCP. You may disable this option if (and only if) you have already customized Claude Code to use Tidewave MCP.

> #### Custom `codex-acp` installation
>
> Tidewave IDE talks to Codex using the [Codex ACP](https://github.com/agentclientprotocol/claude-agent-acp) project. It is possible to use a custom `codex-acp` executable by setting the `TIDEWAVE_CODEX_ACP_EXECUTABLE` environment variable when starting your web application. This is rarely needed in practice but it may be required in some operating systems like NixOS.

### OpenCode

You can connect Tidewave IDE directly to [OpenCode](https://opencode.ai).

Simply open up Tidewave IDE settings, choose the Providers tab, choose "OpenCode" and click "Connect". Next we will automatically download and install OpenCode for you.

Once connected, we will automatically configure OpenCode to also use Tidewave MCP. You may disable this option if (and only if) you have already customized OpenCode to use Tidewave MCP.

> #### Custom `opencode` installation {: .info}
>
> It is possible to use a custom `opencode` executable by setting the `TIDEWAVE_OPENCODE_EXECUTABLE` environment variable when starting your web application. This is rarely needed in practice but it may be required in some operating systems like NixOS.

<!-- tabs-close -->

## Third-party providers

There are three mechanisms you can extend Tidewave IDE beyond the providers listed above.

* [By using OpenCode and adding the models of your choice](#opencode-providers). OpenCode supports 75+ different providers, including local ones

* [By using Codex with custom providers](#codex-custom-providers). The Codex CLI can be customized to run with any OpenAI compatible providers, which includes [Ollama](https://ollama.com) and external services

* By using External Agents that implement the [Agent Client Protocol](https://agentclientprotocol.com/get-started/registry) (ACP) - you can enable them in the "External Agents" tab under the advanced settings. Given ACP is still evolving, keep in mind Tidewave IDE may not work as expected with all possible agents

### OpenCode providers

OpenCode supports [+75 different providers](https://opencode.ai/docs/providers/), including GitHub Copilot subscriptions, OpenRouter, and Moonshot AI.

You can add new models directly from Tidewave IDE, by clicking the "Add models" button inside the Provider settings:

![Adding models to OpenCode](assets/opencode.png)

### Codex custom providers

Codex comes with the ablity of running custom providers. This can be used to configure [Ollama](https://docs.ollama.com/integrations/codex), OpenRouter, and other OpenAI compatible endpoints.

For example, to use Codex with OpenRouter, add the following to `~/.codex/config.toml`:

```toml
model = "anthropic/claude-sonnet-4.5"
model_provider = "openrouter"

[model_providers.openrouter]
name = "Openrouter"
base_url = "https://openrouter.ai/api/v1"
http_headers = { "Authorization" = "Bearer sk-or-v1-..." }
wire_api = "chat"
```

## Customizing your environment

Our integration will reuse your coding agent settings. Furthermore, Tidewave IDE will automatically pass your environment variables to your coding agent, using this level of priority:

1. the environment variables used when starting your web app (higher priority)
2. the environment variables configured in your Tidewave IDE app (or given to the Tidewave IDE CLI)

For example, to configure the Tidewave IDE app to use [Claude Code's environment variables](https://code.claude.com/docs/en/settings#environment-variables), click on the Tidewave IDE icon in your menu bar (top-right on macOS and Linux, bottom-right on Windows) and then on "Configuration". Doing so will open a file where you can add the desired environment variables, for example:

```toml
# This file is used to configure the Tidewave IDE app.
# If you change this file, you must restart Tidewave IDE.

[env]
CLAUDE_CODE_USE_VERTEX = "1"
CLAUDE_CODE_EXECUTABLE = "..."
```

If you are using the CLI, you can set those variables when starting the CLI.

## FAQ

### Tidewave IDE emits "Authentication required"

This means you haven't authenticated with your provider's CLI. Go to "Settings", click "Providers", select your provider, and then click "Open Terminal" to follow its authentication steps. Alternatively, run the provider's CLI in your terminal of choice and authenticate there.

If Tidewave IDE still claims you are not authenticated, restart the Tidewave IDE App/CLI by clicking its menu bar icon (top-right on macOS and Linux, bottom-right on Windows) and selecting "Restart".
