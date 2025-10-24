import Config

# Configure logging for tests
config :logger, level: :warning

# Test Oban Configuration
# Run jobs inline for deterministic testing
config :centralcloud, Oban, testing: :inline

# Test NATS Configuration
# Disable NATS subscribers in test mode to avoid connection errors
config :centralcloud, CentralCloud.NatsClient,
  host: "localhost",
  port: 4222,
  enable_subscribers: false
