# Setting up Tidewave MCP

You can access some of Tidewave features from your editor via the Model Context Protocol (MCP). We have tailored instructions for some of them:

  * [Claude Code](claude_code.md)
  * [Claude Desktop](claude.md)
  * [Cursor](cursor.md)
  * [Neovim](neovim.md)
  * [opencode](opencode.md)
  * [VS Code](vscode.md)
  * [Windsurf](windsurf.md)
  * [Zed](zed.md)

Tidewave MCP includes only a subset of the features in Tidewave. In-browser agents, point and click prompting, and contextual browser testing are part of [Tidewave Web](https://tidewave.ai) and are available under the `/tidewave` route of your application.

## General instructions

Generally speaking, you need to include Tidewave as MCP of type "http" (for Phoenix) or "sse" (for Rails), pointing to the `/tidewave/mcp` path of port your web application is running on. For example, `http://localhost:4000/tidewave/mcp`.

In case your tool of choice only supports "io" servers, you can use one of the many available [MCP proxies](../guides/mcp_proxy.md).

## Available tools

Here is a baseline comparison of the tools supported by different frameworks/languages. Frameworks may support additional features.

| Features                     | Tidewave for Phoenix | Tidewave for Rails |
| :--------------------------- | :------------------: | :----------------: |
| `project_eval`               | ✅                    | ✅                 |
| `get_docs`                   | ✅                    | ✅                 |
| `get_source_location`        | ✅                    | ✅                 |
| `get_package_location`       | ✅                    | ✅                 |
| `get_logs`                   | ✅                    | ✅                 |
| `get_models` / `get_schemas` | ✅                    | ✅                 |
| `execute_sql_query`          | ✅                    | ✅                 |
| `search_package_docs`        | ✅                    |                   |
