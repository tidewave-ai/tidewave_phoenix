# Claude Code

Adding Tidewave to [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview)
is straight-forward, just run:

```shell
$ claude mcp add --transport sse tidewave http://localhost:$PORT/tidewave/mcp
```

To use it with [the `mcp-proxy`](guides/mcp_proxy.md), run:

```shell
$ claude mcp add --transport stdio tidewave /path/to/mcp-proxy http://localhost:$PORT/tidewave/mcp
```

Where `$PORT` is the port your web application is running on. And you are good to go!
