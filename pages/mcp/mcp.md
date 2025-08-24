# Setting up Tidewave MCP

You can access some of Tidewave's features from your editor/agent via the Model Context Protocol (MCP).

> #### Tidewave Web features {: .info}
>
> Tidewave MCP includes only a subset of Tidewave's features. In-browser agents, point-and-click prompting and contextual browser testing are all parts of [Tidewave Web](https://tidewave.ai), and are available under the `/tidewave` route of your application.

## Editor/agent instructions

We have specific instructions for:

  * [Claude Code](claude_code.md)
  * [Cursor](cursor.md)
  * [Neovim](neovim.md)
  * [opencode](opencode.md)
  * [VS Code](vscode.md)
  * [Windsurf](windsurf.md)
  * [Zed](zed.md)

## General instructions

Add the Tidewave MCP server to your editor or MCP client configuration as the type "http" (streamable) for Phoenix or "sse" for Rails, pointing to the `/tidewave/mcp` path and port your web application is running at. For example, `http://localhost:4000/tidewave/mcp`.

If your MCP client has an option to use the Streamable HTTP transport, enable it.

In case your tool of choice only supports "stdio" servers, you can use one of the many available [MCP proxies](../guides/mcp_proxy.md).

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
