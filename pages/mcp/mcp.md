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

You may want to nudge your coding agent into using Tidewave MCP's capabilities more frequently by using rules, so you don't need to ask explicitly each time. Each editor places those rules at different locations, so make sure to consult their documentation.

For example, you may want to say:

```txt
Always use Tidewave's tools for evaluating code, querying the database, etc.

Use `get_docs` to access documentation and the `get_source_location` tool to
find module/function definitions.
```

You can customize the rule to match your workflow.

## Tidewave MCP vs Language Server Protocol tools

Some coding agents expose the [Language Server Protocol (LSP)](https://microsoft.github.io/language-server-protocol/) as tools to the agent. How does Tidewave MCP compare to those?

The Language Server Protocol integration does provide benefits, such as the ability to read diagnostics and code actions when reading and editing a file. However, because LSP was designed for IDEs, many of its functionality are centered around FILE+LINE+COLUMN, which often means you cannot get information about a function or method unless your codebase already uses it.

For example, imagine you ask your coding agent to use a function/method available in `some_library`. If `some_library` is not used anywhere in your codebase yet, the coding agent won't be able to read its docs or find its source, because there is no existing FILE+LINE+COLUMN the LSP could be pointed to.

Tidewave MCP addresses this by using the notation of each programming language, which is familiar to developers and agents, to explore your codebase. For example, the Tidewave MCP for Ruby allows the agent to get the source location of any `Namespace::Class#instance_method`, the Tidewave MCP for JavaScript can read the documentation of `react:Component#render` as argument, and so on.

Furthermore, Tidewave MCP was designed to perform runtime analysis, rather than static one. This is especially important in the context of web frameworks where meta-programming is often used to avoid repetitive work. For example, your web framework may automatically define models and properties based on your database tables, which often can't be find statically.

Finally, commands to execute code or capture telemetry information within the runtime, such as `project_eval`, `execute_sql_query`, and `get_logs`, simply do not exist in LSP. In other words, Tidewave MCP is about the runtime intelligence of your applications.

If you want use both, we recommend keeping the existing Tidewave MCP tools, and use LSP for diagnostics and symbol search (`workspaceSymbol` and `findReferences`).

## Troubleshooting

This page contains several steps to help debug issues when integrating Tidewave with an editor or MCP client. There are usually three distinct components to investigate:

* Your web application
* (optional) The [MCP proxy](../guides/mcp_proxy.md)
* Your editor

### Your web application

In case your editor or MCP client cannot connect to the server, you should try querying the `/tidewave/mcp` endpoint directly using a tool such as `curl`. For example:

```
curl -v http://localhost:4000/tidewave/mcp \
--header 'Content-Type: application/json' \
--header "Accept: application/json, text/event-stream" \
--data '{"jsonrpc":"2.0","id":1,"method":"ping"}'
```

You should see something like:

```
* Host localhost:4000 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:4000...
* connect to ::1 port 4000 from ::1 port 50526 failed: Connection refused
*   Trying 127.0.0.1:4000...
* Connected to localhost (127.0.0.1) port 4000
* using HTTP/1.x
> POST /tidewave/mcp HTTP/1.1
> Host: localhost:4000
> User-Agent: curl/8.14.1
> Content-Type: application/json
> Accept: application/json, text/event-stream
> Content-Length: 40
>
* upload completely sent off: 40 bytes
< HTTP/1.1 200 OK
< date: Fri, 22 Aug 2025 22:15:54 GMT
< content-length: 36
< vary: accept-encoding
< cache-control: max-age=0, private, must-revalidate
< content-type: application/json; charset=utf-8
<
* Connection #0 to host localhost left intact
{"id":1,"result":{},"jsonrpc":"2.0"}
```

Things to check for:

* Does `localhost` resolve to an IPv6 address? The example above resolved to IPv4, but if `localhost` resolves to IPv6 for you, check that your web server can accept IPv6 connections. Alternatively, use `http://127.0.0.1:$PORT/tidewave/mcp` as your URL instead of using localhost.

* Do the response headers (the lines starting with `<`) include a "transfer-encoding" that indicates compression? Some web servers may automatically compress responses, which may not be handled correctly by your editor or MCP client. In such cases, you may need to disable compression or use an [MCP proxy](../guides/mcp_proxy.md).

* Are you using Docker or similar? By default, Tidewave and your web server only accept requests coming from localhost. Depending on the bridge mode you use, you need to configure both to allow external connections. (Remember to only expose your Docker ports locally.)

### The MCP proxy

In case connections to your web application is working fine but your editor/MCP client still cannot connect to it, you may consider using a [MCP proxy](../guides/mcp_proxy.md) instead.

If the MCP proxy does not work, here is what you can try to debug it:

  * Can you invoke the proxy directly? For example, what happens if you invoke following command in your terminal?
    ```
    echo '{"jsonrpc":"2.0","id":1,"method":"ping"}' | /path/to/mcp-proxy http://localhost:$PORT/tidewave/mcp
    ```
  * Our Rust proxy accepts a `--debug` parameter, which logs helpful debugging information on stderr.

### Your editor

Your editor and most MCP clients keep logs about their MCP tools. Remember to check those logs and try to find additional information which could help you debug connection issues. In particular, if you are using a proxy and you see "ENOENT" (or "enoent") in your logs, it is because the proxy cannot be found (or the user your running your editor does not have permission to access it).

### Further help

In case it still does not work, here are places you can get help to diagnose it:

* [Our Discord server](https://discord.gg/5GhK7E54yA) - the best place to interact with the community and get help specific to your editor and framework

* Our issues trackers - in case we messed something up, please let us know. Here are the specific repositories:
  * [Tidewave for JavaScript](https://github.com/tidewave-ai/tidewave_js/issues)
  * [Tidewave for Phoenix](https://github.com/tidewave-ai/tidewave_phoenix/issues)
  * [Tidewave for Python](https://github.com/tidewave-ai/tidewave_python/issues)
  * [Tidewave for Rails](https://github.com/tidewave-ai/tidewave_rails/issues)
