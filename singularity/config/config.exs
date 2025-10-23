import Config

config :singularity,
  namespace: Singularity

config :singularity, Singularity.Telemetry, metrics: []

config :logger, level: :info

config :logger,
  compile_time_purge_matching: [
    [level: :debug],
    [level: :info],
    [level: :warning],
    [level: :error]
  ]

config :libcluster,
  topologies: []

config :singularity, :git_coordinator,
  enabled:
    System.get_env("GIT_COORDINATOR_ENABLED", "false")
    |> String.downcase()
    |> (&(&1 in ["1", "true", "yes"])).(),
  repo_path: System.get_env("GIT_COORDINATOR_REPO_PATH"),
  base_branch: System.get_env("GIT_COORDINATOR_BASE_BRANCH", "main"),
  remote: System.get_env("GIT_COORDINATOR_REMOTE")

# Claude CLI Recovery Configuration
# Uses dedicated recovery binary: ~/.singularity/emergency/bin/claude-recovery
# Named "claude-recovery" to avoid collision with NPM Claude SDK
# Install with: ./scripts/install_claude_native.sh
emergency_claude_path =
  Path.expand(System.get_env("SINGULARITY_EMERGENCY_BIN") || "~/.singularity/emergency/bin")
  |> Path.join("claude-recovery")

config :singularity, :claude,
  default_model: System.get_env("CLAUDE_DEFAULT_MODEL", "sonnet"),
  cli_path: System.get_env("CLAUDE_CLI_PATH") || emergency_claude_path,
  home: System.get_env("CLAUDE_HOME"),
  cli_flags: String.split(System.get_env("CLAUDE_CLI_FLAGS", ""), " ", trim: true),
  default_profile: :safe,
  profiles: %{
    safe: %{
      description: "Read-only CLI usage with permissions intact",
      claude_flags: [],
      dangerous: false,
      allowed_tools: [],
      disallowed_tools: ["FilesystemEdit", "BashEdit"]
    },
    write: %{
      description: "Allow filesystem edits and dangerous operations",
      claude_flags: ["--dangerously-skip-permissions"],
      dangerous: true,
      allowed_tools: [],
      disallowed_tools: []
    }
  }

import_config "#{config_env()}.exs"

# Database Configuration - Auto-detected by Nix
# Dev: PostgreSQL auto-starts via nix develop
# Prod: Same shared database (single DB strategy for internal tooling)
# All environments use same database for living knowledge base
config :singularity, Singularity.Repo,
  # Single shared DB (internal tooling - no multi-tenancy)
  database: System.get_env("SINGULARITY_DB_NAME", "singularity"),
  username: System.get_env("SINGULARITY_DB_USER") || System.get_env("USER") || "postgres",
  password: System.get_env("SINGULARITY_DB_PASSWORD", ""),
  hostname: System.get_env("SINGULARITY_DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("SINGULARITY_DB_PORT", "5432")),
  pool_size: String.to_integer(System.get_env("SINGULARITY_DB_POOL", "25"))

config :singularity, ecto_repos: [Singularity.Repo]

# Oban Background Job Queue Configuration
# ML training, pattern mining, and maintenance tasks
config :singularity, Oban,
  repo: Singularity.Repo,
  queues: [
    # ML training jobs (GPU constraint - only 1 at a time)
    training: [concurrency: 1, rate_limit: [allowed: 1, period: 60]],
    # Maintenance tasks (cache cleanup, pattern sync - up to 3 concurrent)
    maintenance: [concurrency: 3],
    # Default queue for general background work
    default: [concurrency: 10]
  ],
  plugins: [
    # Prune completed/discarded jobs after 7 days
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    # Periodically check for stalled jobs
    {Oban.Plugins.Stalled, interval: 60}
  ]

# Oban Job Queue & Cron Configuration
# Background job processing with cron-like scheduling for periodic tasks
config :oban,
  repo: Singularity.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    Oban.Plugins.Repeater,
    # Cron plugin for scheduled jobs
    {Oban.Plugins.Cron,
     crontab: [
       # Metrics aggregation: every 5 minutes (feeds Feedback Analyzer)
       {"*/5 * * * *", Singularity.Jobs.MetricsAggregationWorker},
       # Feedback analysis: every 30 minutes (feeds Agent Evolution)
       {"*/30 * * * *", Singularity.Jobs.FeedbackAnalysisWorker},
       # Agent evolution: every 1 hour (applies improvements from feedback analysis)
       {"0 * * * *", Singularity.Jobs.AgentEvolutionWorker},
       # Knowledge export: every day at midnight (promotes learned patterns to Git)
       {"0 0 * * *", Singularity.Jobs.KnowledgeExportWorker},
       # Cache cleanup: every 15 minutes
       {"*/15 * * * *", Singularity.Jobs.CacheCleanupWorker},
       # Cache refresh: every hour
       {"0 * * * *", Singularity.Jobs.CacheRefreshWorker},
       # Cache prewarm: every 6 hours
       {"0 */6 * * *", Singularity.Jobs.CachePrewarmWorker},
       # Pattern sync: every 5 minutes
       {"*/5 * * * *", Singularity.Jobs.PatternSyncWorker}
     ]}
  ],
  queues: [default: 10, ml_training: 5, pattern_mining: 3],
  # Enable verbose logging for job execution
  verbose: true
