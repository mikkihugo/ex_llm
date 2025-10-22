import Config

# Configure logging
config :logger, level: :debug

# Development Oban Configuration
# Run jobs inline for easier debugging
config :centralcloud, Oban, testing: :inline