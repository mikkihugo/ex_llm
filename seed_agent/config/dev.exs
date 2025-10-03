import Config

config :logger, level: :debug

config :seed_agent, SeedAgentWeb.Endpoint,
  http: [port: 4000],
  server: true

config :libcluster,
  topologies: []

config :seed_agent, :http_server_enabled, true
