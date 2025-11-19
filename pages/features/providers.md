# Providers

In order to use Tidewave Web, you will need one of:

* Claude Code subscription
* OpenAI Codex subscription
* GitHub Copilot subscription
* Bring your own API keys (for Anthropic, OpenAI, or OpenRouter)
* Local and third-party providers

Read more below.

## Claude Code

See [our step-by-step instructions to connect Tidewave to Claude Code](../guides/claude_code.md).

## OpenAI Codex

See [our step-by-step instructions to connect Tidewave to OpenAI Codex](../guides/codex.md).

## GitHub Copilot

A [GitHub Copilot subscription](https://github.com/features/copilot) will give you access to models from Anthropic, OpenAI, xAI, and other providers. Simply choose GitHub Copilot as your provider in Settings and follow the authentication steps.

You can control which Copilot models are available to Tidewave in [your GitHub Copilot settings](https://github.com/settings/copilot).

## Bring your own API keys

### Anthropic API

You can also use Tidewave with an Anthropic API key. You can [create an Anthropic API key](https://console.anthropic.com/settings/keys) and paste it into your provider configuration in Settings. Alternatively, you may set the `ANTHROPIC_API_KEY` as an [environment variable](https://en.wikipedia.org/wiki/Environment_variable), which will be automatically picked up by Tidewave.

Note your Anthropic API key is separate from your Claude Code subscription. You can [manage your account and credits in the Anthropic Console](https://console.anthropic.com/settings/billing).

### OpenAI API

You can also use Tidewave with an OpenAI API key. You can [create an OpenAI API key](https://openai.com/api/) and paste it into your provider configuration in Settings. Alternatively, you may set the `OPENAI_API_KEY` as an [environment variable](https://en.wikipedia.org/wiki/Environment_variable), which will be automatically picked up by Tidewave.

### OpenRouter

You can also use Tidewave with OpenRouter. You can [create an OpenRouter API key](https://openrouter.ai/settings/keys) and paste it into your provider configuration in Settings. Alternatively, you may set the `OPENROUTER_API_KEY` as an [environment variable](https://en.wikipedia.org/wiki/Environment_variable), which will be automatically picked up by Tidewave.

## Local and third-party providers

There are two mechanisms you can extend Tidewave beyond the providers listed above.

* [By using Codex with custom providers](../integrations/codex.md#custom-providers) - the Codex CLI can be customized to run with any OpenAI compatible providers, which includes [Ollama](https://ollama.com) and external services

* By using External Agents that implement the [Agent Client Protocol](http://agentclientprotocol.com) (ACP) - you can enable them in the "External Agents" tab under the advanced settings. Given ACP is still evolving, keep in mind Tidewave may not work as expected when using such agents
