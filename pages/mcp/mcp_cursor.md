# Cursor

You can connect [Cursor](https://cursor.com/) to Tidewave through Cursor's MCP support.

## Install

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

Replace `$PORT` by the port your web application is running on.

If you prefer, you can also add Tidewave globally to your editor
by adding the same contents as above to the `~/.cursor/mcp.json`
file. If you have trouble locating that file, open up Cursor's
assistant tab and click on the `⋯` icon on the top right and
choose "Chat Settings". In the new window that opens, you can
click "MCP" on the sidebar and follow the steps there.

## Verify

You can verify it all works by starting a new session and asking
your agent if it can see Tidewave's tools.
If it fails, check out [our MCP Troubleshooting section](mcp.md#troubleshooting)
or [Cursor's official docs](https://docs.cursor.com/context/model-context-protocol).
