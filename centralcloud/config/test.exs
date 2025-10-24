import Config

# Configure logging for tests
config :logger, level: :warning

# Test Oban Configuration
# Run jobs inline for deterministic testing
config :centralcloud, Oban, testing: :inline
