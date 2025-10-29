import Config

config :singularity, :git_coordinator, enabled: false

# Note: Singularity is a pure Elixir application with no web endpoint
# Web interfaces are provided by Observer (port 4002)

config :logger, level: :warning

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

# SASL Configuration for Tests
# Silence SASL in tests (errors logged via ExUnit)
config :sasl,
  sasl_error_logger: :silent,
  errlog_type: :error,
  utc_log: true
