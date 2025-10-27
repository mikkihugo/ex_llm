defmodule Singularity.Execution.Orchestrator.ExecutionStrategy do
  @moduledoc """
  Execution Strategy Behavior - Contract for all execution strategies.

  Defines the unified interface for execution strategies (TaskDAG, SPARC, Methodology, etc.)
  enabling config-driven orchestration of different execution patterns.

  Consolidates scattered execution strategies into a flexible behavior-based system.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Execution.Orchestrator.ExecutionStrategy",
    "purpose": "Behavior contract for config-driven execution strategy orchestration",
    "type": "behavior/protocol",
    "layer": "execution",
    "location": "lib/singularity/execution/orchestrator/execution_strategy.ex",
    "status": "production"
  }
  ```

  ## Configuration Example

  ```elixir
  # singularity/config/config.exs
  config :singularity, :execution_strategies,
    task_dag: %{
      module: Singularity.ExecutionStrategies.TaskDagStrategy,
      enabled: true,
      priority: 10,
      description: "Task DAG based execution with dependency tracking"
    },
    sparc: %{
      module: Singularity.ExecutionStrategies.SparcStrategy,
      enabled: true,
      priority: 20,
      description: "SPARC template-driven execution"
    },
    methodology: %{
      module: Singularity.ExecutionStrategies.MethodologyStrategy,
      enabled: true,
      priority: 30,
      description: "Methodology-based execution (SAFe, etc.)"
    }
  ```
  """

  require Logger

  @doc """
  Returns the atom identifier for this execution strategy.

  Examples: `:task_dag`, `:sparc`, `:methodology`
  """
  @callback strategy_type() :: atom()

  @doc """
  Returns human-readable description of this strategy.
  """
  @callback description() :: String.t()

  @doc """
  Returns list of capabilities this strategy provides.

  Examples: `["parallel", "dependency_tracking", "distributed"]`
  """
  @callback capabilities() :: [String.t()]

  @doc """
  Check if this strategy is applicable for the given goal.

  Returns:
  - `true` if this strategy can handle the goal
  - `false` if this strategy is not applicable
  """
  @callback applicable?(goal :: term()) :: boolean()

  @doc """
  Execute a goal using this strategy.

  Returns:
  - `{:ok, result}` on success
  - `{:error, reason}` on failure
  """
  @callback execute(goal :: term(), _opts :: Keyword.t()) ::
              {:ok, term()} | {:error, term()}

  # Config loading helpers

  @doc """
  Load all enabled execution strategies from config, sorted by priority (ascending).

  Returns: `[{strategy_type, priority, config_map}, ...]` in priority order
  """
  def load_enabled_strategies do
    :singularity
    |> Application.get_env(:execution_strategies, %{})
    |> Enum.filter(fn {_type, config} -> config[:enabled] == true end)
    |> Enum.map(fn {type, config} -> {type, config[:priority] || 100, config} end)
    |> Enum.sort_by(fn {_type, priority, _config} -> priority end)
  end

  @doc """
  Check if a specific execution strategy is enabled.
  """
  def enabled?(strategy_type) when is_atom(strategy_type) do
    strategies = load_enabled_strategies()
    Enum.any?(strategies, fn {type, _priority, _config} -> type == strategy_type end)
  end

  @doc """
  Get the module implementing a specific execution strategy.
  """
  def get_strategy_module(strategy_type) when is_atom(strategy_type) do
    case Application.get_env(:singularity, :execution_strategies, %{})[strategy_type] do
      %{module: module} -> {:ok, module}
      nil -> {:error, :strategy_not_configured}
      _ -> {:error, :invalid_config}
    end
  end

  @doc """
  Get priority for a specific execution strategy (lower numbers try first).

  Defaults to 100 if not specified.
  """
  def get_priority(strategy_type) when is_atom(strategy_type) do
    case Application.get_env(:singularity, :execution_strategies, %{})[strategy_type] do
      %{priority: priority} -> priority
      _ -> 100
    end
  end

  @doc """
  Get description for a specific execution strategy.
  """
  def get_description(strategy_type) when is_atom(strategy_type) do
    case get_strategy_module(strategy_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) do
          module.description()
        else
          "Unknown strategy"
        end

      {:error, _} ->
        "Unknown strategy"
    end
  end
end
