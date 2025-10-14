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
