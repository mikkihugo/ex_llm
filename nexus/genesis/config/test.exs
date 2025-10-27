import Config

# Test logging
config :logger, level: :warning

# Test Oban configuration
# Run jobs inline for deterministic testing
config :genesis, Oban, testing: :inline

# Test database
config :genesis, Genesis.Repo,
  database: "genesis_test",
  pool: Ecto.Adapters.SQL.Sandbox

# Test Shared Queue (disabled for unit tests)
# Integration tests can enable with specific test database
config :genesis, :shared_queue,
  enabled: false,
  database_url: "postgresql://postgres:@localhost:5432/shared_queue_test",
  poll_interval_ms: 100,
  batch_size: 10
