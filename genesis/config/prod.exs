import Config

# Production logging
config :logger, level: :info

# Production Oban configuration
config :genesis, Oban,
  queues: [
    cleanup: [concurrency: 1],
    analysis: [concurrency: 1],
    default: [concurrency: 2]
  ]

# Production Quantum configuration
config :genesis, Genesis.Scheduler, debug: false
