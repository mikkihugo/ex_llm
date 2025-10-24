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

  @doc """
  Execute code or tasks using unified orchestration.

  Automatically detects or uses specified strategy for execution.

  ## Options

  - `:strategy` - Execution strategy: `:task_dag`, `:sparc`, `:methodology`
  - `:timeout` - Execution timeout in milliseconds (default: 60000)
  - `:parallel` - Allow parallel execution (default: true)

  ## Returns

  `{:ok, results}` or `{:error, reason}`
  """
  def execute(goal, opts \\ []) when is_map(goal) or is_binary(goal) do
    try do
      strategy = Keyword.get(opts, :strategy, :auto)
      timeout = Keyword.get(opts, :timeout, 60000)
      parallel = Keyword.get(opts, :parallel, true)

      Logger.info("Executing with orchestrator",
        strategy: strategy,
        timeout: timeout,
        parallel: parallel
      )

      case strategy do
        :task_dag -> execute_task_dag(goal, opts, timeout)
        :sparc -> execute_sparc(goal, opts, timeout)
        :methodology -> execute_methodology(goal, opts, timeout)
        :auto -> detect_and_execute(goal, opts, timeout)
        _ -> {:error, :unknown_strategy}
      end
    rescue
      e ->
        Logger.error("Execution failed", error: inspect(e))
        {:error, :execution_failed}
    end
  end

  # Private helpers

  defp execute_task_dag(goal, _opts, timeout) do
    try do
      if Code.ensure_loaded?(Singularity.Execution.TaskGraph.Executor) do
        Singularity.Execution.TaskGraph.Executor.execute(goal, timeout: timeout)
      else
        {:error, :executor_not_available}
      end
    rescue
      _ -> {:error, :task_dag_execution_failed}
    end
  end

  defp execute_sparc(goal, _opts, timeout) do
    try do
      if Code.ensure_loaded?(Singularity.Execution.SPARC.Orchestrator) do
        Singularity.Execution.SPARC.Orchestrator.execute(goal, timeout: timeout)
      else
        {:error, :orchestrator_not_available}
      end
    rescue
      _ -> {:error, :sparc_execution_failed}
    end
  end

  defp execute_methodology(goal, _opts, timeout) do
    try do
      if Code.ensure_loaded?(Singularity.Execution.MethodologyExecutor) do
        Singularity.Execution.MethodologyExecutor.execute(goal, timeout: timeout)
      else
        {:error, :executor_not_available}
      end
    rescue
      _ -> {:error, :methodology_execution_failed}
    end
  end

  defp detect_and_execute(goal, opts, timeout) do
    # Attempt to detect appropriate strategy based on goal structure
    cond do
      # Has task dependencies -> use task DAG
      is_map(goal) and Map.has_key?(goal, :tasks) ->
        execute_task_dag(goal, opts, timeout)

      # Has template -> use SPARC
      is_map(goal) and Map.has_key?(goal, :template) ->
        execute_sparc(goal, opts, timeout)

      # Default to task DAG
      true ->
        execute_task_dag(goal, opts, timeout)
    end
  end
end
