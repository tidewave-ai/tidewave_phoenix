# OpenAI Codex

You can connect Tidewave Web directly to [OpenAI Codex CLI](https://developers.openai.com/codex/cli) by following the steps below:

1. Install the `codex` CLI
2. Authenticate with your OpenAI subscription
3. Connect to Codex

Once setup, Tidewave will use your OpenAI subscription and settings (including MCP servers, subagents, etc).

## Install the `codex` CLI

You can [install the Codex CLI in different ways](https://developers.openai.com/codex/cli/). However, because installing the `OpenAI Codex ACP`, in step 3, requires using `npm`, our recommendation is to [install `npm`](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm) and then run:

```shell
npm install -g @openai/codex
```

If you install `codex` and Tidewave Web cannot detect it, please restart the Tidewave App/CLI by clicking its menu bar icon (top-right on macOS and Linux, bottom-right on Windows) and selecting "Restart".

## Authenticate with OpenAI

Once `codex` is installed, you must authenticate with your OpenAI subscription. You can do this by simply running `codex` in any directory and then following the described steps:

```shell
codex
```

## Connect to Codex

If you have `npm`/`npx` available in your PATH, which is the preferred method forward, Tidewave will use it to automatically install and connect to [Codex ACP](https://github.com/zed-industries/codex-acp). Open up Tidewave Web settings, choose the Providers tab, choose "OpenAI Codex" and click "Connect".

If "Connect" is not available, it is because `npm`/`npx` could not be found. You can check your `npm`/`npx` installation by running `which npx` (on macOS/Unix) or `where npx` (Windows) in the same terminal you start your web server. If it fails (and only if it fails), you can explicitly install `codex-acp` with `npm install -g @zed-industries/codex-acp`.

Once Tidewave Web connects to Codex, we will automatically configure Codex to also use Tidewave MCP. You may disable this option if (and only if) you have already customized Codex to use Tidewave MCP.

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