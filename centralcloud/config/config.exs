import Config

# Configure the database
config :centralcloud, Centralcloud.Repo,
  database: "centralcloud",
  hostname: System.get_env("CENTRALCLOUD_DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("CENTRALCLOUD_DB_PORT", "5432")),
  username: System.get_env("CENTRALCLOUD_DB_USER", "mhugo"),
  password: System.get_env("CENTRALCLOUD_DB_PASSWORD", ""),
  pool_size: 10

# Configure NATS
config :centralcloud, Centralcloud.NatsClient,
  host: System.get_env("NATS_HOST", "localhost"),
  port: String.to_integer(System.get_env("NATS_PORT", "4222"))

# Configure the application
config :centralcloud,
  ecto_repos: [Centralcloud.Repo]

# Oban Background Job Queue Configuration
# Pattern aggregation, package sync, statistics generation
config :centralcloud, Oban,
  repo: Centralcloud.Repo,
  queues: [
    # Aggregation jobs (up to 2 concurrent)
    aggregation: [concurrency: 2],
    # Package sync and external integrations (up to 1)
    sync: [concurrency: 1],
    # Default queue for general background work
    default: [concurrency: 5]
  ],
  plugins: [
    # Prune completed/discarded jobs after 7 days
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    # Periodically check for stalled jobs
    {Oban.Plugins.Stalled, interval: 60}
  ]

# Quantum Scheduler Configuration
# Cron-like scheduling for periodic global tasks
config :centralcloud, Centralcloud.Scheduler,
  # Enable the scheduler globally
  global: true,
  # Log execution of all jobs
  debug: true,
  # Define all scheduled jobs
  jobs: [
    # Pattern aggregation: every 1 hour
    {"0 * * * *", {Centralcloud.Jobs.PatternAggregationJob, :aggregate_patterns, []}},
    # Package sync: daily at 2 AM
    {"0 2 * * *", {Centralcloud.Jobs.PackageSyncJob, :sync_packages, []}},
    # Global statistics: every 1 hour
    {"0 * * * *", {Centralcloud.Jobs.StatisticsJob, :generate_statistics, []}}
  ]

import_config "#{config_env()}.exs"