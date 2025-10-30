import Config

config :logger, level: :debug

# HTTP server configuration (if needed)
# config :singularity, :http_server,
#   port: 4000

config :libcluster,
  topologies: []

config :singularity, :http_server_enabled, true

# Enable HTDAG Auto-Bootstrap for automatic code ingestion
config :singularity, Singularity.Execution.Planning.HTDAGAutoBootstrap,
  enabled: true,
  max_iterations: 10,
  fix_on_startup: true,
  notify_on_complete: true,
  run_async: true,
  cooldown_ms: 300_000,
  fix_severity: :medium,
  use_rag: true,
  use_quality_templates: true,
  integrate_sparc: true,
  safe_planning: true

config :singularity, Singularity.Repo, database: "singularity"

# Development Oban Configuration
# Run jobs inline for easier debugging
config :oban, testing: :inline

# =============================================================================
# BEAM Debugging Configuration
# =============================================================================

# Enable Erlang debugger (graphical debugger)
# Start with: :debugger.start()
config :singularity, :enable_debugger, false

# Enable IEx breakpoints and debugging helpers
# Insert breakpoints with: require Debug; Debug.pry()
config :iex, :colors, enabled: true

# Enable verbose error messages and stack traces
config :logger,
  level: :debug,
  compile_time_purge_matching: [],
  backends: [:console]

# SASL Configuration for Development
# Log to console in development for easier debugging
config :sasl,
  sasl_error_logger: :tty,
  errlog_type: :progress,
  utc_log: true
