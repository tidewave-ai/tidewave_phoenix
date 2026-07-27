# OpenCode

You can connect [OpenCode](https://opencode.ai/) to Tidewave via its MCP configuration, either:

## Install

- Globally, typically in `~/.config/opencode/opencode.json`, or
- Per project, typically in `/path/to/your-project/opencode.json`

Add the following:

```json
{
  "mcp": {
    "tidewave": {
      "type": "remote",
      "url": "http://localhost:$PORT/tidewave/mcp",
      "enabled": true
    }
  }
}
```

Replace `$PORT` by the port your web application is running on.

## Verify

You can verify it all works by starting a new session and asking your agent if
it can see Tidewave's tools.
If it fails, check out [our MCP Troubleshooting section](mcp.md#troubleshooting).
