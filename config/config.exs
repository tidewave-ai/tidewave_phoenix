import Config

if config_env() == :test do
  config :tidewave,
    debug: true,
    enable_control_plane: true,
    ecto_repos: [MockRepo]
end
