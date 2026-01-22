# OpenAI Codex

You can connect Tidewave Web directly to [OpenAI Codex CLI](https://developers.openai.com/codex/cli) by following the steps below:

1. Install the `codex` CLI
2. Authenticate with your OpenAI subscription
3. Connect to Codex

Once setup, Tidewave will use your OpenAI subscription and settings (including MCP servers, subagents, etc).

## Install the `codex` CLI

Follow [OpenAI's official intructions to install the Codex CLI](https://developers.openai.com/codex/cli/).

## Authenticate with OpenAI

Once `codex` is installed, you must authenticate with your OpenAI subscription. You can do this by simply running `codex` in any directory and then following the described steps:

```shell
codex
```

## Connect to Codex

Open up Tidewave Web settings, choose the Providers tab, choose "OpenAI Codex" and click "Connect".

Once connected, we will automatically configure Codex to also use Tidewave MCP. You may disable this option if (and only if) you have already customized Codex to use Tidewave MCP.

## Custom Providers

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

## FAQ

#### Using Tidewave Web with Codex emits "Authentication required"

This means you haven't authenticated in the `codex` CLI. Remember to run `codex` and, if Tidewave Web still claims you are not authenticated, restart the Tidewave App/CLI by clicking its menu bar icon (top-right on macOS and Linux, bottom-right on Windows) and selecting "Restart".