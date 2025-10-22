import Config

# Development logging
config :logger, level: :debug

# Development Oban configuration
# Run jobs inline for easier debugging
config :genesis, Oban, testing: :inline

# Development Quantum configuration
# Disable scheduler during development (or set short intervals for testing)
config :genesis, Genesis.Scheduler, debug: false
