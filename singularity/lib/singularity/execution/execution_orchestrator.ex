defmodule Singularity.Execution.ExecutionOrchestrator do
  @moduledoc """
  Execution Orchestrator - Unified strategy-based code execution.

  Consolidates scattered executors (TaskGraphExecutor, SPARC.Orchestrator,
  MethodologyExecutor, etc.) into a single, strategy-based execution system.

  Supports multiple execution patterns:
  - Task DAGs (dependency graphs)
  - SPARC execution (template-driven)
  - Methodology execution (SAFe, etc.)

  ## Usage

  ```elixir
  # Execute with automatic strategy detection
  {:ok, results} = ExecutionOrchestrator.execute(goal)

  # Execute with specific strategy
  {:ok, results} = ExecutionOrchestrator.execute(
    goal,
    strategy: :task_dag,
    opts: [timeout: 30000, parallel: true]
  )
  ```
  """

  require Logger
  alias Singularity.Execution.ExecutionStrategyOrchestrator

  @doc """
  Execute code or tasks using unified orchestration.

  Delegates to ExecutionStrategyOrchestrator for strategy routing based on
  configuration. Automatically detects or uses specified strategy for execution.

  ## Options

  - `:strategy` - Specific execution strategy to use (optional, will auto-detect if not provided)
  - `:timeout` - Execution timeout in milliseconds (default: 60000)
  - `:strategies` - List of strategies to try (default: all enabled strategies in priority order)

  ## Returns

  Returns result from selected strategy or error tuple.

  ## Examples

      ExecutionOrchestrator.execute(%{tasks: [...]})
      # => {:ok, results}

      ExecutionOrchestrator.execute(goal, strategy: :sparc)
      # => {:ok, results}
  """
  def execute(goal, opts \\ []) when is_map(goal) or is_binary(goal) do
    timeout = Keyword.get(opts, :timeout, 60000)

    Logger.info("ExecutionOrchestrator: Routing goal to execution strategy",
      goal: inspect(goal),
      timeout: timeout
    )

    # Delegate to ExecutionStrategyOrchestrator for config-driven routing
    ExecutionStrategyOrchestrator.execute(goal, Keyword.put(opts, :timeout, timeout))
  end

  @doc """
  Get information about all configured execution strategies.

  Returns list of available strategies with their capabilities and priorities.
  """
  def get_strategies_info do
    ExecutionStrategyOrchestrator.get_strategies_info()
  end
end
