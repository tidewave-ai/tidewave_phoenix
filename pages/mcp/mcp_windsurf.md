# Windsurf

You can use Tidewave MCP with [Windsurf](https://windsurf.com/). First, you must
install a [`mcp-proxy`](../guides/mcp_proxy.md).

Once you are done, open up your "Windsurf Settings", find the "Cascade" section,
click "Add Server" and then "Add custom server". A file will open up and you can
manually add Tidewave:

<!-- tabs-open -->

### HTTP connection

Windsurf also supports MCP servers through HTTP:

```json
{
  "mcpServers": {
    "tidewave": {
      "serverUrl": "http://localhost:4000/tidewave/mcp"
    }
  }
}
```

Note, if you restart your dev server, you will need to refresh the MCP connection.

### MCP Proxy

See the [MCP proxy documentation](guides/mcp_proxy.md).

On macOS/Linux:

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

<!-- tabs-close -->

And you are good to go! Now Windsurf will list all tools from Tidewave
available. If your application uses a SQL database, you can verify it
all works by asking it to run `SELECT 1` as database query.
If it fails, check out [our MCP Troubleshooting guide](mcp_troubleshooting.md)
or [Windsurf's official docs](https://docs.windsurf.com/windsurf/mcp#configuring-mcp).

