# Setting up Tidewave MCP

You can access some of Tidewave's features from your editor/agent via the Model Context Protocol (MCP). Our MCP integrates your coding agent directly with your framework runtime, allowing it to access logs, query the database, and run code within the context of your app.

> #### Tidewave Web features {: .info}
>
> Tidewave MCP includes only a subset of Tidewave's features. In-browser agents, point-and-click prompting, Figma integration, and more are all parts of [Tidewave Web](https://tidewave.ai). Furthermore, if you are using Tidewave Web, you don't need to configure the Tidewave MCP. That's done automatically for you.

## Editor/agent instructions

Add the Tidewave MCP server to your editor or MCP client configuration as the type "http" (streamable), pointing to the `/tidewave/mcp` path and port your web application is running at. For example, `http://localhost:4000/tidewave/mcp`.

We also have specific instructions for:

  * [Claude Code](mcp_claude_code.md)
  * [Codex](mcp_codex.md)
  * [Cursor](mcp_cursor.md)
  * [Neovim](mcp_neovim.md)
  * [opencode](mcp_opencode.md)
  * [VS Code](mcp_vscode.md)
  * [Windsurf](mcp_windsurf.md)
  * [Zed](mcp_zed.md)

## Available tools

Here is a baseline comparison of the tools supported by different frameworks/languages.

| Features                     | Django | FastAPI | Flask | Next.js | Phoenix | Rails | TanStack Start |
| :--------------------------- | :----: | :-----: | :---: | :-----: | :-----: | :---: | :------------: |
| `project_eval`               | ✅     | ✅      | ✅    | ✅      | ✅      | ✅    | ✅             |
| `get_docs`                   | ✅     | ✅      | ✅    | ✅      | ✅      | ✅    | ✅             |
| `get_source_location`        | ✅     | ✅      | ✅    | ✅      | ✅      | ✅    | ✅             |
| `get_logs`                   | ✅     | ✅      | ✅    | ✅      | ✅      | ✅    | ✅             |
| `get_models` / `get_schemas` | ✅     | ✅      | ✅    |         | ✅      | ✅    |                |
| `execute_sql_query`          | ✅     | ✅      | ✅    |         | ✅      | ✅    |                |
| `search_package_docs`        |        |         |       |         | ✅      |       |                |

## Tips

You may want to nudge your coding agent into using Tidewave MCP's capabilities more frequently by using rules, so you don't need to ask explicitly each time. Each editor places those rules at different locations, so make sure to consult their documentation.

For example, you may want to say:

```txt
Always use Tidewave's tools for evaluating code, querying the database, etc.

Use `get_docs` to access documentation and the `get_source_location` tool to
find module/function definitions.
```

From then on, your coding agent will automatically leverage Tidewave's deep framework integration without you having to explicitly ask. You can customize the rule to match your workflow.

## Tidewave MCP vs Language Server Protocol tools

Some coding agents expose the [Language Server Protocol (LSP)](https://microsoft.github.io/language-server-protocol/) as tools to the agent. How does Tidewave MCP compare to those?

The Language Server Protocol integration does provide benefits, such as the ability to read diagnostics and code actions when reading and editing a file. However, because LSP was designed for IDEs, many of its functionality are centered around FILE+LINE+COLUMN, which often means you cannot get information about a function or method unless your codebase already uses it.

For example, imagine you ask your coding agent to use a function/method available in `some_library`. If `some_library` is not used anywhere in your codebase yet, the coding agent won't be able to read its docs or find its source, because there is no existing FILE+LINE+COLUMN the LSP could be pointed to.

Tidewave MCP addresses this by using the notation of each programming language, which is familiar to developers and agents, to explore your codebase. For example, the Tidewave MCP for Ruby allows the agent to get the source location of any `Namespace::Class#instance_method`, the Tidewave MCP for JavaScript can read the documentation of `react:Component#render` as argument, and so on.

Furthermore, Tidewave MCP was designed to perform runtime analysis, rather than static one. This is especially important in the context of web frameworks where meta-programming is often used to avoid repetitive work. For example, your web framework may automatically define models and properties based on your database tables, which often can't be find statically.

Finally, commands to execute code or capture telemetry information within the runtime, such as `project_eval`, `execute_sql_query`, and `get_logs`, simply do not exist in LSP. In other words, Tidewave MCP is about the runtime intelligence of your applications.

If you want use both, we recommend keeping the existing Tidewave MCP tools, and use LSP for diagnostics and symbol search (`workspaceSymbol` and `findReferences`).
