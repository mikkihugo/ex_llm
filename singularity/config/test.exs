import Config

config :singularity, :git_coordinator, enabled: false

config :singularity, SingularityWeb.Endpoint,
  http: [port: 5001],
  server: false

config :logger, level: :warning

config :singularity, :http_server_enabled, false

config :singularity, Singularity.Repo,
  # Shared DB, sandboxed for tests
  database: "singularity",
  pool: Ecto.Adapters.SQL.Sandbox

# Disable Oban in tests - it's not needed and causes initialization issues
config :singularity, :oban_enabled, false

# Disable NATS in tests - NATS server not available
config :singularity, :nats, %{enabled: false}

# Oban configuration for test mode
# CRITICAL: start_supervised: false prevents OTP from auto-starting Oban
# This allows us to handle Oban startup explicitly in the supervision tree
config :oban,
  start_supervised: false,
  engine: Oban.Engines.Inline,
  queues: [default: [concurrency: 1]],
  repo: Singularity.Repo
