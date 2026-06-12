# OpenAI Codex

You can connect Tidewave Web directly to [OpenAI Codex CLI](https://developers.openai.com/codex/cli) by following the steps below:

Simply open up Tidewave Web settings, choose the Providers tab, choose "Codex" and click "Connect". Next we will automatically download and install Codex for you.

Once connected, we will automatically configure Codex to also use Tidewave MCP. You may disable this option if (and only if) you have already customized Claude Code to use Tidewave MCP.

> #### ChatGPT subscription {: .warning}
>
> Tidewave usage of Codex is compatible with your ChatGPT subscription. Note you can also use your OpenAI subscription with [OpenCode](opencode.md).

> #### Custom `codex-acp` installation
>
> Tidewave talks to Codex using the [Codex ACP](https://github.com/agentclientprotocol/claude-agent-acp) project. It is possible to use a custom `codex-acp` executable by setting the `TIDEWAVE_CODEX_ACP_EXECUTABLE` environment variable when starting your web application. This is rarely needed in practice but it may be required in some operating systems like NixOS.

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

This means you haven't authenticated in the `codex` CLI. Go to "Settings", click "Providers", and then "Codex". If you are connected to Codex, you should see a "Open Terminal" option. Open up the terminal and it will guide you through the login steps. Alternatively, you can run `codex` in your terminal of choice.

If Tidewave Web still claims you are not authenticated, restart the Tidewave App/CLI by clicking its menu bar icon (top-right on macOS and Linux, bottom-right on Windows) and selecting "Restart".
