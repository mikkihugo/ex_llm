import Config

# Configure logger
config :logger, :console,
  format: "[$level] $message\n"

# Configure eex for live view templates
config :eex,
  autoescape: true

# NATS client configuration
config :gnat,
  host: {:system, "NATS_HOST", "127.0.0.1"},
  port: {:system, "NATS_PORT", 4222}

# Import environment specific config
import_config "#{Mix.env()}.exs"
