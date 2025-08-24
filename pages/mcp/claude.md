# Claude Desktop

> To use Tidewave with Claude Code, [see here](claude_code.md).

To use Tidewave with [Claude Desktop](https://support.anthropic.com/en/articles/10065433-installing-claude-desktop),
you must first install an [`mcp-proxy`](../guides/mcp_proxy.md).

Then open up Claude Desktop, go to "Settings" and, under the
"Developer" tab, click on "Edit Config". It will point to a file
you can open in your favorite editor. Which you must edit to
include the following settings:

On macOS/Linux:

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

And you are good to go! Note we enabled filesystem tools by default,
as Claude Desktop does not support any filesystem operation out of the box.
If your application uses a SQL database, you can verify it all works
by asking it to run `SELECT 1` as database query. If it fails,
check out [our MCP Troubleshooting guide](mcp_troubleshooting.md).
