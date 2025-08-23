# Proxy

Tidewave implements the HTTP transports of the MCP protocol: Streamable HTTP
for Phoenix and HTTP+SSE for Ruby on Rails. Some MCP clients may only support
the stdio transport, and so we provide a proxy.

The proxy handles automatic reconnection upon restart of the dev server, and
so we also recommend the proxy in cases where a native HTTP implementation is
available in your MCP client that does not properly handle reconnection.

## Rust-based proxy

Provides a single binary executable. See [the
installation instructions on GitHub](https://github.com/tidewave-ai/mcp_proxy_rust#installation).

Once installation concludes, take note of the full path
the `mcp-proxy` was installed at. It will be necessary
in most scenarios in order to use Tidewave. Note on Windows
the executable will also have the `.exe` extension.

## Python-based proxy

An alternative MCP Proxy if the Rust version is not working as expected.
Requires Python tooling on your machine. See [the installation instructions
on GitHub](https://github.com/sparfenyuk/mcp-proxy).

Once installation concludes, take note of the full path
the `mcp-proxy` was installed at. It will be necessary
in most scenarios in order to use Tidewave. Note on Windows
the executable will also have the `.exe` extension.
