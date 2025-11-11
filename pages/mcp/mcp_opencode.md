# Opencode

You can use Tidewave MCP with [opencode](https://opencode.ai/) by adding the following to your opencode config, either:

- Globally, typically in `~/.config/opencode/opencode.json`, or
- Per project, typically in `/path/to/your-project/opencode.json`

by adding the following:

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
