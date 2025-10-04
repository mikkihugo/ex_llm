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
