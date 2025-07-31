# Adding MCP Server to Kiro Editor

1. Open the Kiro application
2. Navigate to the `Kiro` tab in the top menu
3. Find the `MCP servers` section and click the pencil icon to edit
4. In the editor that appears, enter the following configuration:
```json
{
  "mcpServers": {
    "tidewave": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "http://localhost:$PORT/tidewave/mcp",
        "--transport",
        "sse"
      ],      
      "disabled": false,
      "autoApprove": []
    }
  }
}
```
