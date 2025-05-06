# Troubleshooting

This page contains several steps to help debug issues when integrating Tidewave with an editor or MCP client. There are usually three distinct components to investigate:

* Your web application
* (optional, but recommended) The [MCP proxy](../guides/mcp_proxy.md)
* Your editor

## Your web application

In case your editor/MCP client cannot connect to the server, you should try querying the `/tidewave/mcp` endpoint directly using a tool such as `curl`. For example, if your web server is running on port `4000`, you should see something similar to below:

```
$ curl -v http://localhost:4000/tidewave/mcp
* Host localhost:4000 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:4000...
* connect to ::1 port 4000 from ::1 port 50526 failed: Connection refused
*   Trying 127.0.0.1:4000...
* Connected to localhost (127.0.0.1) port 4000
> GET /tidewave/mcp HTTP/1.1
> Host: localhost:4000
> User-Agent: curl/8.7.1
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 200 OK
< transfer-encoding: chunked
< date: Sat, 03 May 2025 06:57:49 GMT
< vary: accept-encoding
< cache-control: no-cache
< connection: keep-alive
< content-type: text/event-stream; charset=utf-8
<
event: endpoint
data: http://localhost:4000/tidewave/mcp/message?sessionId=734c52c4-8aec8eb7-2f3dc8c0
```

In particular, you want to check that:

* The last two lines of the response including `event: endpoint` with a data payload

* Does `localhost` resolve to an IPv4 or IPv6 address? The example above resolved to IPv4 but, if yours resolved to IPv6, you need to make sure your web server can accept IPv6 connections. Alternatively, use `http://127.0.0.1:$PORT/tidewave/mcp` as your URL instead of using localhost

* Does the response (the parts starting with `<`) have a "transfer-encoding" (or "Transfer-Encoding") header? Some web servers may automatically compress responses, which may not be handled correctly by all editors or MCP clients. In such cases, you may want to disable compression or use a [MCP proxy](../guides/mcp_proxy.md)

* Are you using Docker or similar? By default, Tidewave and your web server only accept requests coming from localhost. Depending on the bridge mode you use, you need to configure both to allow external connections (but then remember to only expose your Docker ports locally)

## The MCP proxy

In case connections to your web application is working fine but your editor/MCP client still cannot connect to it, you may consider using a [MCP proxy](../guides/mcp_proxy.md) instead.

If the MCP proxy does not work, here is what you can try to debug it:

  * Can you invoke the proxy directly? For example, what happens if you invoke `echo '{"jsonrpc":"2.0","id":1,"method":"ping"}' | /path/to/mcp-proxy` in your terminal?
  * Our Rust proxy accepts a `--debug` parameter, which logs helpful debugging information on stderr.

## Your editor

Your editor and most MCP clients keep logs about their MCP tools. Remember to check those logs and try to find additional information which could help you debug connection issues. In particular, if you are using a proxy and you see "ENOENT" (or "enoent") in your logs, it is because the proxy cannot be found (or the user your running your editor does not have permission to access it).

## Further help

In case it still does not work, here are places you can get help to diagnose it:

* [Our Discord server](https://discord.gg/5GhK7E54yA) - the best place to interact with the community and get help specific to your editor and framework

* Our issues trackers - in case we messed something up, please let us know. Here are framework specific links:
  * [Tidewave for Phoenix](https://github.com/tidewave-ai/tidewave_phoenix/issues)
  * [Tidewave for Rails](https://github.com/tidewave-ai/tidewave_rails/issues)