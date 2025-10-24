import Config

# Production logging
config :logger, level: :info

# Production Oban configuration
# Full concurrency with all queues enabled
config :genesis, Oban,
  queues: [
    cleanup: [concurrency: 1],
    analysis: [concurrency: 1],
    default: [concurrency: 2]
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Stalled, interval: 60}
  ]
