import Config

# Development logging
config :logger, level: :debug

# Development Oban configuration
# Run jobs inline for easier debugging
config :genesis, Oban, testing: :inline

# Development Shared Queue (local PostgreSQL)
config :genesis, :shared_queue,
  enabled: true,
  database_url: "postgresql://postgres:@localhost:5432/shared_queue",
  poll_interval_ms: 1000,
  batch_size: 100
