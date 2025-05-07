# MCP proxy

Tidewave implements the SSE version of MCP protocol. Some tools may only support the IO
protocol but we provide a proxy that also handles automatic reconnects when your restart
your dev server. Therefore, we also recommend the proxy in cases where a native SSE implementation
is available, but doesn't handle reconnecting properly.

## Rust-based proxy

Provides a single binary executable. See [the
installation instructions on GitHub](https://github.com/tidewave-ai/mcp_proxy_rust#installation).

Once installation concludes, take note of the full path
the `mcp-proxy` was installed at. It will be necessary
in most scenarios in order to use Tidewave. Note on Windows
the executable will also have the `.exe` extension.

## Other proxies

There are also other proxies available, for example [an implementation in Python](https://github.com/sparfenyuk/mcp-proxy),
but it did not handle reconnects last time we tried. The Rust proxy is also simpler to install.

We also provided an [Elixir based proxy](https://github.com/tidewave-ai/mcp_proxy_elixir) in the past,
but it is now deprecated as the Rust proxy is simpler to install (as it does not require Elixir).
