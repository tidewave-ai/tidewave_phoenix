# Claude Code

You can connect Tidewave Web directly to [Claude Code](https://www.claude.com/product/claude-code) by following the steps below:

1. Install the `claude` CLI
2. Authenticate with your Claude subscription
3. Connect to Claude Code

Once setup, Tidewave will use your Claude Code subscription and settings (including MCP servers, subagents, etc).

## Install the `claude` CLI

You can [install the Claude Code CLI in different ways](https://docs.claude.com/en/docs/claude-code/setup). However, because installing the `Claude Code ACP`, in step 3, requires using `npm`, our recommendation is to [install `npm`](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm) and then run:

```shell
npm install -g @anthropic-ai/claude-code`
```

If you install `claude` and Tidewave Web cannot detect it, please restart the Tidewave App/CLI by clicking its menu bar icon (top-right on macOS and Linux, bottom-right on Windows) and selecting "Restart".

## Authenticate with Claude

Once `claude` is installed, you must authenticate with your Claude subscription. You can do this by simply running `claude` in any directory and then following the described steps:

```shell
claude
```

## Connect to Claude Code

If you have `npm`/`npx` available in your PATH, Tidewave will use it to automatically install and connect to [Claude Code ACP](https://github.com/zed-industries/claude-code-acp). Open up Tidewave Web settings, choose the Providers tab, choose "Claude Code" and click "Connect".

<iframe width="640" height="360" src="https://www.youtube.com/embed/qxzPZ0PGd2s?si=mnci1z08B44y1F5z" title="Tidewave and Claude Code" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

If "Connect" is not available, it is because `npm`/`npx` could not be found. You can check your `npm`/`npx` installation by running `which npx` (on macOS/Unix) or `where npx` (Windows) in the same terminal you start your web server. If it fails (and only if it fails), you can explicitly install `claude-code-acp` with `npm install -g @zed-industries/claude-code-acp`.

Once Tidewave Web connects to Claude Code, we will automatically configure Claude Code to also use Tidewave MCP. You may disable this option if (and only if) you have already customized Claude Code to use Tidewave MCP.

## Customizing your environment

Our integration will reuse your Claude Code settings. Furthermore, when we start Claude Code, we give it the same environment variables which you used to start your server.

However, if you want to set any of [Claude Code's environment variables](https://code.claude.com/docs/en/settings#environment-variables) to be used exclusively with Tidewave, you can do so by clicking on the Tidewave icon in your menu bar (top-right on macOS and Linux, bottom-right on Windows) and then on "Settings...". Doing so will open a file where you can add the desired environment variables, for example:

```toml
# This file is used to configure the Tidewave app.
# If you change this file, you must restart Tidewave.

[env]
CLAUDE_CODE_USE_VERTEX = "1"
CLAUDE_CODE_EXECUTABLE = "..."
```

Note the environment variables used when starting your web server will override any variable defined in the Tidewave App/CLI.

## FAQ

#### Using Tidewave Web with Claude Code emits "Authentication required"

This means you haven't authenticated in the `claude` CLI. Remember to run `claude` and, if Tidewave Web still claims you are not authenticated, restart the Tidewave App/CLI by clicking its menu bar icon (top-right on macOS and Linux, bottom-right on Windows) and selecting "Restart".

#### `claude` is available on my machine but Tidewave cannot find it

Please double check `claude` is indeed available as an executable by running `which claude`. In some installations, `claude` is installed as an alias, which cannot be found nor used by Tidewave.