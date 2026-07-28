# VS Code

You can connect Visual Studio Code to Tidewave through the [GitHub Copilot extension](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot).

## Install

> #### Organization settings {: .warning}
>
> When using GitHub Copilot within your organization, administrators may disable usage of some (or all) MCP Servers. In such cases, configuring Tidewave (and other MCPs) in your IDE will be grayed out. Reach out to your organization administrator for further information.

Open up your AI assistant and then click on the red arrow in your editor (shown below)
to enable "Agent" mode and then the Wrench icon (pointed by the green arrow) to
configure it.

![VSCode AI panel](assets/vscode.png)

And then at the center top choose "+ Add MCP Server..." and follow these steps:

1. Choose "HTTP (HTTP or Server-Sent events)"

2. Add the URL your web application is running on with `/tidewave/mcp` at the end, such as `http://localhost:$PORT/tidewave/mcp`, where `$PORT` is the port it is running on

3. Add a name of your choice

## Verify

You can verify it all works by starting a new session and asking your agent if
it can see Tidewave's tools.
If it fails, check out [our MCP Troubleshooting section](mcp.md#troubleshooting).
