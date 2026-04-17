# OpenCode

You can connect Tidewave Web directly to [OpenCode](https://opencode.ai). 

Simply open up Tidewave Web settings, choose the Providers tab, choose "OpenCode" and click "Connect". Next we will automatically download and install OpenCode for you.

Once connected, we will automatically configure OpenCode to also use Tidewave MCP. You may disable this option if (and only if) you have already customized OpenCode to use Tidewave MCP.

> #### Custom `opencode` installation {: .info}
>
> It is possible to use a custom `opencode` executable by setting the `TIDEWAVE_OPENCODE_EXECUTABLE` environment variable, either in your running web application, or in the Tidewave App/CLI. This is rarely needed in practice but it may be required in some operating systems like NixOS.

## Adding models

OpenCode supports [+75 different providers](https://opencode.ai/docs/providers/), including GitHub Copilot subscriptions, OpenRouter, and Moonshot AI.

You can add new models directly from Tidewave Web, by clicking the "Add models" button inside the Provider settings:

![Adding models to OpenCode](assets/opencode.png)
