# Tidewave

Tidewave is a coding agent that runs in the browser alongside your web application, deeply integrated with Phoenix. [See our website](https://tidewave.ai) for more information.

This project can also be used as a standalone Model Context Protocol server for your editors.

## Installation

### Manually

You can install Tidewave by adding the `tidewave` package to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tidewave, "~> 0.4", only: :dev}
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

Tidewave is a regular Plug, so you can use it in any Elixir project, as long as you run a web server. For example, you can use `bandit` (and `tidewave`) in dev mode in your `mix.exs`:

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

Now run `mix tidewave` and Tidewave will be available at `https://localhost:4000/tidewave`.

## Troubleshooting

Tidewave expects your web application to be running on `localhost`. If you are not running on localhost, you may need to set some additional configuration. In particular, you must pass `allow_remote_access: true` to `plug Tidewave` and optionally configure the origin you are accessing from, for example:

```elixir
  plug Tidewave,
   allow_remote_access: true,
   allowed_origins: ["http://company.local"]
```

If you want to use Docker for development, you either need to enable the configuration above or automatically redirect the relevant ports, as done by [devcontainers](https://code.visualstudio.com/docs/devcontainers/containers). See our [containars](https://hexdocs.pm/tidewave/containers.html) guide for more information.

If you have enabled Content-Security-Policy, Tidewave also requires "unsafe-eval" to be enabled under `script-src` in order for contextual browser testing to work correctly.

## Configuration

You may configure the `Tidewave` plug using the following syntax:

```elixir
  plug Tidewave, options
```

The following options are available:

  * `:allowed_origins` - if using the MCP from a browser, this can be a list of values matched against the `Origin` header to prevent cross origin and DNS rebinding attacks. When using Phoenix, this defaults to the `Endpoint`'s URL.

  * `:allow_remote_access` - Tidewave only allows requests from localhost by default, even if your server listens on other interfaces as well. If you trust your network and need to access Tidewave from a different machine, this configuration can be set to `true`.

  * `:autoformat` - When writing Elixir source files, Tidewave will automatically format them with `mix format` by default. Setting this option to `false` disables autoformatting.

  * `:inspect_opts` - Custom options passed to `Kernel.inspect/2` when formatting some tool results. Defaults to: `[charlists: :as_lists, limit: 50, pretty: true]`

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
