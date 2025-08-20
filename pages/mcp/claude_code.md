# Claude Code

> To use Tidewave with Claude Desktop, [see here](claude.md).

Adding Tidewave to [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview)
is straight-forward, just run:

<!-- tabs-open -->

### Rails

```shell
$ claude mcp add --transport sse tidewave http://localhost:$PORT/tidewave/mcp
```

### Phoenix

```shell
$ claude mcp add --transport http tidewave http://localhost:$PORT/tidewave/mcp
```

<!-- tabs-close -->

To use it with [the `mcp-proxy`](guides/mcp_proxy.md), run:

```shell
$ claude mcp add --transport stdio tidewave /path/to/mcp-proxy http://localhost:$PORT/tidewave/mcp
```

Where `$PORT` is the port your web application is running on. And you are good to go!
