# Claude Code

You can connect Tidewave Web directly to [Claude Code](https://www.claude.com/product/claude-code) by following the steps below:

1. Install the `claude` code CLI
2. Authenticate with your Claude subscription
3. Install Claude Code ACP

Once setup, Tidewave Web will use your Claude Code subscription and settings (including MCP servers, subagents, etc).

## Install the `claude` code CLI

You can [install the Claude Code CLI in many different ways](https://docs.claude.com/en/docs/claude-code/setup). However, because installing the `Claude Code ACP`, in step 3, requires using `npm`, our recommendation is to [install `npm`](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm) and then run:

```shell
npm install -g @anthropic-ai/claude-code`
```

If you install `claude` and Tidewave Web cannot detect it, please restart your web application and the Tidewave App/CLI.

## Authenticate with Claude

Once `claude` is installed, you must authenticate with your Claude subscription. You can do this by simply running `claude` in any directory and then following the described steps:

```shell
claude
```

> #### Check your `claude /status` {: .warning}
>
> If you have the `ANTHROPIC_API_KEY` environment variable set, `claude` will automatically use it if you don't log in. For this reason, we recommend running `claude /status` and double checking the "Login method" field to validate it is using one of your Claude Pro or Claude Max subscriptions. If you want to be double sure, consider unsetting the environment variable.

## Install Claude Code ACP

This step is not strictly required. If you have `npx` available in your PATH, Tidewave Web will automatically use it to install [Claude Code ACP](https://github.com/zed-industries/claude-code-acp). If it fails, you can explicitly install it with:

```shell
npm install -g @zed-industries/claude-code-acp
```

## Customizing your environment

Our integration will reuse your Claude Code settings. Furthermore, when we start Claude Code, we pass the same environment variables which you used to start your server to Claude Code.

However, if you want to set any of [Claude Code's environment variables] to be used exclusively with Tidewave, you can do so by clicking on the Tidewave icon in your menu bar (top-right on macOS and Linux, bottom-right on Windows) and then on "Settings...". Doing so will open a file where you can add the desired environment variables, for example:

```toml
# This file is used to configure the Tidewave app.
# If you change this file, you must restart Tidewave.

[env]
CLAUDE_CODE_USE_VERTEX = "1"
```
