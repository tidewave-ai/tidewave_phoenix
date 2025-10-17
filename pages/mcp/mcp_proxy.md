# Proxy

Tidewave implements the Streamable HTTP transport of the MCP protocol.
Some MCP clients may only support the stdio transport, and so we provide
a proxy. See [the installation instructions on GitHub](https://github.com/tidewave-ai/mcp_proxy_rust#installation).

Once installation concludes, take note of the full path
the `mcp-proxy` was installed at. It will be necessary
in most scenarios in order to use Tidewave. Note on Windows
the executable will also have the `.exe` extension.

The proxy also handles automatic reconnection upon restart of the
dev server, and so we also recommend the proxy in cases where a
native HTTP implementation is available in your MCP client that
does not properly handle reconnection.
