# VS Code

You can use Tidewave with Visual Studio Code through the [GitHub Copilot extension](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot).

At the time of writing, MCP support in GitHub Copilot is in public preview and only
available when **a)** the 'Editor Preview Features' flag is enabled in your GitHub
settings and **b)** your Copilot session is in "Agent" mode. Given the preview state
of the feature, the instructions below may be out of date. In any case, let's do this.

Open up your AI assistant and then click on the red arrow in your editor (shown below)
to enable "Agent" mode and then the Wrench icon (pointed by the green arrow) to
configure it.

![VSCode AI panel](assets/vscode.png)

And then at the center top:

1. Choose "+ Add MCP Server..."

2. Choose "HTTP (Server sent events)..."

3. Add the URL your web application is running on with `/tidewave/mcp` at the end, such as `http://localhost:$PORT/tidewave/mcp`, where `$PORT` is the port it is running on

4. Add a name of your choice

And you are good to go! Now the Copilot extension will list all tools from
Tidewave available. If your application uses a SQL database, you can verify
it all works by asking it to run `SELECT 1` as database query.
