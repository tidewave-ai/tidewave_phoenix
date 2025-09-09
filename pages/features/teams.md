# Teams

The Tidewave Team plan provides a central place to manage billing and configuration. Currently in beta, this plan offers early adopters special pricing and the opportunity to shape our roadmap.

Applications that want to use Tidewave Team must be explicitly configured to do so, as outlined in the next section. The Tidewave Team plan is separate from your Tidewave Pro account. You don't need a Tidewave Pro account if your project is configured to use the Tidewave Team plan.

## Installation

Applications must be explicitly configured to use Tidewave Teams via the steps below:

<!-- tabs-open -->

### Rails

[Install the latest `tidewave` gem](https://github.com/tidewave-ai/tidewave_rails)
and set `config.tidewave` in your Rails `config/application.rb` to use your team
and restart your app:

```ruby
config.tidewave.team = { id: 'your-team' }
```

### Phoenix

[Install the latest `tidewave` package](https://github.com/tidewave-ai/tidewave_phoenix)
and configure `plug Tidewave` in your `lib/my_app_web/endpoint.ex` to use your team:

```elixir
plug Tidewave, team: [id: "your-team"]
```

<!-- tabs-close -->