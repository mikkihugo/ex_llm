import Config

config :logger, level: :info

config :singularity, SingularityWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT", "8080")),
    transport_options: [num_acceptors: String.to_integer(System.get_env("HTTP_ACCEPTORS", "10"))]
  ],
  https: [
    port: String.to_integer(System.get_env("HTTPS_PORT", "8443")),
    keyfile: System.get_env("HTTPS_KEYFILE", "priv/cert/selfsigned_key.pem"),
    certfile: System.get_env("HTTPS_CERTFILE", "priv/cert/selfsigned.pem"),
    transport_options: [num_acceptors: String.to_integer(System.get_env("HTTPS_ACCEPTORS", "10"))]
  ],
  force_ssl: [rewrite_on: [:x_forwarded_proto]],
  server: true

config :singularity, :fly,
  release_node: System.get_env("RELEASE_NODE"),
  release_distribution: System.get_env("RELEASE_DISTRIBUTION", "name")

config :singularity, :http_server_enabled, true

# Production Oban Configuration
# Persistent job queue with proper error handling
# Note: Merge with base config in config.exs - only override production-specific settings
config :oban,
  queues: [
    # Override dev defaults for production
    training: [concurrency: 1],
    maintenance: [concurrency: 3],
    default: [concurrency: 10]
  ]
