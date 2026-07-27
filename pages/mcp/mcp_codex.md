# OpenAI Codex

You can connect OpenAI's [Codex CLI](https://developers.openai.com/codex/cli/) to Tidewave via its MCP support.

## Install

Invoke the `codex` CLI to add `tidewave` using the HTTP transport:


```shell
$ codex mcp add tidewave --url http://localhost:$PORT/tidewave/mcp
```

Replace `$PORT` by the port your web application is running on. And you are good to go!

## Verify

Running `codex mcp list` will show you the config is there, but won't verify the connection. You can verify the MCP connection is working by starting Codex and running the `/mcp` command. If it's connected, you should see the list of Tidewave tools. If not, check out our [MCP Troubleshooting guide](mcp.md#troubleshooting).
