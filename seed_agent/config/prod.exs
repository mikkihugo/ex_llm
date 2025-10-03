import Config

config :logger, level: :info

config :seed_agent, SeedAgentWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT", "8080")),
    transport_options: [num_acceptors: String.to_integer(System.get_env("HTTP_ACCEPTORS", "10"))]
  ],
  server: true

config :seed_agent, :fly,
  release_node: System.get_env("RELEASE_NODE"),
  release_distribution: System.get_env("RELEASE_DISTRIBUTION", "name")

config :seed_agent, :http_server_enabled, true
