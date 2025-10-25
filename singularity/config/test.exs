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

# Disable Oban in tests - it's not needed and causes initialization issues
config :singularity, :oban_enabled, false

# Oban configuration for test mode
# Using `testing: :inline` prevents Oban from trying to connect to the database
# The dispatcher runs jobs immediately in the same process instead of enqueueing them
# NOTE: Even though oban_enabled is false above, we still provide config for if it's explicitly started
config :oban,
  engine: Oban.Engines.Inline,
  queues: [],
  repo: Singularity.Repo
