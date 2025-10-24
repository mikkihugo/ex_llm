import Config

config :singularity, :git_coordinator, enabled: false

config :singularity, SingularityWeb.Endpoint,
  http: [port: 5001],
  server: false

config :logger, level: :warning

config :singularity, :http_server_enabled, false

config :singularity, Singularity.Repo,
  # Shared DB, sandboxed for tests
  database: "singularity",
  pool: Ecto.Adapters.SQL.Sandbox

# Disable Oban in tests (not needed, can cause configuration issues)
config :singularity, :oban_enabled, false

# Still need to provide valid Oban config even though we skip it in supervision tree
# Use testing mode for inline job execution if Oban somehow tries to start
config :oban, testing: :inline

# Test Quantum Configuration
# Disable Quantum scheduler during tests to avoid side effects
config :singularity, Singularity.Scheduler, debug: false

# Test NATS Configuration
# Disable NATS for unit tests to avoid connectivity requirements
config :singularity, :nats, enabled: false
