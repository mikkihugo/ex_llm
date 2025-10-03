import Config

config :seed_agent, SeedAgentWeb.Endpoint,
  http: [port: 5001],
  server: false

config :logger, level: :warning

config :seed_agent, :http_server_enabled, false
