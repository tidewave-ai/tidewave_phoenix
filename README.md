# Tidewave

Tidewave speeds up development with an AI assistant that understands your web application,
how it runs, and what it delivers. Our current release connects your editor's
assistant to your web framework runtime via [MCP](https://modelcontextprotocol.io/).

[See our website](https://tidewave.ai) for more information.

## Key Features

Tidewave provides tools that allow your LLM of choice to:

- get documentation
- inspect your application logs to help debugging errors
- inspect and trace processes
- execute SQL queries and inspect your database
- evaluate custom Elixir code in the context of your project
- find Hex packages and search your dependencies

and more.

## Installation

### Manually

You can install Tidewave by adding the `tidewave` package to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tidewave, "~> 0.1", only: :dev}
  ]
end
```

Then, for Phoenix applications, go to your `lib/my_app_web/endpoint.ex` and right above the `if code_reloading? do` block, add:

```diff
+  if Code.ensure_loaded?(Tidewave) do
+    plug Tidewave
+  end

   if code_reloading? do
```

Tidewave will now run on the same port as your regular Phoenix application.
In particular, the MCP is located by default at http://localhost:4000/tidewave/mcp.
[You must configure your editor and AI assistants accordingly](https://hexdocs.pm/tidewave/mcp.html).

### Using Igniter

Alternatively, you can use `igniter` to automatically install it into an existing Phoenix application:

```sh
# install igniter_new if you haven't already
mix archive.install hex igniter_new

# install tidewave
mix igniter.install tidewave
```

Tidewave will now run on the same port as your regular Phoenix application.
In particular, the MCP is located by default at http://localhost:4000/tidewave/mcp.
[You must configure your editor and AI assistants accordingly](https://hexdocs.pm/tidewave/mcp.html).

## Configuration

You may configure the `Tidewave` plug using the following syntax:

```elixir
  plug Tidewave, options
```

The following options are available:

  * `:allowed_origins` - if using the MCP from a browser, this can be a list of values matched against the `Origin` header to prevent cross origin and DNS rebinding attacks. When using Phoenix, this defaults to the `Endpoint`'s URL.

  * `:allow_remote_access` - Tidewave only allows requests from localhost by default, even if your server listens on other interfaces as well. If you trust your network and need to access Tidewave from a different machine, this configuration can be set to `true`.

  * `:autoformat` - When writing Elixir source files, Tidewave will automatically format them with `mix format` by default. Setting this option to `false` disabled autoformatting.

  * `:inspect_opts` - Custom options passed to `Kernel.inspect/2` when formatting some tool results. Defaults to: `[charlists: :as_lists, limit: 50, pretty: true]`

  * `:tools` - Configuration for the tools that are included/excluded from the MCP server.

    * `:include` - A list of tools to be included in the MCP. Defaults to `nil`, meaning all tools are included.

    * `:exclude` - A list of tools to be excluded from the MCP. Defaults to `[]`. Supersedes `:include` if both are set.

## License

Copyright (c) 2025 Dashbit

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
