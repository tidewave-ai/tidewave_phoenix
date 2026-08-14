# Neovim

You can connect [Neovim](https://neovim.io/) to Tidewave through the
[MCP Hub extension](https://github.com/ravitemer/mcphub.nvim), and integration
with [Avante](https://github.com/yetone/avante.nvim) or
[CodeCompanion](https://github.com/olimorris/codecompanion.nvim).

## Install

With MCP Hub added, create a file at `~/.config/mcphub/servers.json` and add
the following contents:

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

## Verify

You can verify it all works by starting a new session and asking your agent if
it can see Tidewave's tools.
If it fails, check out [our MCP Troubleshooting section](mcp.md#troubleshooting).
