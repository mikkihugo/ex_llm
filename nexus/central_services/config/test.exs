import Config

# Configure logging for tests
config :logger, level: :warning

# Test Oban Configuration
# Run jobs inline for deterministic testing
config :centralcloud, Oban, testing: :inline

# Test QuantumFlow Configuration
# All messaging uses QuantumFlow with PGMQ + NOTIFY
config :centralcloud, QuantumFlow,
  repo: CentralCloud.Repo,
  pgmq_extension: true
