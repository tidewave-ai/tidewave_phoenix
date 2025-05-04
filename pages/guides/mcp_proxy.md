# MCP proxy

Tidewave implements the SSE version of MCP protocol. Some tools may only support the IO
protocol but proxies are available in different languages. Pick whatever language is more
suitable to you.

## Python-based proxy

Requires either `uv`, `npm`, or `pip` installed. See [the
installation instructions on GitHub](https://github.com/sparfenyuk/mcp-proxy#installation).

Once installation concludes, take note of the full path
the `mcp-proxy` was installed at. It will be necessary
in most scenarios in order to use Tidewave. Note on Windows
the executable will also have the `.exe` extension.

## Elixir-based proxy

Requires Elixir installed on your machine. Then simply run:

```bash
$ mix escript.install hex mcp_proxy
```

The proxy will be installed at `~/.mix/escripts/mcp-proxy`.

In order to use it with Tidewave, you will need to run this
command on Windows:

``` shell
$ escript.exe c:\$HOME\.mix\escripts\mcp-proxy http://localhost:$PORT/tidewave/mcp
```

And on Unix, you will need to know the path to the `escript`
executable by running `which escript`. Then you run it as:

``` shell
$ /path/to/escript $HOME/.mix/escripts/mcp-proxy http://localhost:$PORT/tidewave/mcp
```

Where you replace `$HOME` by your home folder (shown during installation)
and `$PORT` by the port your web application is running on.
