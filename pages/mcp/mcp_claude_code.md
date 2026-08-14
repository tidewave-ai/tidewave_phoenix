# Claude Code

You can connect [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview) to Tidewave via the Claude CLI.

## Install

Invoke the `claude` CLI to add `tidewave` using the HTTP transport:

```shell
$ claude mcp add --transport http tidewave http://localhost:$PORT/tidewave/mcp
```

Replace `$PORT` by the port your web application is running on. And you are good to go!

## Verify

You can verify the MCP connection is working by starting Claude Code and running the `/mcp` command. If the status is different from "✔ connected", please double check you are using the correct transport (SSE or HTTP) for your web framework as listed in the configuration above. If you see a 405 error, the root cause is most likely an incorrect transport.

Furthermore, notice that **Tidewave does not require authentication**, as it runs on your machine and accepts only local connections by default. If you select the "Authenticate" option, it will lead to errors, as Tidewave does not implement any of the authentication endpoints specified by the protocol.
