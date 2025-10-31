# Opencode

You can use Tidewave MCP with [opencode](https://opencode.ai/) by adding the following to your opencode config, either:

- Globally, typically in `~/.config/opencode/opencode.json`, or
- Per project, typically in `/path/to/your-project/opencode.json`

<!-- tabs-open -->

### HTTP connection

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

Where `$PORT` is the port your web application is running on.

### MCP Proxy

See the [MCP proxy documentation](guides/mcp_proxy.md).

On macOS/Linux:

```json
{
  "mcp": {
    "tidewave": {
      "type": "local",
      "command": ["/path/to/mcp-proxy", "http://localhost:$PORT/tidewave/mcp"],
      "enabled": true
    }
  }
}
```

On Windows:

```json
{
  "mcp": {
    "tidewave": {
      "type": "local",
      "command": ["/path/to/mcp-proxy.exe", "http://localhost:$PORT/tidewave/mcp"],
      "enabled": true
    }
  }
}
```

Where `$PORT` is the port your web application is running on.

<!-- tabs-close -->
