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

# SASL Configuration for Production
# Log to file in production for system monitoring
config :sasl,
  sasl_error_logger: {:file, ~c"log/sasl-error.log"},
  errlog_type: :error,
  utc_log: true
