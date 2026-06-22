import Config

if config_env() == :test do
  config :tidewave,
    debug: true,
    ecto_repos: [MockRepo]
end
