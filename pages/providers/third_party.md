# Third-party providers

There are three mechanisms you can extend Tidewave Web beyond the providers listed above.

* [By using OpenCode and adding the models of your choice](opencode.md). OpenCode supports 75+ different providers, including local ones

* [By using Codex with custom providers](codex.md#custom-providers). The Codex CLI can be customized to run with any OpenAI compatible providers, which includes [Ollama](https://ollama.com) and external services

* By using External Agents that implement the [Agent Client Protocol](http://agentclientprotocol.com) (ACP) - you can enable them in the "External Agents" tab under the advanced settings. Given ACP is still evolving, keep in mind Tidewave may not work as expected when using such agents
