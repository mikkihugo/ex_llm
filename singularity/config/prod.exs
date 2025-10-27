import Config

config :logger, level: :info

# Note: Singularity is a pure Elixir application with no web endpoint
# Web interfaces are provided by:
# - Observer (port 4002) - Phoenix web UI for observability
# - AI calls go directly through ExLLM to providers (no HTTP intermediary)

config :singularity, :fly,
  release_node: System.get_env("RELEASE_NODE"),
  release_distribution: System.get_env("RELEASE_DISTRIBUTION", "name")

# HTTP server not applicable - Singularity is pure Elixir application

# Production Oban Configuration
# Persistent job queue with proper error handling
# Note: Merge with base config in config.exs - only override production-specific settings
config :oban,
  queues: [
    # Override dev defaults for production
    training: [concurrency: 1],
    maintenance: [concurrency: 3],
    default: [concurrency: 10]
  ]
