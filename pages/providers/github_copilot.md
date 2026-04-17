# GitHub Copilot

You can connect Tidewave Web directly to [GitHub Copilot CLI](https://github.com/features/copilot/cli). The [GitHub Copilot subscription](https://github.com/features/copilot) will give you access to models from Anthropic, OpenAI, xAI, and other providers.

Simply open up Tidewave Web settings, choose the Providers tab, choose "GitHub Copilot" and click "Connect". Next we will automatically download and install the Copilot CLI for you. Once connected, we will automatically configure the Copilot CLI to use Tidewave MCP. You may disable this option if (and only if) you have already customized the Copilot CLI to use Tidewave MCP.

You can control which Copilot models are available to Tidewave in [your GitHub Copilot settings](https://github.com/settings/copilot).

> #### Copilot through OpenCode {: .info}
>
> You can also use GitHub Copilot with OpenCode. First connect Tidewave to OpenCode. Once connceted, select "Add models", and then pick GitHub as one of the providers. See [our OpenCode documentation to learn more](opencode.md).

> #### Custom `copilot-cli` installation {: .info}
>
> It is possible to use a custom `copilot` executable by setting the `TIDEWAVE_COPILOT_CLI_EXECUTABLE` environment variable, either in your running web application, or in the Tidewave App/CLI. This is rarely needed in practice but it may be required in some operating systems like NixOS.

> #### Deprecated GitHub Copilot API {: .warn}
>
> Previously, Tidewave supported directly communicating with the "GitHub Copilot API". This has been deprecated in favor of the GitHub Copilot CLI steps documented above.
