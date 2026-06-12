# Claude Code

You can connect Tidewave Web directly to [Claude Code](https://www.claude.com/product/claude-code).

Simply open up Tidewave Web settings, choose the Providers tab, choose "Claude Code" and click "Connect". Next we will automatically download and install Claude for you.

Once connected, we will automatically configure Claude to also use Tidewave MCP. You may disable this option if (and only if) you have already customized Claude Code to use Tidewave MCP.

> #### Claude Agent SDK {: .warning}
>
> Tidewave uses the Claude Agent SDK to integrate with Claude Code. From June 15th, 2026, programmatic usage of Claude Code (such as the Claude Agent SDK and `claude -p` itself) are no longer part of your subscription and will use API pricing. [Some users may be eligible to extra credits](https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan).
>
> In case those credits are not sufficient, consider using alternative subscriptions, such as Codex and OpenCode, which do not discriminate between programmatic and interactive usage.

## Customizing your environment

Our integration will reuse your Claude Code settings. Furthermore, Tidewave will automatically pass your environment variables to Claude Code, using this level of priority:

1. the environment variables used when starting your web app (higher priority)
2. the environment variables configured in your Tidewave App (or given to the Tidewave CLI)

To configure the Tidewave app to use [Claude Code's environment variables](https://code.claude.com/docs/en/settings#environment-variables), click on the Tidewave icon in your menu bar (top-right on macOS and Linux, bottom-right on Windows) and then on "Configuration". Doing so will open a file where you can add the desired environment variables, for example:

```toml
# This file is used to configure the Tidewave app.
# If you change this file, you must restart Tidewave.

[env]
CLAUDE_CODE_USE_VERTEX = "1"
CLAUDE_CODE_EXECUTABLE = "..."
```

If you are using the CLI, you can set those variables when starting the CLI.

> #### Custom `claude-agent-acp` and `claude` installation {: .info}
>
> Tidewave talks to Claude Code using the [Claude Agent ACP](https://github.com/zed-industries/claude-agent-acp) project. It is possible to use custom `claude-agent-acp` and `claude` executables by setting the `TIDEWAVE_CLAUDE_AGENT_ACP_EXECUTABLE` and `CLAUDE_CODE_EXECUTABLE` environment variables when starting your web application. This is rarely needed in practice but it may be required in some operating systems such as NixOS. Example variables for NixOS:
> 
> ```
> TIDEWAVE_CLAUDE_AGENT_ACP_EXECUTABLE = "/run/current-system/sw/bin/claude-agent-acp"
> CLAUDE_CODE_EXECUTABLE = "/run/current-system/sw/bin/claude"
> ```

## FAQ

#### Using Tidewave Web with Claude Code emits "Authentication required"

This means you haven't authenticated in the `claude` CLI. Go to "Settings", click "Providers", and then "Claude Code". If you are connected to Claude Code, you should see a "Open Terminal" option. Open up the terminal and type `/login` to authenticate. Alternatively, you can run `claude` in your terminal of choice.

If Tidewave Web still claims you are not authenticated, restart the Tidewave App/CLI by clicking its menu bar icon (top-right on macOS and Linux, bottom-right on Windows) and selecting "Restart".
