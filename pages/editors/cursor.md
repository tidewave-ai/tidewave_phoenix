# Cursor

You can use Tidewave with [Cursor](https://cursor.com/).

Cursor allows you to place a file at `.cursor/mcp.json`, for configuration
which is specific to your project. Given Tidewave is explicitly tied to your
web application, that's our preferred approach.

> #### Installing an MCP proxy {: .info}
> The SSE integration of Cursor has shown to be unreliable. Whenever the connection
> drops to the SSE server, for example when you restart your dev server, Cursor does
> not properly reconnect, leading to a frustrating user experience. For this reason,
> we highly recommend to use an [MCP proxy](../guides/mcp_proxy.md), despite the built
> in SSE support.

Create a file at `.cursor/mcp.json` and add the following contents.

<!-- tabs-open -->

### Python Proxy

On macos/Linux:

```json
{
  "mcpServers": {
    "tidewave": {
      "command": "/path/to/mcp-proxy",
      "args": [
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
      "command": "/path/to/mcp-proxy.exe",
      "args": [
        "http://localhost:$PORT/tidewave/mcp"
      ]
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
      "command": "/path/to/escript.exe",
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

### Direct Connect

Note: as mentioned above, we do not recommend this approach!

```json
{
  "mcpServers": {
    "tidewave": {
      "url": "http://localhost:$PORT/tidewave/mcp"
    }
  }
}
```

Where `$PORT` is the port your web application is running on. If the `mcp-proxy` command

<!-- tabs-close -->

If you prefer, you can also add Tidewave globally to your editor
by adding the same contents as above to the `~/.cursor/mcp.json`
file. If you have trouble locating such file, open up Cursor's
assistant tab and click on the `⋯` icon on the top right and
choose "Chat Settings". In the new window that opens, you can
click "MCP" on the sidebar and follow the steps there.

If your application uses a SQL database, you can verify it all works
by asking it to run `SELECT 1` as database query.
If you have any questions, check out [Cursor official docs](https://docs.cursor.com/context/model-context-protocol).
