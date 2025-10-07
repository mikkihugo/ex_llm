import Config

config :singularity,
  namespace: Singularity

config :singularity, Singularity.Telemetry, metrics: []

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

config :singularity, :git_coordinator,
  enabled:
    System.get_env("GIT_COORDINATOR_ENABLED", "false")
    |> String.downcase()
    |> (&(&1 in ["1", "true", "yes"])).(),
  repo_path: System.get_env("GIT_COORDINATOR_REPO_PATH"),
  base_branch: System.get_env("GIT_COORDINATOR_BASE_BRANCH", "main"),
  remote: System.get_env("GIT_COORDINATOR_REMOTE")

# Claude CLI Recovery Configuration
# Uses dedicated recovery binary: ~/.singularity/emergency/bin/claude-recovery
# Named "claude-recovery" to avoid collision with NPM Claude SDK
# Install with: ./scripts/install_claude_native.sh
emergency_claude_path =
  Path.expand(System.get_env("SINGULARITY_EMERGENCY_BIN") || "~/.singularity/emergency/bin")
  |> Path.join("claude-recovery")

config :singularity, :claude,
  default_model: System.get_env("CLAUDE_DEFAULT_MODEL", "sonnet"),
  cli_path: System.get_env("CLAUDE_CLI_PATH") || emergency_claude_path,
  home: System.get_env("CLAUDE_HOME"),
  cli_flags: String.split(System.get_env("CLAUDE_CLI_FLAGS", ""), " ", trim: true),
  default_profile: :safe,
  profiles: %{
    safe: %{
      description: "Read-only CLI usage with permissions intact",
      claude_flags: [],
      dangerous: false,
      allowed_tools: [],
      disallowed_tools: ["FilesystemEdit", "BashEdit"]
    },
    write: %{
      description: "Allow filesystem edits and dangerous operations",
      claude_flags: ["--dangerously-skip-permissions"],
      dangerous: true,
      allowed_tools: [],
      disallowed_tools: []
    }
  }

import_config "#{config_env()}.exs"

config :singularity, Singularity.Repo,
  # Single shared DB
  database: System.get_env("SINGULARITY_DB_NAME", "singularity"),
  username: System.get_env("SINGULARITY_DB_USER") || System.get_env("USER") || "postgres",
  password: System.get_env("SINGULARITY_DB_PASSWORD", ""),
  hostname: System.get_env("SINGULARITY_DB_HOST", "localhost"),
  port: String.to_integer(System.get_env("SINGULARITY_DB_PORT", "5432")),
  pool_size: String.to_integer(System.get_env("SINGULARITY_DB_POOL", "10"))

config :singularity, ecto_repos: [Singularity.Repo]
