# Zed

You can use Tidewave with [Zed](https://zed.dev/). First, you must
install a [`mcp-proxy`](../guides/mcp_proxy.md).

Once that's done, open up the Assistant tab and click on the `⋯` icon at the
top right (see image below):

![Zed AI panel](assets/zed.png)

In the new pane, select "Add Custom Server" to open a new dialog. Fill in with the following.

On macOS/Linux:

```text
{
  "tidewave-mcp": {
    "command": "/path/to/mcp-proxy",
    "args": ["--transport", "streamablehttp", "http://localhost:$PORT/tidewave/mcp"],
    "env": {}
  }
}
```

On Windows:

```text
{
  "tidewave-mcp": {
    "command": "c:\path\to\mcp-proxy.exe",
    "args": ["http://localhost:$PORT/tidewave/mcp"],
    "env": {}
  }
}
```

Where `$PORT` is the port your web application is running on and `/path/to/mcp-proxy` should be replaced with the absolute path to your mcp-proxy executable.

And you are good to go! Now Zed will list all tools from Tidewave available.
If your application uses a SQL database, you can verify it all works by asking
it to run `SELECT 1` as database query. If it fails, check out
[our MCP Troubleshooting guide](mcp_troubleshooting.md). You can also manage your
installation, by clicking on the same `⋯` icon and then on "Settings".
