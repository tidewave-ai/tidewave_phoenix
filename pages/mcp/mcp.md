# Set up Tidewave MCP

For your coding agent (or editor) to access some of Tidewave's features, they must be configured to use Tidewave MCP. Tidewave MCP runs inside your web app, so it is a matter of connecting your coding agent (or editor) to your web app.

## Instructions

Add the Tidewave MCP server to your editor or MCP client configuration as the type "http" (streamable), pointing to the `/tidewave/mcp` path and port your web application is running at. For example, `http://localhost:4000/tidewave/mcp`.

We also have specific instructions for:

  * [Claude Code](mcp_claude_code.md)
  * [Codex](mcp_codex.md)
  * [Cursor](mcp_cursor.md)
  * [Neovim](mcp_neovim.md)
  * [opencode](mcp_opencode.md)
  * [VS Code](mcp_vscode.md)

## Available tools

Here is a baseline comparison of the tools supported by different frameworks/languages.

| Features                     | Phoenix | Rails | Vite / TanStack Start |
| :--------------------------- | :-----: | :---: | :-------------------: |
| `browser_eval`               | ✅      | Soon™ | Soon™                 |
| `project_eval`               | ✅      | ✅    | ✅                    |
| `get_docs`                   | ✅      | ✅    | ✅                    |
| `get_source_location`        | ✅      | ✅    | ✅                    |
| `get_logs`                   | ✅      | ✅    | ✅                    |
| `get_models` / `get_schemas` | ✅      | ✅    |                       |
| `execute_sql_query`          | ✅      | ✅    |                       |

You may want to nudge your coding agent into using Tidewave MCP's capabilities more frequently by using rules, so you don't need to ask explicitly each time. Each editor places those rules at different locations, so make sure to consult their documentation.

For example, you may want to say:

```txt
Always use Tidewave's tools for evaluating code, querying the database, etc.

Use `get_docs` to access documentation and the `get_source_location` tool to
find module/function definitions.
```

You can customize the rule to match your workflow.

> #### Exclude browser tools {: .info}
>
> By default, the Tidewave MCP will include browser tools, such `browser_eval`.
> If you don't plan to use browser tools, you can set your MCP URL to
> `/tidewave/mcp?include_browser_tools=false`.

## Troubleshooting

This page contains several steps to help debug issues when integrating Tidewave with an editor or MCP client. There are usually three distinct components to investigate:

* Your web application
* Your agent/editor

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

* Do the response headers (the lines starting with `<`) include a "transfer-encoding" that indicates compression? Some web servers may automatically compress responses, which may not be handled correctly by your editor or MCP client. In such cases, you may need to disable compression or use an MCP proxy.

* Are you using Docker or similar? By default, Tidewave and your web server only accept requests coming from localhost. Depending on the bridge mode you use, you need to configure both to allow external connections. (Remember to only expose your Docker ports locally.)

### Your agent/editor

Your editor and most MCP clients keep logs about their MCP tools. Remember to check those logs and try to find additional information which could help you debug connection issues. In particular, if you are using a proxy and you see "ENOENT" (or "enoent") in your logs, it is because the proxy cannot be found or you do not have permission to access it.

### Further help

In case it still does not work, here are places you can get help to diagnose it:

* [Our Discord server](https://discord.gg/5GhK7E54yA) - the best place to interact with the community and get help specific to your editor and framework

* Our issues trackers - in case we messed something up, please let us know. Here are the specific repositories:
  * [Tidewave for JavaScript](https://github.com/tidewave-ai/tidewave_js/issues)
  * [Tidewave for Phoenix](https://github.com/tidewave-ai/tidewave_phoenix/issues)
  * [Tidewave for Rails](https://github.com/tidewave-ai/tidewave_rails/issues)
