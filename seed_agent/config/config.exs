import Config

config :seed_agent,
  namespace: SeedAgent

config :seed_agent, SeedAgent.Telemetry,
  metrics: []

config :logger, level: :info

config :libcluster,
  topologies: []

config :seed_agent, :claude,
  default_model: System.get_env("CLAUDE_DEFAULT_MODEL", "sonnet"),
  cli_path: System.get_env("CLAUDE_CLI_PATH"),
  home: System.get_env("CLAUDE_HOME"),
  cli_flags: String.split(System.get_env("CLAUDE_CLI_FLAGS", ""), " ", trim: true)

import_config "#{config_env()}.exs"
