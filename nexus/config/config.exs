import Config

# Helper function for auto-detecting redirect URI
defmodule Nexus.ConfigHelpers do
  def build_redirect_uri do
    port = System.get_env("PORT", "4000")
    hostname = detect_hostname()
    scheme = if System.get_env("HTTPS") == "true", do: "https", else: "http"
    "#{scheme}://#{hostname}:#{port}/auth/codex/callback"
  end

  defp detect_hostname do
    case System.get_env("HOSTNAME") do
      nil ->
        case :inet.gethostname() do
          {:ok, h} -> List.to_string(h)
          _ -> System.get_env("COMPUTERNAME") || "localhost"
        end

      hostname ->
        hostname
    end
  end
end

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
    System.get_env("CODEX_REDIRECT_URI") ||
      Nexus.ConfigHelpers.build_redirect_uri(),
  scopes: ["openai.user.read", "model.request", "model.read"]

# Gemini Code Assist configuration
config :nexus, :gemini_code,
  project_id: System.get_env("GEMINI_CODE_PROJECT"),
  default_model: System.get_env("GEMINI_CODE_DEFAULT_MODEL") || "models/gemini-2.5-pro"

# Import environment-specific config
import_config "#{config_env()}.exs"
