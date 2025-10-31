# Neovim

You can use Tidewave MCP with [Neovim](https://neovim.io/) through the
[MCP Hub extension](https://github.com/ravitemer/mcphub.nvim), and integration
with [Avante](https://github.com/yetone/avante.nvim) or
[CodeCompanion](https://github.com/olimorris/codecompanion.nvim).

With MCP Hub added, create a file at `~/.config/mcphub/servers.json` and add
the following contents.

<!-- tabs-open -->

### HTTP connection

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

### MCP Proxy

See the [MCP proxy documentation](guides/mcp_proxy.md).

On macOS/Linux:

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

<!-- tabs-close -->

And you are good to go! If your application uses SQL database, you can verify
it works by asking CodeCompanion/Avante to run `SELECT 1` as a database query.
If it fails, check out [our MCP Troubleshooting guide](mcp_troubleshooting.md).
