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

# Test Oban Configuration
# Run jobs inline for deterministic testing
config :oban, testing: :inline

# Test Quantum Configuration
# Disable Quantum scheduler during tests to avoid side effects
config :singularity, Singularity.Scheduler, debug: false

# Test NATS Configuration
# Disable NATS for unit tests to avoid connectivity requirements
config :singularity, :nats, enabled: false
