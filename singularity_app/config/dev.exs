import Config

config :logger, level: :debug

config :singularity, SingularityWeb.Endpoint,
  http: [port: 4000],
  server: true

config :libcluster,
  topologies: []

config :singularity, :http_server_enabled, true

config :singularity, Singularity.Repo, database: "singularity_dev"
