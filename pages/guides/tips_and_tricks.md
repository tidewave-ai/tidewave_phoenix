# Tips and tricks

Some tips and tricks to use Tidewave effectively.

## Be specific

AI assistants are not very different from working with your teammates.
If you give specific instructions, it is more likely they will deliver
exactly what you asked. However, if you are vague, they may try things
completely different from what you had in mind, sometimes surprising you,
othertimes leading to work that will have to be discarded.

## Short chats

In general, you should keep your chats (also known as conversations/threads)
short.

Once the context window becomes too large, models may become imprecise,
forget previous instructions, or start running into loops. Furthermore,
once a model does something wrong, its mistakes remain in the prompt,
and trying to coax them to fix it often leads them to repeat those mistakes
in a loop, leading to increasing token/message consumption.

Keeping chats short help address those problems. Tidewave will
include more functionality in the future to help you manage your chats
and their context.

## Configure your prompts

Tidewave allows you to write an AGENTS.md file that is given as context
to models. We have [a dedicated page to this feature](agentsmd.md),
where you can learn more.

Such files can also be used to prompt Tidewave to use certain tools
above others, so you can steer them towards using your favorite
Tidewave tools more frequently.

## Use eval: AI's swiss army knife

Tidewave can evaluate code within your project (using the `project_eval` tool),
as well as execute commands in the terminal (using `shell_eval`). Therefore,
you can ask Tidewave to execute complex tasks without a need for additional
tooling. With Tidewave, you can:

  * evaluate code within the project context
  * execute commands in the terminal
  * run SQL queries directly on your development database

This direct integration streamlines your workflow and keeps everything within
your existing development environment. For example, you no longer need to use
a separate tool to connect to your database, you can either execute SQL queries
directly or ask the agent to use your models and data schemas to load the data
in a more structured format. In this case, remember to be precise and don't shy
away from telling the exact tool it should use.

Similarly, any API that your application talks to is automatically available
to Tidewave, which can then leverage your established authentication methods
and access patterns without requiring you to set up and maintain additional
development keys.

If you find yourself needing to automate workflows, you can implement those
as regular functions in your codebase and ask the agent to use them, by
explicitly telling Tidewave to "use `project_eval` to invoke function
`Foo.Bar.baz`". This means extending Tidewave is simply a matter of adding
new functions/methods to your codebase, like any other code you write, and
informing Tidewave where this functionality is defined.

In our experience, models become less effective when there are too many
tools, and work best with a few powerful ones. With our eval tools, Tidewave
has the full power of your programming language within the context of your
project.

## Plan and think ahead

Different models will require different techniques to produce the best
results but the majority of them will output better code if you ask them
to plan ahead.

In particular, thinking models can be prompted into thinking, at different
effort levels, by simply asking them to. For example, Claude says:

> We recommend using the word "think" to trigger extended thinking mode,
> which gives Claude additional computation time to evaluate alternatives
> more thoroughly. These specific phrases are mapped directly to increasing
> levels of thinking budget in the system: "think" < "think hard" <
> "think harder" < "ultrathink." Each level allocates progressively more
> thinking budget for Claude to use.

- https://www.anthropic.com/engineering/claude-code-best-practices