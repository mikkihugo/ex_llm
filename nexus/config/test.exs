import Config

# Test configuration
config :nexus, Nexus.Repo,
  database:
    System.get_env(
      "NEXUS_TEST_DATABASE",
      "singularity_test#{System.get_env("MIX_TEST_PARTITION")}"
    ),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Print only warnings and errors during test
config :logger, level: :warning
