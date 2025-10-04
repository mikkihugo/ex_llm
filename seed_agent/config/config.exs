import Config

config :seed_agent,
  namespace: SeedAgent

config :seed_agent, SeedAgent.Telemetry, metrics: []

config :logger, level: :info

config :logger,
  compile_time_purge_matching: [
    [level: :debug],
    [level: :info],
    [level: :warning],
    [level: :error]
  ]

config :libcluster,
  topologies: []

# Claude CLI Recovery Configuration
# Uses dedicated recovery binary: ~/.singularity/emergency/bin/claude-recovery
# Named "claude-recovery" to avoid collision with NPM Claude SDK
# Install with: ./scripts/install_claude_native.sh
emergency_claude_path =
  Path.expand(System.get_env("SINGULARITY_EMERGENCY_BIN") || "~/.singularity/emergency/bin")
  |> Path.join("claude-recovery")

config :seed_agent, :claude,
  default_model: System.get_env("CLAUDE_DEFAULT_MODEL", "sonnet"),
  cli_path: System.get_env("CLAUDE_CLI_PATH") || emergency_claude_path,
  home: System.get_env("CLAUDE_HOME"),
  cli_flags: String.split(System.get_env("CLAUDE_CLI_FLAGS", ""), " ", trim: true)

import_config "#{config_env()}.exs"
