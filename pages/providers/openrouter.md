# OpenRouter

There are two options to connect Tidewave Web to OpenRouter:

* [By using OpenCode and adding the models of your choice](opencode.md). OpenCode supports 75+ different providers, including OpenRouter

* [By using Codex with custom providers](codex.md#custom-providers). The Codex CLI can be customized to run with any OpenAI compatible providers, which includes OpenRouter

## `OPENROUTER_API_KEY`

You can set the `OPENROUTER_API_KEY` environment variable in your Tidewave app and OpenCode should automatically pick it up. Click on the Tidewave icon in your menu bar (top-right on macOS and Linux, bottom-right on Windows) and then on "Settings...". Doing so will open a file where you can add the desired environment variables, for example:

```toml
# This file is used to configure the Tidewave app.
# If you change this file, you must restart Tidewave.

[env]
OPENROUTER_API_KEY = "sk-or-v1-..."
```

If you are using the CLI, you can set those variables when starting the CLI. You may also set the environment variable in the session that starts your web server and Tidewave Web should automatically pick it up too.
