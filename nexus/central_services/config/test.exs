import Config

# Configure logging for tests
config :logger, level: :warning

# Test Oban Configuration
# Run jobs inline for deterministic testing
config :centralcloud, Oban, testing: :inline

# Test PgFlow Configuration
# All messaging uses PgFlow with PGMQ + NOTIFY
config :centralcloud, Pgflow,
  repo: CentralCloud.Repo,
  pgmq_extension: true
