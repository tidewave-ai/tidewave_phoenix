# AGENTS.md

Tidewave looks for a file called `AGENTS.md` in your project's root directory to add context to your chat session. You can use `AGENTS.md` to add useful instructions to the agent's context, such as important project rules, basic project structure, etc.

> #### Third-party coding agents and AGENTS.md {: .info}
>
> If you are using a third-party coding agent, such as OpenAI Codex or Claude Code, the specific details of if and when `AGENTS.md` is read is left up to them.
>
> Luckily, most have adopted `AGENTS.md` as a standard, with Claude Code being a notable exception. Claude Code official documentation [recommends creating a `CLAUDE.md` file and writing `@AGENTS.md` at the top to automatically include it](https://docs.claude.com/en/docs/claude-code/claude-code-on-the-web#best-practices).

Whenever Tidewave is the one responsible for managing your `AGENTS.md` file, it will show a notice at the very top of the active chat about the status of the `AGENTS.md` file. For some frameworks, Tidewave includes a default `AGENTS.md` file that is used if the project does not define one itself (with a link in case you want to copy it into a local `AGENTS.md` file).

![AGENTS.md notice](assets/agentsmd.png)

> #### Changing AGENTS.md {: .info}
>
> Tidewave does not watch for file changes. If you edit your `AGENTS.md` file or create it
> from scratch, you need to reload Tidewave in your browser for the new content to be picked up.
> Third-party coding agents may only pick up changes to `AGENTS.md` on new sessions.