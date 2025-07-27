# MCP

You can integrate Tidewave into any editor or AI assistant that supports the Model Context Protocol (MCP). We have tailored instructions for some of them:

  * [Claude Code](claude.md)
  * [Claude Desktop](claude_code.md)
  * [Cursor](cursor.md)
  * [Neovim](neovim.md)
  * [opencode](opencode.md)
  * [VS Code](vscode.md)
  * [Windsurf](windsurf.md)
  * [Zed](zed.md)

## General instructions

For any other editor/assistant, you need to include Tidewave as MCP of type "sse", pointing to the `/tidewave/mcp` path of port your web application is running on. For example, `http://localhost:4000/tidewave/mcp`.

In case your tool of choice does not support "sse" servers, only "io" ones, you can use one of the many available [MCP proxies](../guides/mcp_proxy.md).

## Available tools

Here is a baseline comparison of the tools supported by different frameworks/languages. Frameworks may support additional features.

### Runtime intelligence

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

### Filesystem tools

Our MCP servers may also accept `/tidewave/mcp?include_fs_tools=true` option,
which enables your assistant to run shell commands as well as list, read and write
files. Writing and editing files may also perform syntax validation and automatic
formatting.

Most editors and CLI tools already provide this functionality which are better
integrated into their specific environments. The ones below are kept minimal
and mentioned here for documentation purposes:

| Features                   | Tidewave for Phoenix | Tidewave for Rails |
| :------------------------- | :------------------: | :----------------: |
| `shell_eval`               | ✅                    | ✅                 |
| `read_project_file`        | ✅                    | ✅                 |
| `write_project_file`       | ✅                    | ✅                 |
| Syntax validation          | ✅                    | ✅                 |
| Automatic formatting       | ✅                    |                   |
