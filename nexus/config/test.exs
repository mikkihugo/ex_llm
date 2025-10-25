import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used to provide built-in test
# partitioning in CI environment. When your CI assigns a value to the
# MIX_TEST_PARTITION an only the tests tagged with the same test partition
# will run.
config :nexus, NexusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test-secret-key-do-not-use-in-production-64-char-minimum-ok-yes",
  server: false

# Disable logger output for tests
config :logger, level: :warning
