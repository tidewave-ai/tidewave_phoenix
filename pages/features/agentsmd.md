# AGENTS.md

Tidewave looks for a file called `AGENTS.md` in your project's root directory to add context to your chat session.

You can use `AGENTS.md` to add useful instructions to the agent's context, such as important project rules, basic project structure, etc.

If you already have a `CLAUDE.md`, `.cursor/rules` or similar file for use with other AI tools, you can symlink or copy this file into `AGENTS.md`
for Tidewave to pick it up.

Tidewave Web shows a notice at the very top of the active chat about the status of the `AGENTS.md` file.

> #### Changing AGENTS.md {: .info}
>
> Tidewave does not watch for file changes. If you edit your `AGENTS.md` file or create it
> from scratch, you need to reload Tidewave in your browser for the new content to be picked up.

For some frameworks, Tidewave includes a default `AGENTS.md` file that is used if the project does not define one itself.
If that is the case, the notice includes a link to the default file, which you can then copy into a local `AGENTS.md` file
to make adjustments based on your needs.

![AGENTS.md notice](assets/agentsmd.png)
