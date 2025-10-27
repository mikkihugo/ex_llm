import Config

config :singularity, :git_coordinator, enabled: false

config :singularity, SingularityWeb.Endpoint,
  http: [port: 5001],
  server: false

config :logger, level: :warning

config :singularity, :http_server_enabled, false

config :singularity, Singularity.Repo,
  # Shared DB, sandboxed for tests
  username: System.get_env("POSTGRES_USER", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "singularity_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Disable Oban in tests - it's not needed and causes initialization issues
config :singularity, :oban_enabled, false

# Oban configuration for test mode
# CRITICAL: start_supervised: false prevents OTP from auto-starting Oban
# This allows us to handle Oban startup explicitly in the supervision tree
config :oban,
  start_supervised: false,
  engine: Oban.Engines.Inline,
  queues: [default: [concurrency: 1]],
  repo: Singularity.Repo
