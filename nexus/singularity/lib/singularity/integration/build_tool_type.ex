defmodule Singularity.Integration.BuildToolType do
  @moduledoc """
  Build Tool Type Behavior - Contract for all build tool strategies.

  Defines the unified interface for build tool integrations (Bazel, NX, Moon, etc.)
  enabling config-driven orchestration of build automation across different tools.

  Consolidates hardcoded build tool functions into a flexible behavior-based system.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Integration.BuildToolType",
    "purpose": "Behavior contract for config-driven build tool orchestration",
    "type": "behavior/protocol",
    "layer": "integration",
    "status": "production"
  }
  ```

  ## Configuration Example

  ```elixir
  # singularity/config/config.exs
  config :singularity, :build_tools,
    bazel: %{
      module: Singularity.BuildTools.BazelTool,
      enabled: true,
      priority: 10,
      description: "Bazel build system integration"
    },
    nx: %{
      module: Singularity.BuildTools.NxTool,
      enabled: true,
      priority: 20,
      description: "NX monorepo build system"
    },
    moon: %{
      module: Singularity.BuildTools.MoonTool,
      enabled: true,
      priority: 30,
      description: "Moon build orchestration"
    }
  ```

  ## How Build Tools Work

  1. **Orchestrator loads build tools from config** (sorted by priority)
  2. **For each build command**:
     - Try each tool in priority order
     - If tool applicable → Execute build command
     - If not applicable → Try next tool
  3. **Return result** with build output and status
  """

  require Logger

  @doc """
  Returns the atom identifier for this build tool.

  Examples: `:bazel`, `:nx`, `:moon`
  """
  @callback tool_type() :: atom()

  @doc """
  Returns human-readable description of this build tool.
  """
  @callback description() :: String.t()

  @doc """
  Returns list of capabilities this tool provides.

  Examples: `["monorepo", "caching", "parallel_builds"]`
  """
  @callback capabilities() :: [String.t()]

  @doc """
  Detect if this build tool is applicable for the given project.

  Returns:
  - `true` if this tool should be used
  - `false` if this tool is not applicable
  """
  @callback applicable?(project_path :: String.t()) :: boolean()

  @doc """
  Run build command using this tool.

  Returns:
  - `{:ok, %{output: String.t(), status: 0}}` on success
  - `{:error, reason}` on failure
  """
  @callback run_build(project_path :: String.t(), opts :: Keyword.t()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Run specific target using this tool.

  Returns:
  - `{:ok, %{output: String.t(), status: 0}}` on success
  - `{:error, reason}` on failure
  """
  @callback run_target(target :: String.t(), opts :: Keyword.t()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Clean build artifacts using this tool.

  Returns:
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  @callback clean_build(project_path :: String.t()) :: :ok | {:error, term()}

  # Config loading helpers

  @doc """
  Load all enabled build tools from config, sorted by priority (ascending).

  Returns: `[{tool_type, priority, config_map}, ...]` in priority order
  """
  def load_enabled_tools do
    :singularity
    |> Application.get_env(:build_tools, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.map(fn {type, config} -> {type, config[:priority] || 100, config} end)
    |> Enum.sort_by(fn {_type, priority, _config} -> priority end)
  end

  @doc """
  Check if a specific build tool is enabled.
  """
  def enabled?(tool_type) when is_atom(tool_type) do
    tools = load_enabled_tools()
    Enum.any?(tools, fn {type, _priority, _config} -> type == tool_type end)
  end

  @doc """
  Get the module implementing a specific build tool.
  """
  def get_tool_module(tool_type) when is_atom(tool_type) do
    case Application.get_env(:singularity, :build_tools, %{})[tool_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :tool_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get priority for a specific build tool (lower numbers try first).

  Defaults to 100 if not specified.
  """
  def get_priority(tool_type) when is_atom(tool_type) do
    case Application.get_env(:singularity, :build_tools, %{})[tool_type] do
      %{priority: priority} -> priority
      _ -> 100
    end
  end

  @doc """
  Get description for a specific build tool.
  """
  def get_description(tool_type) when is_atom(tool_type) do
    case get_tool_module(tool_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown build tool"
        end

      {:error, _} ->
        "Unknown build tool"
    end
  end
end
