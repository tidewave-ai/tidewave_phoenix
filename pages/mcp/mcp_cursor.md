# Cursor

You can use Tidewave MCP with [Cursor](https://cursor.com/).

Cursor allows you to place a file at `.cursor/mcp.json`, for configuration
which is specific to your project. Given Tidewave is explicitly tied to your
web application, that's our preferred approach.

Create a file at `.cursor/mcp.json` and add the following contents:

```json
{
  "mcpServers": {
    "tidewave": {
      "url": "http://localhost:$PORT/tidewave/mcp"
    }
  }
}
```

Where `$PORT` is the port your web application is running on.

If you prefer, you can also add Tidewave globally to your editor
by adding the same contents as above to the `~/.cursor/mcp.json`
file. If you have trouble locating such file, open up Cursor's
assistant tab and click on the `⋯` icon on the top right and
choose "Chat Settings". In the new window that opens, you can
click "MCP" on the sidebar and follow the steps there.

If your application uses a SQL database, you can verify it all works
by asking it to run `SELECT 1` as database query.
If it fails, check out [our MCP Troubleshooting section](mcp.md#troubleshooting)
or [Cursor's official docs](https://docs.cursor.com/context/model-context-protocol).

