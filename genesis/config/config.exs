import Config

# Configure logging
config :logger, level: :info

# Configure Ecto repository
config :genesis, Genesis.Repo,
  database: "genesis_db",
  username: System.get_env("DB_USER", "postgres"),
  password: System.get_env("DB_PASSWORD", ""),
  hostname: System.get_env("DB_HOST", "localhost"),
  port: System.get_env("DB_PORT", "5432") |> String.to_integer(),
  pool_size: 10

# Configure Oban background jobs
config :genesis, Oban,
  queues: [
    cleanup: [concurrency: 1],
    analysis: [concurrency: 1],
    default: [concurrency: 2]
  ]

# Configure Quantum scheduler
config :genesis, Genesis.Scheduler,
  jobs: [
    # Cleanup completed experiments every 6 hours
    {"0 */6 * * *", {Genesis.Jobs, :cleanup_experiments, []}},
    # Analyze trends every 24 hours
    {"0 0 * * *", {Genesis.Jobs, :analyze_trends, []}},
    # Report metrics to Centralcloud every 24 hours
    {"0 1 * * *", {Genesis.Jobs, :report_metrics, []}}
  ]

# Configure NATS
config :genesis,
  nats_host: System.get_env("NATS_HOST", "127.0.0.1"),
  nats_port: System.get_env("NATS_PORT", "4222") |> String.to_integer()

# Genesis-specific configuration
config :genesis,
  sandbox_dir: Path.join([System.get_env("HOME", "/tmp"), ".genesis", "sandboxes"]),
  experiment_timeout_ms: 3_600_000,
  max_experiments_concurrent: 5,
  auto_rollback_on_regression: true,
  regression_threshold: 0.05

import_config "#{Mix.env()}.exs"
