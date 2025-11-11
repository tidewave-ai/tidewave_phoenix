# Windsurf

You can use Tidewave MCP with [Windsurf](https://windsurf.com/). First, you must
install a [`mcp-proxy`](../guides/mcp_proxy.md).

Once you are done, open up your "Windsurf Settings", find the "Cascade" section,
click "Add Server" and then "Add custom server". A file will open up and you can
manually add Tidewave:

```json
{
  "mcpServers": {
    "tidewave": {
      "serverUrl": "http://localhost:$PORT/tidewave/mcp"
    }
  }
}
```

where `$PORT` is the port your web application is running on.

<!-- tabs-close -->

And you are good to go! Now Windsurf will list all tools from Tidewave
available. If your application uses a SQL database, you can verify it
all works by asking it to run `SELECT 1` as database query.
If it fails, check out [our MCP Troubleshooting guide](mcp_troubleshooting.md)
or [Windsurf's official docs](https://docs.windsurf.com/windsurf/mcp#configuring-mcp).

