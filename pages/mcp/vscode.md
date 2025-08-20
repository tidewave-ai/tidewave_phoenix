# VS Code

You can use Tidewave with Visual Studio Code through the [GitHub Copilot extension](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot).

> #### Public preview required {: .warning}
>
> At the time of writing, MCP support in GitHub Copilot is in public preview and only
available when **a)** the "Editor Preview Features" flag is enabled in your GitHub
settings and **b)** your Copilot session is in "Agent" mode. Given the preview state of the feature, the instructions below may be out of date.

> #### Organization settings {: .warning}
>
> When using GitHub Copilot within your organization, administrators may disable usage of some (or all) MCP Servers. In such cases, configuring Tidewave (and other MCPs) in your IDE will be grayed out. Reach out to your organization administrator for further information.

Open up your AI assistant and then click on the red arrow in your editor (shown below)
to enable "Agent" mode and then the Wrench icon (pointed by the green arrow) to
configure it.

![VSCode AI panel](assets/vscode.png)

And then at the center top choose "+ Add MCP Server..." and follow one of the options below:

<!-- tabs-open -->

### MCP Proxy (recommended)

See the [MCP proxy documentation](guides/mcp_proxy.md).

1. Choose "Command (stdio)"

2. List the path to the mcp-proxy followed by the URL your web application is running on with `/tidewave/mcp` at the end, such as `/path/to/mcp-proxy http://localhost:$PORT/tidewave/mcp` on macOS/Linux or `c:\path\to\mcp-proxy.exe http://localhost:$PORT/tidewave/mcp` on Windows, where `$PORT` is the port it is running on

3. Add a name of your choice

### HTTP/SSE connection

1. Choose "HTTP (HTTP or Server-Sent events)"

2. Add the URL your web application is running on with `/tidewave/mcp` at the end, such as `http://localhost:$PORT/tidewave/mcp`, where `$PORT` is the port it is running on

3. Add a name of your choice

<!-- tabs-close -->

And you are good to go! Now the Copilot extension will list all tools from
Tidewave available. If your application uses a SQL database, you can verify
it all works by asking it to run `SELECT 1` as database query.
If it fails, check out [our MCP Troubleshooting guide](mcp_troubleshooting.md).
