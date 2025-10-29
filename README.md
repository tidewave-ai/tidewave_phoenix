# Tidewave

Tidewave is the coding agent for full-stack web app development, deeply integrated with Phoenix, from the database to the UI. [See our website](https://tidewave.ai) for more information.

This project can also be used as a standalone Model Context Protocol (MCP) server for your editors.

## Installation

### Manually

You can install Tidewave by adding the `tidewave` package to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tidewave, "~> 0.5", only: :dev}
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

Now access `/tidewave` route of your web application to enjoy Tidewave Web!

> Tidewave Web works best with Phoenix LiveView v1.1 or later. Once you update it,
> make sure to enable the following options in your `config/dev.exs`:
>
> ```elixir
> config :phoenix_live_view,
>   debug_heex_annotations: true,
>   debug_attributes: true
> ```
>
> Those are enabled by default for Phoenix v1.8+ apps.

### Using Igniter

Alternatively, you can use `igniter` to automatically install it into an existing Phoenix application:

```sh
# install igniter_new if you haven't already
mix archive.install hex igniter_new

# install tidewave
mix igniter.install tidewave
```

Now access `/tidewave` route of your web application to enjoy Tidewave Web!

### Usage in non-Phoenix applications

Tidewave can be used as a MCP in any Elixir project. For example, you can use `bandit` (and `tidewave`) in dev mode in your `mix.exs`:

```elixir
{:tidewave, "~> 0.4", only: :dev},
{:bandit, "~> 1.0", only: :dev},
```

And then adding an alias in your `mix.exs`:

```elixir
aliases: [
  tidewave:
    "run --no-halt -e 'Agent.start(fn -> Bandit.start_link(plug: Tidewave, port: 4000) end)'"
]
```

Now run `mix tidewave` and [configure Tidewave as a MCP](https://hexdocs.pm/tidewave/mcp.html).

## Troubleshooting

Tidewave expects your web application to be running on `localhost`. If you are not running on localhost, you may need to set some additional configuration. In particular, you must pass `allow_remote_access: true` to `plug Tidewave` and optionally configure the origin you are accessing from, for example:

```elixir
  plug Tidewave,
   allow_remote_access: true,
   allowed_origins: ["http://company.local"]
```

If you want to use Docker for development, you either need to enable the configuration above or automatically redirect the relevant ports, as done by [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers). See our [containers](https://hexdocs.pm/tidewave/containers.html) guide for more information.

### Content security policy

If you have enabled Content-Security-Policy, Tidewave will automatically enable "unsafe-eval" under `script-src` in order for contextual browser testing to work correctly. It also disables the `frame-ancestors` directive.

## Configuration

You may configure the `Tidewave` plug using the following syntax:

```elixir
  plug Tidewave, options
```

The following options are available:

  * `:allowed_origins` - a list of values matched against the `Origin` header to prevent cross origin and DNS rebinding attacks. Each value must be a string of shape `[scheme:]//host[:port]`, where both scheme and port are optional. The host may also start with "*". Example: `["//localhost:8000", "//*.test"]`.

  * `:allow_remote_access` - Tidewave only allows requests from localhost by default, even if your server listens on other interfaces as well. If you trust your network and need to access Tidewave from a different machine, this configuration can be set to `true`.

  * `:inspect_opts` - Custom options passed to `Kernel.inspect/2` when formatting some tool results. Defaults to: `[charlists: :as_lists, limit: 50, pretty: true]`

  * `:team` - set your Tidewave Team configuration, such as `team: [id: "my-company"]`

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
