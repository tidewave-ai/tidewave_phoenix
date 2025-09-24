# Codex

You can use Tidewave with OpenAI's [Codex CLI](https://developers.openai.com/codex/cli/)

## Installation

First, you must install a [`mcp-proxy`](guides/mcp_proxy.md).

```shell
$ codex mcp add tidewave /path/to/mcp-proxy http://localhost:$PORT/tidewave/mcp
```
Where `$PORT` is the port your web application is running on. And you are good to go!

## Verify

Running `codex mcp list` will show you the config is there, but won't verify the connection. You can verify the MCP connection is working by starting Codex and running the `/mcp` command. If it's connected, you should see the list of Tidwave tools. If not, see f it fails, check out our [MCP Troubleshooting guide](mcp_troubleshooting.md)
