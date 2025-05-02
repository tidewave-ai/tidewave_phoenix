# Windsurf

You can use Tidewave with [Windsurf](https://windsurf.com/). First, you must
install a [`mcp-proxy`](../guides/mcp_proxy.md).

Once you are done, open up your "Windsurf Settings", find the "Cascade" section,
click "Add Server" and then "Add custom server". A file will open up and you can
manually add Tidewave, according to your proxy of choice:

<!-- tabs-open -->

### Python Proxy

On macos/Linux:

```json
{
  "mcpServers": {
    "tidewave": {
      "command": "/path/to/mcp-proxy",
      "args": ["http://localhost:$PORT/tidewave/mcp"]
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
      "args": ["http://localhost:$PORT/tidewave/mcp"]
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
        "http://localhost:$PORT/tidewave/mcp"
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
        "http://localhost:$PORT/tidewave/mcp"
      ]
    }
  }
}
```

Where you replace `$HOME` by your home folder (shown during installation)
and `$PORT` by the port your web application is running on.

### SSE connection

Note, if you restart your dev server, you will need to refresh the MCP connection. 

```json
{
  "mcpServers": {
    "tidewave": {
      "serverUrl": "http://localhost:4000/tidewave/mcp"
    }
  }
}
```

<!-- tabs-close -->

And you are good to go! Now Windsurf will list all tools from Tidewave
available. If your application uses a SQL database, you can verify it
all works by asking it to run `SELECT 1` as database query.
If you have any questions, check out [Windsurf official docs](https://docs.windsurf.com/windsurf/mcp#configuring-mcp).
