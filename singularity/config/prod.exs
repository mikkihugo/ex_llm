import Config

config :logger, level: :info

config :singularity, SingularityWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT", "8080")),
    transport_options: [num_acceptors: String.to_integer(System.get_env("HTTP_ACCEPTORS", "10"))]
  ],
  server: true

config :singularity, :fly,
  release_node: System.get_env("RELEASE_NODE"),
  release_distribution: System.get_env("RELEASE_DISTRIBUTION", "name")

config :singularity, :http_server_enabled, true

# Production Oban Configuration
# Persistent job queue with proper error handling
config :singularity, Oban,
  queues: [
    # Override dev defaults for production
    training: [concurrency: 1],
    maintenance: [concurrency: 3],
    default: [concurrency: 10]
  ]
