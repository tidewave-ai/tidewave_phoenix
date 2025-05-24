# MCP

You can integrate Tidewave into any editor or AI assistant that supports the Model Context Protocol (MCP). We have tailored instructions for some of them:

  * [Claude Code and Claude Desktop](claude.md)
  * [Cursor](cursor.md)
  * [Neovim](neovim.md)
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
| `package_search`             | ✅                    | ✅                 |
| `package_docs_search`        | ✅                    |                   |
| `get_docs`                   | ✅                    |                   |
| `get_source_location`        | ✅                    | ✅                 |
| `get_package_location`       | ✅                    | ✅                 |
| `get_logs`                   | ✅                    | ✅                 |
| `get_models` / `get_schemas` | ✅                    | ✅                 |
| `execute_sql_query`          | ✅                    | ✅                 |

### Filesystem tools

Our MCP servers may also accept `/tidewave/mcp?include_fs_tools=true` option,
which enables your assistant to run shell commands as well as list, read, write,
edit, and search files. Most editors already provide such tools, and therefore
you must not enable the Tidewave ones, except for assistants like Claude Desktop:

| Features                   | Tidewave for Phoenix | Tidewave for Rails |
| :------------------------- | :------------------: | :----------------: |
| `shell_eval`               | ✅                    | ✅                 |
| `list_project_files`       | ✅                    | ✅                 |
| `read_project_file`        | ✅                    | ✅                 |
| `edit_project_file`        | ✅                    | ✅                 |
| `write_project_file`       | ✅                    | ✅                 |
| `grep_project_files`       | ✅                    | ✅                 |
| Syntax validation          | ✅                    | ✅                 |
| Automatic formatting       | ✅                    |                   |

Tidewave stores the timestamps files have been read and written to, to avoid accidentally
overriding previous work. Writing and editing files may also perform syntax validation and
automatic formatting.
