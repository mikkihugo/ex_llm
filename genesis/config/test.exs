import Config

# Test logging
config :logger, level: :warning

# Test Oban configuration
# Run jobs inline for deterministic testing
config :genesis, Oban, testing: :inline

# Test database
config :genesis, Genesis.Repo,
  database: "genesis_db_test",
  pool: Ecto.Adapters.SQL.Sandbox
