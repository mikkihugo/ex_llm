import Config

# Development logging
config :logger, level: :debug

# Development Oban configuration
# Run jobs inline for easier debugging
config :genesis, Oban, testing: :inline
