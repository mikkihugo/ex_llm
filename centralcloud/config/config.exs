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
    {Oban.Plugins.Stalled, interval: 60},
    # Cron plugin for scheduled jobs
    {Oban.Plugins.Cron,
     crontab: [
       # Pattern aggregation: every 1 hour
       {"0 * * * *", Centralcloud.Jobs.PatternAggregationJob},
       # Global statistics: every 1 hour
       {"0 * * * *", Centralcloud.Jobs.StatisticsJob},
       # Package sync: daily at 2 AM
       {"0 2 * * *", Centralcloud.Jobs.PackageSyncJob}
     ]}
  ]

# Framework Learning Configuration (Config-Driven)
# Defines which framework learning strategies are enabled and their execution priority
config :centralcloud, :framework_learners,
  template_matcher: %{
    module: Centralcloud.FrameworkLearners.TemplateMatcher,
    enabled: true,
    priority: 10,
    description: "Fast template-based framework matching using dependency signatures"
  },
  llm_discovery: %{
    module: Centralcloud.FrameworkLearners.LLMDiscovery,
    enabled: true,
    priority: 20,
    description: "Intelligent framework detection using LLM analysis of code"
  }

import_config "#{config_env()}.exs"