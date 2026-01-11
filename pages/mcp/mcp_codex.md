# Codex

You can use Tidewave MCP with OpenAI's [Codex CLI](https://developers.openai.com/codex/cli/)

> #### Tidewave Web vs Tidewave MCP {: .info}
>
> The instructions here are about connecting Tidewave MCP and Codex together. To use Tidewave Web (the one running in your browser) and Codex, please [read this guide](../integrations/codex.md).

## Install

Invoke the `codex` CLI to add `tidewave` using the HTTP transport:


```shell
$ codex mcp add tidewave --url http://localhost:$PORT/tidewave/mcp
```

Where `$PORT` is the port your web application is running on. And you are good to go!

## Verify

Running `codex mcp list` will show you the config is there, but won't verify the connection. You can verify the MCP connection is working by starting Codex and running the `/mcp` command. If it's connected, you should see the list of Tidewave tools. If not, check out our [MCP Troubleshooting guide](mcp.md#troubleshooting).
