import Config

config :singularity,
  namespace: Singularity

# Shared Queue Configuration (pgmq - central message hub managed by CentralCloud)
# Provides inter-service communication for LLM requests, approvals, questions, job requests
config :singularity, :shared_queue,
  enabled: System.get_env("SHARED_QUEUE_ENABLED", "true") == "true",
  database_url: System.get_env("SHARED_QUEUE_DB_URL"),
  poll_interval_ms: String.to_integer(System.get_env("SHARED_QUEUE_POLL_MS", "1000")),
  batch_size: String.to_integer(System.get_env("SHARED_QUEUE_BATCH_SIZE", "100")),
  # Separate configuration for LLM request polling (more frequent for lower latency)
  llm_request_poll_ms: String.to_integer(System.get_env("SHARED_QUEUE_LLM_POLL_MS", "100")),
  llm_batch_size: String.to_integer(System.get_env("SHARED_QUEUE_LLM_BATCH_SIZE", "50"))

# Automatic Code Ingestion Configuration
# Enables real-time file watching and automatic code ingestion into database
config :singularity, :auto_ingestion,
  enabled: System.get_env("AUTO_INGESTION_ENABLED", "true") == "true",
  # File watching configuration
  watch_directories:
    String.split(System.get_env("AUTO_INGESTION_WATCH_DIRS", "lib,packages,nexus,observer"), ","),
  debounce_delay_ms: String.to_integer(System.get_env("AUTO_INGESTION_DEBOUNCE_MS", "60000")),
  busy_file_threshold_ms:
    String.to_integer(System.get_env("AUTO_INGESTION_BUSY_THRESHOLD_MS", "1000")),
  # Retry configuration
  max_retries: String.to_integer(System.get_env("AUTO_INGESTION_MAX_RETRIES", "1")),
  retry_delay_ms: String.to_integer(System.get_env("AUTO_INGESTION_RETRY_DELAY_MS", "1000")),
  # File filtering
  include_extensions:
    String.split(
      System.get_env(
        "AUTO_INGESTION_INCLUDE_EXT",
        ".ex,.exs,.rs,.ts,.tsx,.js,.jsx,.py,.go,.nix,.sh,.toml,.json,.yaml,.yml,.md"
      ),
      ","
    ),
  ignore_patterns:
    String.split(
      System.get_env(
        "AUTO_INGESTION_IGNORE_PATTERNS",
        "/_build/,/deps/,/node_modules/,/target/,/.git/,/.nix/,.log,.tmp,.pid,.DS_Store,Thumbs.db"
      ),
      ","
    ),
  # Performance tuning
  max_concurrent_ingestions:
    String.to_integer(System.get_env("AUTO_INGESTION_MAX_CONCURRENT", "1")),
  ingestion_timeout_ms: String.to_integer(System.get_env("AUTO_INGESTION_TIMEOUT_MS", "30000")),
  # Auto-detection settings
  auto_detect_codebase: System.get_env("AUTO_INGESTION_AUTO_DETECT_CODEBASE", "true") == "true",
  default_codebase_id: System.get_env("AUTO_INGESTION_DEFAULT_CODEBASE", "singularity"),
  # Logging control
  quiet_mode: System.get_env("AUTO_INGESTION_QUIET_MODE", "false") == "true"

# =============================================================================
# Broadway Embedding Pipeline Configuration
# =============================================================================
# High-performance concurrent embedding generation with PGFlow orchestration
# See docs/EMBEDDING_PIPELINE_PGFLOW.md for detailed documentation

# Embedding Pipeline Settings
# Enable/disable the Broadway embedding pipeline
config :singularity, :broadway_embedding_pipeline,
  enabled: System.get_env("EMBEDDING_PIPELINE_ENABLED", "true") == "true",
  # PGFlow workflow orchestration settings
  pgflow: %{
    enabled: System.get_env("EMBEDDING_PGFLOW_ENABLED", "true") == "true",
    queue_name: System.get_env("EMBEDDING_QUEUE_NAME", "embedding_jobs"),
    timeout_ms: String.to_integer(System.get_env("EMBEDDING_PGFLOW_TIMEOUT_MS", "300000")),
    concurrency: String.to_integer(System.get_env("EMBEDDING_PGFLOW_CONCURRENCY", "5")),
    retries: String.to_integer(System.get_env("EMBEDDING_PGFLOW_RETRIES", "3")),
    retry_delay_ms: String.to_integer(System.get_env("EMBEDDING_PGFLOW_RETRY_DELAY_MS", "5000"))
  },
  # Pipeline performance and hardware settings
  pipeline: %{
    # :cpu, :cuda, :metal
    device: String.to_atom(System.get_env("EMBEDDING_DEVICE", "cpu")),
    # Concurrent processors
    workers: String.to_integer(System.get_env("EMBEDDING_WORKERS", "10")),
    # GPU batch size
    batch_size: String.to_integer(System.get_env("EMBEDDING_BATCH_SIZE", "16")),
    # Pipeline timeout
    timeout_ms: String.to_integer(System.get_env("EMBEDDING_TIMEOUT_MS", "300000")),
    # Progress logging
    verbose: System.get_env("EMBEDDING_VERBOSE", "false") == "true"
  }

# =============================================================================
# HTDAG Auto-Bootstrap Configuration (Consolidated)
# =============================================================================
# Enables HTDAG-based automatic code ingestion with PgFlow orchestration
config :singularity, :htdag_auto_ingestion,
  enabled: System.get_env("HTDAG_AUTO_INGESTION_ENABLED", "false") == "true",
  # File watching configuration
  watch_directories:
    String.split(System.get_env("HTDAG_WATCH_DIRS", "lib,packages,nexus,observer"), ","),
  # Increased from 500ms to 2s
  debounce_delay_ms: String.to_integer(System.get_env("HTDAG_DEBOUNCE_MS", "2000")),
  # HTDAG-specific configuration - GENTLE LOAD SETTINGS
  # Reduced from 10 to 3
  max_concurrent_dags: String.to_integer(System.get_env("HTDAG_MAX_CONCURRENT", "3")),
  # Reduced from 10 to 5
  batch_size: String.to_integer(System.get_env("HTDAG_BATCH_SIZE", "5")),
  dependency_aware: System.get_env("HTDAG_DEPENDENCY_AWARE", "true") == "true",
  # Rate limiting and throttling
  # Max 30 files per minute
  rate_limit_per_minute: String.to_integer(System.get_env("HTDAG_RATE_LIMIT_PER_MIN", "30")),
  # Pause if CPU > 70%
  cpu_threshold: String.to_float(System.get_env("HTDAG_CPU_THRESHOLD", "0.7")),
  # Pause if memory > 80%
  memory_threshold: String.to_float(System.get_env("HTDAG_MEMORY_THRESHOLD", "0.8")),
  # 5s cooldown after high load
  cooldown_period_ms: String.to_integer(System.get_env("HTDAG_COOLDOWN_MS", "5000")),
  # Retry policy - More conservative
  retry_policy: %{
    # Reduced from 3 to 2
    max_retries: String.to_integer(System.get_env("HTDAG_MAX_RETRIES", "2")),
    # Increased from 2.0 to 3.0
    backoff_multiplier: String.to_float(System.get_env("HTDAG_BACKOFF_MULTIPLIER", "3.0")),
    # Increased from 1000 to 2000
    initial_delay_ms: String.to_integer(System.get_env("HTDAG_INITIAL_DELAY_MS", "2000"))
  },
  # File filtering
  include_extensions:
    String.split(
      System.get_env(
        "HTDAG_INCLUDE_EXT",
        ".ex,.exs,.rs,.ts,.tsx,.js,.jsx,.py,.go,.nix,.sh,.toml,.json,.yaml,.yml,.md"
      ),
      ","
    ),
  ignore_patterns:
    String.split(
      System.get_env(
        "HTDAG_IGNORE_PATTERNS",
        "/_build/,/deps/,/node_modules/,/target/,/.git/,/.nix/,.log,.tmp,.pid,.DS_Store,Thumbs.db"
      ),
      ","
    ),
  # Performance tuning - More conservative timeouts
  # Increased from 60s to 120s
  node_timeout_ms: String.to_integer(System.get_env("HTDAG_NODE_TIMEOUT_MS", "120000")),
  # Increased from 300s to 600s
  dag_timeout_ms: String.to_integer(System.get_env("HTDAG_DAG_TIMEOUT_MS", "600000")),
  # Load balancing
  load_balancing: %{
    enabled: System.get_env("HTDAG_LOAD_BALANCING", "true") == "true",
    # Check every 10s
    check_interval_ms: String.to_integer(System.get_env("HTDAG_LOAD_CHECK_INTERVAL", "10000")),
    adaptive_scaling: System.get_env("HTDAG_ADAPTIVE_SCALING", "true") == "true"
  },
  # Auto-detection settings
  auto_detect_codebase: System.get_env("HTDAG_AUTO_DETECT_CODEBASE", "true") == "true",
  default_codebase_id: System.get_env("HTDAG_DEFAULT_CODEBASE", "singularity"),
  # Hot reload settings
  hot_reload_enabled: System.get_env("HTDAG_HOT_RELOAD_ENABLED", "true") == "true",
  reload_delay_ms: String.to_integer(System.get_env("HTDAG_RELOAD_DELAY_MS", "1000")),
  max_concurrent_reloads: String.to_integer(System.get_env("HTDAG_MAX_CONCURRENT_RELOADS", "5")),
  dependency_timeout_ms: String.to_integer(System.get_env("HTDAG_DEPENDENCY_TIMEOUT_MS", "30000"))

config :singularity, :bootstrap_tasks,
  enabled: System.get_env("STARTUP_BOOT_TASKS_ENABLED", "true") == "true",
  delay_ms: String.to_integer(System.get_env("STARTUP_BOOT_TASKS_DELAY_MS", "60000"))

config :singularity, :setup_bootstrap,
  enabled: System.get_env("SETUP_BOOTSTRAP_ENABLED", "true") == "true",
  delay_ms: String.to_integer(System.get_env("SETUP_BOOTSTRAP_DELAY_MS", "60000"))

config :singularity, Singularity.Telemetry, metrics: []

config :logger, level: :info

config :logger,
  compile_time_purge_matching: [
    [level: :debug],
    [level: :info],
    [level: :warning],
    [level: :error]
  ]

# SASL Configuration - Erlang System Architecture Support Libraries
# Provides system monitoring, error logging, and progress reports
config :sasl,
  # Reduce SASL verbosity in production (default is :tty)
  sasl_error_logger: {:file, ~c"log/sasl-error.log"},
  # Control error report formatting
  # :error | :progress | :all
  errlog_type: :error,
  # UTC timestamps for logs
  utc_log: true

# Enhanced SASL Configuration - Telecom Authentication and Security
config :singularity, :sasl,
  # Supported SASL mechanisms
  mechanisms: [:diameter, :radius, :ss7, :standard_scram],
  # Default mechanism for authentication
  default_mechanism: :diameter,
  # Security settings
  security: %{
    # Minimum password requirements
    min_password_length: 12,
    # Require special characters in passwords
    require_special_chars: true,
    # Maximum authentication attempts per minute
    max_auth_attempts_per_minute: 5,
    # Session timeout in seconds (default: 1 hour)
    default_session_timeout: 3600,
    # Maximum session timeout in seconds (24 hours)
    max_session_timeout: 86400,
    # Enable audit logging
    audit_logging: true,
    # Enable security event notifications
    security_notifications: true
  },
  # Telecom-specific settings
  telecom: %{
    # Enable telecom protocol support
    enable_telecom_protocols: true,
    # Supported telecom protocols
    protocols: [:diameter, :radius, :ss7, :sigtran],
    # Network access server (NAS) configuration
    nas: %{
      # Default NAS identifier
      default_identifier: "singularity-nas",
      # NAS IP address (auto-detect if not set)
      ip_address: nil,
      # Supported authentication methods
      auth_methods: [:pap, :chap, :mschap]
    },
    # SS7 configuration
    ss7: %{
      # Default point code
      default_point_code: "1-234-5",
      # Default subsystem number
      default_subsystem: 3,
      # Global title translation enabled
      global_title_translation: true
    }
  },
  # Database integration
  database: %{
    # User table name for SASL authentication
    user_table: "sasl_users",
    # Enable automatic user provisioning
    auto_provisioning: false,
    # Password hashing algorithm
    password_hash_algorithm: :pbkdf2_sha256,
    # Password hash iterations
    password_hash_iterations: 100_000
  },
  # Integration settings
  integration: %{
    # Enable integration with existing security validator
    security_validator_integration: true,
    # Enable integration with audit system
    audit_system_integration: true,
    # Enable Rust NIF acceleration
    rust_acceleration: true
  }

config :libcluster,
  topologies: []

config :singularity, Singularity.Bootstrap.PageRankBootstrap,
  enabled: true,
  # 4 AM UTC daily (after midnight backups)
  refresh_schedule: "0 4 * * *",
  # Calculate on startup if scores are missing
  auto_init: true

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
  (System.get_env("SINGULARITY_EMERGENCY_BIN") ||
     Path.join([
       System.get_env("XDG_DATA_HOME") || System.get_env("HOME", "/tmp"),
       ".singularity",
       "emergency",
       "bin"
     ]))
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

# Import broadway_pgflow package defaults for PGFlow configuration
# import_config Path.expand("../../../packages/broadway_pgflow/config/config.exs", __DIR__)

import_config "#{config_env()}.exs"

# =============================================================================
# Singularity Architecture Learning Pipeline Configuration
# =============================================================================
# PGFlow migration for architecture learning pipeline with canary rollout support
config :singularity, :architecture_learning_pipeline,
  # Enable PGFlow mode (canary rollout)
  pgflow_enabled: System.get_env("PGFLOW_ARCHITECTURE_LEARNING_ENABLED", "false") == "true",
  # Canary rollout percentage (0-100)
  canary_percentage:
    String.to_integer(System.get_env("ARCHITECTURE_LEARNING_CANARY_PERCENT", "10"))

# PGFlow workflow configuration for architecture learning
config :singularity, :architecture_learning_workflow,
  # Workflow-level timeouts and retries
  timeout_ms: String.to_integer(System.get_env("ARCHITECTURE_WORKFLOW_TIMEOUT_MS", "300000")),
  retries: String.to_integer(System.get_env("ARCHITECTURE_WORKFLOW_RETRIES", "3")),
  retry_delay_ms:
    String.to_integer(System.get_env("ARCHITECTURE_WORKFLOW_RETRY_DELAY_MS", "5000")),
  # Concurrency settings
  concurrency: String.to_integer(System.get_env("ARCHITECTURE_WORKFLOW_CONCURRENCY", "1")),
  # Step-specific timeouts
  step_timeouts: %{
    pattern_discovery:
      String.to_integer(System.get_env("ARCHITECTURE_PATTERN_DISCOVERY_TIMEOUT_MS", "60000")),
    pattern_analysis:
      String.to_integer(System.get_env("ARCHITECTURE_PATTERN_ANALYSIS_TIMEOUT_MS", "30000")),
    model_training:
      String.to_integer(System.get_env("ARCHITECTURE_MODEL_TRAINING_TIMEOUT_MS", "180000")),
    model_validation:
      String.to_integer(System.get_env("ARCHITECTURE_MODEL_VALIDATION_TIMEOUT_MS", "30000")),
    model_deployment:
      String.to_integer(System.get_env("ARCHITECTURE_MODEL_DEPLOYMENT_TIMEOUT_MS", "60000"))
  },
  # Resource allocation hints
  resource_hints: %{
    model_training: %{gpu: true, single_worker: true}
  }

# =============================================================================
# Singularity Embedding Training Pipeline Configuration
# =============================================================================
# PGFlow migration for embedding training pipeline with canary rollout support
config :singularity, :embedding_training_pipeline,
  # Enable PGFlow mode (canary rollout)
  pgflow_enabled: System.get_env("PGFLOW_EMBEDDING_TRAINING_ENABLED", "false") == "true",
  # Canary rollout percentage (0-100)
  canary_percentage: String.to_integer(System.get_env("EMBEDDING_TRAINING_CANARY_PERCENT", "10"))

# PGFlow workflow configuration for embedding training
config :singularity, :embedding_training_workflow,
  # Workflow-level timeouts and retries
  timeout_ms: String.to_integer(System.get_env("EMBEDDING_WORKFLOW_TIMEOUT_MS", "300000")),
  retries: String.to_integer(System.get_env("EMBEDDING_WORKFLOW_RETRIES", "3")),
  retry_delay_ms: String.to_integer(System.get_env("EMBEDDING_WORKFLOW_RETRY_DELAY_MS", "5000")),
  # Concurrency settings
  concurrency: String.to_integer(System.get_env("EMBEDDING_WORKFLOW_CONCURRENCY", "1")),
  # Step-specific timeouts
  step_timeouts: %{
    data_collection:
      String.to_integer(System.get_env("EMBEDDING_DATA_COLLECTION_TIMEOUT_MS", "60000")),
    data_preparation:
      String.to_integer(System.get_env("EMBEDDING_DATA_PREPARATION_TIMEOUT_MS", "30000")),
    model_training:
      String.to_integer(System.get_env("EMBEDDING_MODEL_TRAINING_TIMEOUT_MS", "180000")),
    model_validation:
      String.to_integer(System.get_env("EMBEDDING_MODEL_VALIDATION_TIMEOUT_MS", "30000")),
    model_deployment:
      String.to_integer(System.get_env("EMBEDDING_MODEL_DEPLOYMENT_TIMEOUT_MS", "60000"))
  },
  # Resource allocation hints
  resource_hints: %{
    model_training: %{gpu: true, single_worker: true}
  }

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

# =============================================================================
# Oban Background Job Queue & Cron Configuration (Consolidated)
# =============================================================================
# Background job processing with cron-like scheduling for periodic tasks.
# ML training, pattern mining, maintenance, and utility jobs.
#
# Note: Using :oban namespace (not :singularity, Oban) for official Oban config
config :oban,
  repo: Singularity.Repo,
  queues: [
    # ML training jobs (GPU constraint - only 1 at a time)
    training: [concurrency: 1, rate_limit: [allowed: 1, period: 60]],
    # Maintenance tasks (cache cleanup, pattern sync - up to 3 concurrent)
    maintenance: [concurrency: 3],
    # Metrics aggregation tasks (hourly aggregation)
    metrics: [concurrency: 1],
    # Default queue for general background work
    default: [concurrency: 10],
    # Pattern mining jobs
    pattern_mining: [concurrency: 3]
  ],
  plugins: [
    # Prune completed/discarded jobs after 7 days
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    # Periodically check for stalled jobs
    {Oban.Plugins.Stalled, interval: 60},
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
       # Pattern sync: every 5 minutes
       {"*/5 * * * *", Singularity.Jobs.PatternSyncJob},
       # Dead code monitoring: daily at 9am
       {"0 9 * * *", Singularity.Jobs.DeadCodeDailyCheck},
       # Dead code summary: every Monday at 9am
       {"0 9 * * 1", Singularity.Jobs.DeadCodeWeeklySummary},
       # Database backup: hourly (keep 6)
       {"0 * * * *", Singularity.Database.BackupWorker, args: %{"type" => "hourly"}},
       # Database backup: daily at 1:00 AM (keep 7)
       {"0 1 * * *", Singularity.Database.BackupWorker, args: %{"type" => "daily"}},
       # Embedding fine-tuning: daily at 2:00 AM (BEAM-optimized Qodo)
       {"0 2 * * *", Singularity.Jobs.EmbeddingFinetuneJob,
        args: %{"model" => "qodo", "epochs" => 1}},
       # Template sync: daily at 2:15 AM (was: mix templates.sync --force)
       {"15 2 * * *", Singularity.Jobs.TemplateSyncWorker},
       # Cache cleanup: daily at 3:00 AM (was: mix analyze.cache clear)
       {"0 3 * * *", Singularity.Jobs.CacheClearWorker},
       # Dev LLM improvement: daily at 3:10 AM (CodeGen2-1B, 100 pairs, ~5-8 min)
       {"10 3 * * *", Singularity.Jobs.BeamLLMDailyImproveJob,
        args: %{"model" => "dev", "epochs" => 1, "pair_count" => 100}},
       # Prod LLM improvement: daily at 3:40 AM (CodeLlama-3.4B, 1000 pairs, ~20 min)
       {"40 3 * * *", Singularity.Jobs.BeamLLMDailyImproveJob,
        args: %{"model" => "prod", "epochs" => 1, "pair_count" => 1000}},
       # Registry sync: daily at 4:00 AM (was: mix registry.sync)
       {"0 4 * * *", Singularity.Jobs.RegistrySyncWorker},
       # Template embed: weekly on Sundays at 5:00 AM (was: mix templates.embed --missing)
       {"0 5 * * 0", Singularity.Jobs.TemplateEmbedWorker},
       # Code re-ingest: weekly on Sundays at 6:00 AM (re-index code for semantic search)
       {"0 6 * * 0", Singularity.Jobs.CodeIngestWorker}
       # NOTE: Moved to pg_cron (pure SQL - more efficient):
       # - Planning Seed: Runs once via pg_cron stored procedure
       #   Migration: 20251025000020_move_tasks_to_pgcron.exs
       # - Graph Populate: Runs weekly + startup via pg_cron
       #   Migration: 20251025000020_move_tasks_to_pgcron.exs
       # - Cache Cleanup: Runs every 15 min via pg_cron
       #   Migration: 20251025000030_move_cache_tasks_to_pgcron.exs
       # - Cache Refresh: Runs hourly via pg_cron
       #   Migration: 20251025000030_move_cache_tasks_to_pgcron.exs
       # - Cache Prewarm: Runs every 6 hours via pg_cron
       #   Migration: 20251025000030_move_cache_tasks_to_pgcron.exs
       # - PageRank Recalculation: Daily 3 AM via pg_cron
       #   Migration: 20251025000010_add_comprehensive_pgcron_maintenance.exs
     ]}
  ],
  # Enable verbose logging for job execution
  verbose: true

# =============================================================================
# Architecture Pattern Detection Configuration (Config-Driven)
# =============================================================================
# Defines which pattern detectors are enabled and their modules.
# Add new pattern types here without changing code!

config :singularity, :pattern_types,
  framework: %{
    module: Singularity.Architecture.Detectors.FrameworkDetector,
    enabled: true,
    description: "Detect web frameworks, build tools, and runtime frameworks"
  },
  technology: %{
    module: Singularity.Architecture.Detectors.TechnologyDetector,
    enabled: true,
    description: "Detect programming languages, runtimes, and technology stack"
  },
  service_architecture: %{
    module: Singularity.Architecture.Detectors.ServiceArchitectureDetector,
    enabled: true,
    description: "Detect microservice vs monolith architecture patterns"
  }

# =============================================================================
# Code Analysis Configuration (Config-Driven)
# =============================================================================
# Defines which analyzers are enabled and their modules.
# Add new analyzer types here without changing code!

config :singularity, :analyzer_types,
  feedback: %{
    module: Singularity.Architecture.Analyzers.FeedbackAnalyzer,
    enabled: true,
    description: "Identify agent improvement opportunities from metrics"
  },
  quality: %{
    module: Singularity.Architecture.Analyzers.QualityAnalyzer,
    enabled: true,
    description: "Analyze code quality issues and violations"
  },
  refactoring: %{
    module: Singularity.Architecture.Analyzers.RefactoringAnalyzer,
    enabled: true,
    description: "Identify refactoring needs and opportunities"
  }

# =============================================================================
# Code Scanning Configuration (Config-Driven)
# =============================================================================
# Defines which scanners are enabled (Quality, Security, Performance, etc.)

config :singularity, :scanner_types,
  quality: %{
    module: Singularity.CodeAnalysis.Scanners.QualityScanner,
    enabled: true,
    description: "Detect code quality issues and violations"
  },
  security: %{
    module: Singularity.CodeAnalysis.Scanners.SecurityScanner,
    enabled: true,
    description: "Detect code security vulnerabilities"
  },
  linting: %{
    module: Singularity.CodeAnalysis.Scanners.LintingScanner,
    enabled: true,
    description: "Multi-language linting: style, performance, AI patterns"
  }

# =============================================================================
# Code Generation Configuration (Config-Driven)
# =============================================================================
# Defines which code generators are enabled.
#
# Currently Implemented:
# - QualityGenerator: High-quality production-ready code generation
#
# Future Generators (Not Yet Implemented):
# - RAG Generator: Retrieval-Augmented Generation using code embeddings
# - Pseudocode Generator: High-level algorithm specification
# - Template Generator: Template-based code generation
#
# To add a new generator:
# 1. Create module at singularity/lib/singularity/code_generation/generators/
# 2. Implement @behaviour Singularity.CodeGeneration.GeneratorType
# 3. Add to config below with enabled: true
# 4. GenerationOrchestrator will automatically discover and use it

config :singularity, :generator_types,
  code_generator: %{
    module: Singularity.CodeGeneration.Generators.CodeGeneratorImpl,
    enabled: true,
    description: "Generate code with RAG + Quality + Strategy selection (T5 local vs LLM API)"
  },
  rag: %{
    module: Singularity.CodeGeneration.Generators.RAGGeneratorImpl,
    enabled: true,
    description: "Generate code using Retrieval-Augmented Generation (RAG) from your codebase"
  },
  generator_engine: %{
    module: Singularity.CodeGeneration.Generators.GeneratorEngineImpl,
    enabled: true,
    description: "Generate code using Rust NIF-backed engine with intelligent naming"
  },
  quality: %{
    module: Singularity.CodeGeneration.Generators.QualityGenerator,
    enabled: true,
    description: "Generate high-quality, production-ready code"
  }

# =============================================================================
# Extractor Configuration (Config-Driven)
# =============================================================================
# Defines which extractors are enabled for unified metadata extraction
# All extractors implement ExtractorType behavior for consistent interface

config :singularity, :extractor_types,
  ai_metadata: %{
    module: Singularity.Analysis.Extractors.AIMetadataExtractorImpl,
    enabled: true,
    description: "Extract AI navigation metadata (JSON/YAML/Mermaid/Markdown) from @moduledoc"
  },
  ast: %{
    module: Singularity.Analysis.Extractors.AstExtractorImpl,
    enabled: true,
    description: "Extract code structure (dependencies, calls, types, docs) from tree-sitter AST"
  },
  pattern: %{
    module: Singularity.Analysis.Extractors.PatternExtractor,
    enabled: true,
    description: "Extract code patterns and architectural keywords"
  }

# =============================================================================
# Search Configuration (Config-Driven)
# =============================================================================
# Defines which search types are enabled (Semantic, Hybrid, AST, Package, etc.)

config :singularity, :search_types,
  semantic: %{
    module: Singularity.Search.Searchers.SemanticSearch,
    enabled: true,
    description: "Semantic search using embeddings and pgvector similarity"
  },
  hybrid: %{
    module: Singularity.Search.Searchers.HybridSearch,
    enabled: true,
    description: "Hybrid search combining full-text search and semantic similarity"
  },
  ast: %{
    module: Singularity.Search.Searchers.AstSearch,
    enabled: false,
    description: "AST-based structural code search using tree-sitter"
  },
  package: %{
    module: Singularity.Search.Searchers.PackageSearch,
    enabled: true,
    description: "Package registry search combined with RAG codebase discovery"
  }

# =============================================================================
# Job Configuration (Config-Driven)
# =============================================================================
# Defines which background jobs (Oban workers) are enabled and their configuration

config :singularity, :job_types,
  metrics_aggregation: %{
    module: Singularity.Jobs.MetricsAggregationWorker,
    enabled: true,
    queue: :default,
    max_attempts: 2,
    description: "Aggregate agent metrics for feedback loop (every 5 minutes)"
  },
  pattern_miner: %{
    module: Singularity.Jobs.PatternMinerJob,
    enabled: true,
    queue: :pattern_mining,
    max_attempts: 3,
    priority: 2,
    description: "Mine code patterns from codebase (daily)"
  },
  agent_evolution: %{
    module: Singularity.Jobs.AgentEvolutionWorker,
    enabled: true,
    queue: :default,
    max_attempts: 2,
    description: "Apply agent improvements (hourly)"
  },
  cache_refresh: %{
    module: Singularity.Jobs.CacheRefreshWorker,
    enabled: true,
    queue: :maintenance,
    max_attempts: 1,
    description: "Refresh embedding cache (every 30 minutes)"
  },
  cache_cleanup: %{
    module: Singularity.Jobs.CacheCleanupWorker,
    enabled: true,
    queue: :maintenance,
    max_attempts: 1,
    description: "Clean old cache entries (every 4 hours)"
  },
  cache_prewarm: %{
    module: Singularity.Jobs.CachePrewarmWorker,
    enabled: false,
    queue: :maintenance,
    max_attempts: 1,
    description: "Pre-warm frequently used models (hourly)"
  },
  cache_maintenance: %{
    module: Singularity.Jobs.CacheMaintenanceJob,
    enabled: true,
    queue: :maintenance,
    max_attempts: 1,
    description: "Cache maintenance tasks (hourly)"
  },
  feedback_analysis: %{
    module: Singularity.Jobs.FeedbackAnalysisWorker,
    enabled: true,
    queue: :default,
    max_attempts: 2,
    description: "Analyze agent feedback (every 30 minutes)"
  },
  pattern_sync: %{
    module: Singularity.Jobs.PatternSyncWorker,
    enabled: true,
    queue: :default,
    max_attempts: 2,
    description: "Sync patterns to DB (hourly)"
  },
  pattern_sync_job: %{
    module: Singularity.Jobs.PatternSyncJob,
    enabled: false,
    queue: :pattern_mining,
    max_attempts: 2,
    description: "Full pattern sync (daily)"
  },
  domain_vocabulary_trainer: %{
    module: Singularity.Jobs.DomainVocabularyTrainerJob,
    enabled: true,
    queue: :training,
    max_attempts: 1,
    description: "Train domain vocabulary (daily)"
  },
  embedding_finetune: %{
    module: Singularity.Jobs.EmbeddingFinetuneJob,
    enabled: false,
    queue: :training,
    max_attempts: 1,
    description: "Fine-tune embeddings (nightly)"
  },
  knowledge_export: %{
    module: Singularity.Jobs.KnowledgeExportWorker,
    enabled: true,
    queue: :default,
    max_attempts: 2,
    description: "Export knowledge to Git (weekly)"
  },
  dead_code_daily_check: %{
    module: Singularity.Jobs.DeadCodeDailyCheck,
    enabled: true,
    queue: :default,
    max_attempts: 2,
    description: "Check dead code (daily)"
  },
  dead_code_weekly_summary: %{
    module: Singularity.Jobs.DeadCodeWeeklySummary,
    enabled: true,
    queue: :default,
    max_attempts: 2,
    description: "Dead code summary (weekly)"
  },
  train_t5_model: %{
    module: Singularity.Jobs.TrainT5ModelJob,
    enabled: false,
    queue: :training,
    max_attempts: 1,
    description: "Train T5 model (on demand)"
  }

# Config-Driven Validation System
# Unified validator orchestration with priority-ordered execution
config :singularity, :validators,
  type_checker: %{
    module: Singularity.Validators.TypeChecker,
    enabled: true,
    priority: 10,
    description: "Validates type specifications and type safety"
  },
  security_validator: %{
    module: Singularity.Validators.SecurityValidator,
    enabled: true,
    priority: 15,
    description: "Enforces security policies and access control"
  },
  schema_validator: %{
    module: Singularity.Validators.SchemaValidator,
    enabled: true,
    priority: 20,
    description: "Validates data structures against schema templates"
  }

# Config-Driven Build Tool System
# Unified build tool orchestration with priority-ordered execution
config :singularity, :build_tools,
  bazel: %{
    module: Singularity.BuildTools.BazelTool,
    enabled: true,
    priority: 10,
    description: "Bazel build system integration"
  },
  nx: %{
    module: Singularity.BuildTools.NxTool,
    enabled: true,
    priority: 20,
    description: "NX monorepo build system"
  },
  moon: %{
    module: Singularity.BuildTools.MoonTool,
    enabled: true,
    priority: 30,
    description: "Moon build orchestration"
  }

# Config-Driven Execution Strategy System
# Unified execution strategy orchestration with priority-ordered execution
config :singularity, :execution_strategies,
  task_dag: %{
    module: Singularity.ExecutionStrategies.TaskDagStrategy,
    enabled: true,
    priority: 10,
    description: "Task DAG based execution with dependency tracking"
  },
  sparc: %{
    module: Singularity.ExecutionStrategies.SparcStrategy,
    enabled: true,
    priority: 20,
    description: "SPARC template-driven execution"
  },
  methodology: %{
    module: Singularity.ExecutionStrategies.MethodologyStrategy,
    enabled: true,
    priority: 30,
    description: "Methodology-based execution (SAFe, etc.)"
  }

# Config-Driven Task Execution System
# Unified task adapter orchestration with priority-ordered execution
config :singularity, :task_adapters,
  oban_adapter: %{
    module: Singularity.Adapters.ObanAdapter,
    enabled: true,
    priority: 10,
    description: "Background job execution via Oban"
  },
  genserver_adapter: %{
    module: Singularity.Adapters.GenServerAdapter,
    enabled: true,
    priority: 20,
    description: "Synchronous task execution via GenServer agents"
  }

# Config-Driven Workflow Registry System
# Centralized workflow definitions for pgflow and RCA integration
config :singularity, :workflows,
  registry: [
    # Pipeline workflows
    agent_improvement: Singularity.Workflows.AgentImprovementWorkflow,
    architecture_learning: Singularity.Workflows.ArchitectureLearningWorkflow,
    code_metrics: Singularity.Workflows.CodeMetricsWorkflow,
    code_quality_training: Singularity.Workflows.CodeQualityTrainingWorkflow,
    embedding_training: Singularity.Workflows.EmbeddingTrainingWorkflow,

    # System workflows
    centralcloud_sync: Singularity.Workflows.CentralCloudSyncWorkflow,
    codebase_registry_sync: Singularity.Workflows.CodebaseRegistrySyncWorkflow,
    database_tool_execution: Singularity.Workflows.DatabaseToolExecutionWorkflow,
    dead_code_report: Singularity.Workflows.DeadCodeReportWorkflow,
    deduplication: Singularity.Workflows.DeduplicationWorkflow,
    genesis_experiment_request: Singularity.Workflows.GenesisExperimentRequestWorkflow,
    rca: Singularity.Workflows.RcaWorkflow,
    system_event_broadcast: Singularity.Workflows.SystemEventBroadcastWorkflow
  ],
  # Workflow type aliases for convenience
  aliases: [
    quality: :code_quality_training,
    architecture: :architecture_learning,
    embedding: :embedding_training,
    rca_base: :rca,
    sync: :centralcloud_sync
  ]
