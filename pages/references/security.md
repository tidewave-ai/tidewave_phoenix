# Security

Tidewave is a development tool and it must not be enabled in production. In a nutshell, you must treat it as any other developer tool, such as web console, REPLs, and similar that you may enable during development.

The installation steps for each framework will guide you towards the best security practices. This guide covers the overall security checks performed by Tidewave and risks you must consider when using it.

## Server exposure

The Tidewave package runs within your web application and exposes features such as the Tidewave MCP which allows coding agents to control and learn more about your web application. To ensure only your coding agent has access to these tools, we have put the following security measures in place:

  * **Localhost binding** - Tidewave allows only localhost access by default.
    Furthermore, most web frameworks restrict your web application in development
    to only be accessible from your own machine, adding one additional layer of protection

  * **Remote IP checks** - In case your web framework enables remote access,
    Tidewave still verifies all incoming requests belong to the current
    machine by verifying the connection's remote IP.

  * **Origin checks** - Tidewave also verifies that the request's "origin"
    header matches your development URL. The Tidewave MCP itself refuses
    any request with an Origin header (unless they have a signed token),
    making it impossible for custom websites to hijack Tidewave

Overall, Tidewave only allows local access, keeping it constrained to your
development environment. More importantly, the Tidewave package is open-source,
so you can audit the code accordingly. Please reach out if you have concerns.

## Tool execution

Tidewave enhances coding agents by allowing them to perform the same project tasks
as you, such as reading, writing, and executing code. Commands that execute code
may perform any action on your machine and therefore must be assessed with care
(as with most tool calls performed by your agent).

Because Tidewave runs within your web application, if you run your web app within
Docker or [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers),
then all of Tidewave's actions will also happen within the container, giving you one
additional level of security. If you are using the Tidewave IDE, you can also run it
inside [containers](../ide/containers.md).

## Data collection

Tidewave logs basic request metadata (timestamps, feature used, etc). Prompts are not logged unless you explicitly opt in.

Tidewave IDE logs basic request metadata (timestamps, model used, token counts). Prompts and messages are not logged unless you explicitly opt in. We don't receive, process, or store tool call results. Note the underlying coding agent may store data separately depending on your user agreement with them, that's outside of Tidewave's control.

See our [Terms of Service](https://tidewave.ai/terms) and [Privacy Policy](https://tidewave.ai/privacy).
