import Config

# Development configuration
config :nexus, Nexus.Repo,
  database: "nexus_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Print SQL queries in development
config :logger, :console, format: "[$level] $message\n"
