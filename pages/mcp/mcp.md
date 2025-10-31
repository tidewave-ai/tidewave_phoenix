# Setting up Tidewave MCP

You can access some of Tidewave's features from your editor/agent via the Model Context Protocol (MCP).

> #### Tidewave Web features {: .info}
>
> Tidewave MCP includes only a subset of Tidewave's features. In-browser agents, point-and-click prompting, Figma integration, and contextual browser testing are all parts of [Tidewave Web](https://tidewave.ai), and are available under the `/tidewave` route of your application.

## Editor/agent instructions

We have specific instructions for:

  * [Claude Code](mcp_claude_code.md)
  * [Codex](mcp_codex.md)
  * [Cursor](mcp_cursor.md)
  * [Neovim](mcp_neovim.md)
  * [opencode](mcp_opencode.md)
  * [VS Code](mcp_vscode.md)
  * [Windsurf](mcp_windsurf.md)
  * [Zed](mcp_zed.md)

## General instructions

Add the Tidewave MCP server to your editor or MCP client configuration as the type "http" (streamable), pointing to the `/tidewave/mcp` path and port your web application is running at. For example, `http://localhost:4000/tidewave/mcp`.

In case your tool of choice only supports "stdio" servers, you can use our MCP proxy (see below).

## Tips

You may want to nudge your coding agent into using Tidewave MCP's capabilities more frequently by using rules, so you don't need to ask explicitly each time. Each editor places those rules at different locations, so make sure to consult their documentation.

For example, you may want to say:

```txt
Always use Tidewave's tools for evaluating code, querying the database, etc.

Use `get_docs` to access documentation and the `get_source_location` tool to
find module/function definitions.
```

From then on, your coding agent will automatically leverage Tidewave's deep framework integration without you having to explicitly ask. You can customize the rule to match your workflow.

## Available tools

Here is a baseline comparison of the tools supported by different frameworks/languages. Frameworks may support additional features.

| Features                     | Tidewave for Phoenix | Tidewave for Rails |
| :--------------------------- | :------------------: | :----------------: |
| `project_eval`               | ✅                    | ✅                 |
| `get_docs`                   | ✅                    | ✅                 |
| `get_source_location`        | ✅                    | ✅                 |
| `get_logs`                   | ✅                    | ✅                 |
| `get_models` / `get_schemas` | ✅                    | ✅                 |
| `execute_sql_query`          | ✅                    | ✅                 |
| `search_package_docs`        | ✅                    |                   |
