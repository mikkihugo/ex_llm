# Singularity GitHub App Configuration

# GitHub App Settings (from GitHub App registration)
config :singularity, :github_app,
  app_id: System.get_env("GITHUB_APP_ID"),
  private_key: System.get_env("GITHUB_PRIVATE_KEY"),
  webhook_secret: System.get_env("GITHUB_WEBHOOK_SECRET"),
  client_id: System.get_env("GITHUB_CLIENT_ID"),
  client_secret: System.get_env("GITHUB_CLIENT_SECRET")

# Database
config :singularity, Singularity.Repo,
  username: System.get_env("DATABASE_USERNAME", "postgres"),
  password: System.get_env("DATABASE_PASSWORD", "postgres"),
  database: System.get_env("DATABASE_NAME", "singularity_dev"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  port: System.get_env("DATABASE_PORT", "5432") |> String.to_integer(),
  pool_size: System.get_env("DATABASE_POOL_SIZE", "10") |> String.to_integer()

# Redis (for caching and queues)
config :singularity, :redis,
  host: System.get_env("REDIS_HOST", "localhost"),
  port: System.get_env("REDIS_PORT", "6379") |> String.to_integer(),
  password: System.get_env("REDIS_PASSWORD"),
  database: System.get_env("REDIS_DATABASE", "0") |> String.to_integer()

# Analysis Engine
config :singularity, :analysis,
  rust_engine_path: System.get_env("RUST_ENGINE_PATH", "./code_quality_engine"),
  timeout_seconds: System.get_env("ANALYSIS_TIMEOUT", "300") |> String.to_integer(),
  max_concurrent_analyses: System.get_env("MAX_CONCURRENT_ANALYSES", "5") |> String.to_integer()

# Intelligence Collection (opt-in)
config :singularity, :intelligence,
  enabled: System.get_env("INTELLIGENCE_ENABLED", "false") == "true",
  anonymize_data: System.get_env("ANONYMIZE_DATA", "true") == "true",
  collection_rate: System.get_env("INTELLIGENCE_COLLECTION_RATE", "0.1") |> String.to_float()

# Web Server
config :singularity, SingularityWeb.Endpoint,
  http: [
    port: System.get_env("PORT", "4000") |> String.to_integer()
  ],
  url: [
    host: System.get_env("HOST", "localhost"),
    port: System.get_env("PORT", "4000") |> String.to_integer()
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# ex_pgflow Configuration
config :singularity, :workflows,
  pgmq_host: System.get_env("PGMQ_HOST", "localhost"),
  pgmq_port: System.get_env("PGMQ_PORT", "5432") |> String.to_integer(),
  pgmq_database: System.get_env("PGMQ_DATABASE", "singularity_dev"),
  pgmq_username: System.get_env("PGMQ_USERNAME", "postgres"),
  pgmq_password: System.get_env("PGMQ_PASSWORD", "postgres")

# Logging
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config
import_config "#{Mix.env()}.exs"