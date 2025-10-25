import Config

# For development, we disable any cache and enable debugging and code reloading.
#
# The watchers configuration can be used to run external watchers to your
# application. For example, we use it with esbuild to bundle .js and .css
# sources.
config :nexus, NexusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev-secret-key-do-not-use-in-production-64-char-minimum-ok-yes"

# Configure logger
config :logger, level: :debug
