import Config

# Database configuration for Nexus
config :nexus, Nexus.Repo,
  database: System.get_env("NEXUS_DB_NAME") || "nexus_dev",
  username: System.get_env("NEXUS_DB_USER") || "postgres",
  password: System.get_env("NEXUS_DB_PASSWORD") || "",
  hostname: System.get_env("NEXUS_DB_HOST") || "localhost",
  pool_size: String.to_integer(System.get_env("NEXUS_DB_POOL_SIZE") || "10")

config :nexus, ecto_repos: [Nexus.Repo]

# Codex (ChatGPT Pro) OAuth2 configuration
config :nexus, :codex,
  # OAuth2 credentials (from ChatGPT Developer Portal)
  # Get these from: https://platform.openai.com/account/api-keys (NOT the pay-per-use API!)
  # This should be the OAuth app credentials for ChatGPT Plus/Pro
  client_id: System.get_env("CODEX_CLIENT_ID"),
  client_secret: System.get_env("CODEX_CLIENT_SECRET"),
  redirect_uri:
    System.get_env("CODEX_REDIRECT_URI") || "http://localhost:4000/auth/codex/callback",
  scopes: ["openai.user.read", "model.request", "model.read"]

# Gemini Code Assist configuration
config :nexus, :gemini_code,
  project_id: System.get_env("GEMINI_CODE_PROJECT"),
  default_model: System.get_env("GEMINI_CODE_DEFAULT_MODEL") || "models/gemini-2.5-pro"

# Import environment-specific config
import_config "#{config_env()}.exs"
