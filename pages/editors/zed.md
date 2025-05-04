# Zed

You can use Tidewave with [Zed](https://zed.dev/). At the time of writing,
Zed agents/assistants are in closed beta. If you have access, you can follow
the steps below, although they may not reflect the latest behaviour.

Zed currently only supports MCP through the IO protocol.
So the first step is to install a [mcp-proxy](../guides/mcp_proxy.md).
Once that's done, open up the Assistant tab and click on the `⋯` icon at the
top right (see image below):

![Zed AI panel](assets/zed.png)

In the new pane, select "+ Add Custom Server", to open a new dialog. Fill in
the name of your choice and the command will vary depending to your proxy
of choice:

<!-- tabs-open -->

### Python Proxy

On macos/Linux:

```text
/path/to/mcp-proxy http://localhost:$PORT/tidewave/mcp
```

On Windows:

```text
/path/to/mcp-proxy.exe http://localhost:$PORT/tidewave/mcp
```

Where `$PORT` is the port your web application is running on.

### Elixir Proxy

On macos/Linux:

```text
/path/to/escript $HOME/.mix/escripts/mcp-proxy http://localhost:$PORT/tidewave/mcp
```

On Windows:

```text
escript.exe $HOME/.mix/escripts/mcp-proxy http://localhost:$PORT/tidewave/mcp
```

Where you replace `$HOME` by your home folder (shown during installation)
and `$PORT` by the port your web application is running on.

<!-- tabs-close -->

And you are good to go! Now Zed will list all tools from Tidewave available.
If your application uses a SQL database, you can verify it all works by asking
it to run `SELECT 1` as database query. If it fails, check out
[our Troubleshooting guide](troubleshooting.md). You can also manage your
installation, by clicking on the same `⋯` icon and then on "Settings".
