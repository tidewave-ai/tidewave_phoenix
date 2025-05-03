# Claude

You can use Tidewave with Claude Desktop and Claude Code.

## Claude Desktop

To use Tidewave with Claude Desktop, you must first install
a [`mcp-proxy`](../guides/mcp_proxy.md).

Then open up Claude Desktop, go to "Settings" and, under the
"Developer" tab, click on "Edit Config". It will point to a file
you can open in your favorite editor. Which you must edit to
include the following settings, depending on the proxy:

<!-- tabs-open -->

### Python Proxy

On macos/Linux:

```json
{
  "mcpServers": {
    "tidewave": {
      "command": "/path/to/mcp-proxy",
      "args": ["http://localhost:$PORT/tidewave/mcp?include_fs_tools=true"]
    }
  }
}
```

On Windows:

```json
{
  "mcpServers": {
    "tidewave": {
      "command": "/path/to/mcp-proxy.exe",
      "args": ["http://localhost:$PORT/tidewave/mcp?include_fs_tools=true"]
    }
  }
}
```

Where `$PORT` is the port your web application is running on.

### Elixir Proxy

On macos/Linux:

```json
{
  "mcpServers": {
    "tidewave": {
      "command": "/path/to/escript",
      "args": [
        "/$HOME/.mix/escripts/mcp-proxy",
        "http://localhost:$PORT/tidewave/mcp?include_fs_tools=true"
      ]
    }
  }
}
```

On Windows:

```json
{
  "mcpServers": {
    "tidewave": {
      "command": "escript.exe",
      "args": [
        "/$HOME/.mix/escripts/mcp-proxy",
        "http://localhost:$PORT/tidewave/mcp?include_fs_tools=true"
      ]
    }
  }
}
```

Where you replace `$HOME` by your home folder (shown during installation)
and `$PORT` by the port your web application is running on.

<!-- tabs-close -->

And you are good to go! Note we enabled filesystem tools by default,
as Claude Desktop does not support any filesystem operation out of the box.
If your application uses a SQL database, you can verify it all works
by asking it to run `SELECT 1` as database query.

## Claude Code

Adding Tidewave to [Claude Code](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview)
is straight-forward, just run:

```shell
$ claude mcp add --transport sse tidewave http://127.0.0.1:$PORT/tidewave/mcp
```

Where `$PORT` is the port your web application is running on. And you are good to go!
