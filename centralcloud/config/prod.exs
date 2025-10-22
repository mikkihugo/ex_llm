import Config

# Configure logging
config :logger, level: :info

# Production Oban Configuration
# Persistent job queue with proper error handling
config :centralcloud, Oban,
  queues: [
    aggregation: [concurrency: 2],
    sync: [concurrency: 1],
    default: [concurrency: 5]
  ]
