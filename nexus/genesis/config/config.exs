import Config

# Declare Ecto repos for migrations
config :genesis, ecto_repos: [Genesis.Repo]

# Configure logging
config :logger, level: :info

# Configure Ecto repository
config :genesis, Genesis.Repo,
  database: "genesis",
  username: System.get_env("DB_USER", System.get_env("USER", "postgres")),
  password: System.get_env("DB_PASSWORD", ""),
  hostname: System.get_env("DB_HOST", "localhost"),
  port: System.get_env("DB_PORT", "5432") |> String.to_integer(),
  pool_size: 10

# Configure Oban background jobs
config :genesis, Oban,
  engine: Oban.Engines.Basic,
  queues: [
    cleanup: [concurrency: 1],
    analysis: [concurrency: 1],
    default: [concurrency: 2]
  ],
  plugins: [
    {Oban.Plugins.Cron, crons: [
      # Cleanup completed experiments every 6 hours
      {"0 */6 * * *", Genesis.Cleanup},
      # Analyze trends every 24 hours
      {"0 0 * * *", Genesis.Analysis},
      # Report metrics to Centralcloud every 24 hours (1 AM)
      {"0 1 * * *", Genesis.Reporting}
    ]}
  ]

# Configure Shared Queue (pgmq - central message hub, owned by CentralCloud)
# Genesis reads job_requests and publishes job_results
config :genesis, :shared_queue,
  enabled: true,
  database_url: "postgresql://postgres:@localhost:5432/shared_queue",
  poll_interval_ms: 1000,
  batch_size: 100

# Genesis-specific configuration
config :genesis,
  sandbox_dir: 
    System.get_env("GENESIS_SANDBOX_DIR") ||
    Path.join([
      System.get_env("XDG_DATA_HOME") || System.get_env("HOME", "/tmp"),
      ".genesis",
      "sandboxes"
    ]),
  experiment_timeout_ms: 3_600_000,
  max_experiments_concurrent: 5,
  auto_rollback_on_regression: true,
  regression_threshold: 0.05

import_config "#{Mix.env()}.exs"
