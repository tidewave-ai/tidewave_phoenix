# Providers

In order to use Tidewave Web, you will need either a [GitHub Copilot subscription](https://github.com/features/copilot) or an [Anthropic API key](https://anthropic.com/api).

## GitHub Copilot

A GitHub Copilot subscription will give you access to models from Anthropic, OpenAI, xAI, and other providers. Simply choose GitHub Copilot as your provider in Settings and follow the authentication steps.

You can control which Copilot models are available to Tidewave in [your GitHub Copilot settings](https://github.com/settings/copilot).

## Anthropic API

You can also use Tidewave with an Anthropic API key. You can [create an Anthropic API key](https://console.anthropic.com/settings/keys) and paste it into your provider configuration in Settings. Alternatively, you may set the `ANTHROPIC_API_KEY` as an [environment variable](https://en.wikipedia.org/wiki/Environment_variable), which will be automatically picked up by Tidewave.

Note your Anthropic API key is separate from your Claude Code subscription. We don't support Claude Code at the moment. You can [manage your account and credits in the Anthropic Console](https://console.anthropic.com/settings/billing).

## OpenAI API

You can also use Tidewave with an OpenAI API key. You can [create an OpenAI API key](https://openai.com/api/) and paste it into your provider configuration in Settings. Alternatively, you may set the `OPENAI_API_KEY` as an [environment variable](https://en.wikipedia.org/wiki/Environment_variable), which will be automatically picked up by Tidewave.

## OpenRouter

You can also use Tidewave with OpenRouter. You can [create an OpenRouter API key](https://openrouter.ai/settings/keys) and paste it into your provider configuration in Settings. Alternatively, you may set the `OPENROUTER_API_KEY` as an [environment variable](https://en.wikipedia.org/wiki/Environment_variable), which will be automatically picked up by Tidewave.
