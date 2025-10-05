import Config

config :singularity, :git_coordinator, enabled: false

config :singularity, SingularityWeb.Endpoint,
  http: [port: 5001],
  server: false

config :logger, level: :warning

config :singularity, :http_server_enabled, false

config :singularity, Singularity.Repo,
  database: "singularity_test",
  pool: Ecto.Adapters.SQL.Sandbox
