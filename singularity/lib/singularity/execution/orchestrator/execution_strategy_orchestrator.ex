defmodule Singularity.Execution.Orchestrator.ExecutionStrategyOrchestrator do
  @moduledoc """
  Execution Strategy Orchestrator - Config-driven orchestration of execution strategies.

  Routes execution goals to first-applicable-match execution strategy based on goal type
  and strategy capabilities (TaskDAG, SPARC, Methodology, etc.).

  ## Usage

  ```elixir
  ExecutionStrategyOrchestrator.execute(goal)
  # => {:ok, result}

  ExecutionStrategyOrchestrator.get_strategies_info()
  # => [%{name: :task_dag, ...}, ...]
  ```
  """

  require Logger
  alias Singularity.Execution.Orchestrator.ExecutionStrategy

  @doc """
  Execute a goal with automatic strategy detection.

  Tries execution strategies in priority order until one succeeds.
  """
  def execute(goal, _opts \\ []) when is_map(goal) or is_binary(goal) do
    try do
      strategies = load_strategies_for_attempt(_opts)

      Logger.info("ExecutionStrategyOrchestrator: Executing goal", goal: inspect(goal))

      case try_strategies(strategies, goal, _opts) do
        {:ok, result} ->
          Logger.info("Goal executed successfully")
          {:ok, result}

        {:error, :no_strategy_found} ->
          Logger.warning("No applicable execution strategy found")
          {:error, :no_strategy_found}

        error ->
          error
      end
    rescue
      e ->
        Logger.error("Execution orchestration failed", error: inspect(e))
        {:error, :execution_failed}
    end
  end

  @doc """
  Get information about all configured execution strategies.
  """
  def get_strategies_info do
    ExecutionStrategy.load_enabled_strategies()
    |> Enum.map(fn {type, priority, config} ->
      description = ExecutionStrategy.get_description(type)

      %{
        name: type,
        enabled: true,
        priority: priority,
        description: description,
        module: config[:module],
        capabilities: get_capabilities(type)
      }
    end)
  end

  @doc """
  Get capabilities for a specific execution strategy.
  """
  def get_capabilities(strategy_type) when is_atom(strategy_type) do
    case ExecutionStrategy.get_strategy_module(strategy_type) do
      {:ok, module} ->
        if Code.ensure_loaded?(module) && function_exported?(module, :capabilities, 0) do
          module.capabilities()
        else
          []
        end

      {:error, _} ->
        []
    end
  end

  # Private helpers

  defp load_strategies_for_attempt(opts) do
    case Keyword.get(opts, :strategies) do
      nil -> ExecutionStrategy.load_enabled_strategies()
      specific_strategies -> filter_strategies(specific_strategies)
    end
  end

  defp filter_strategies(specific_strategies) when is_list(specific_strategies) do
    all_strategies = ExecutionStrategy.load_enabled_strategies()

    Enum.filter(all_strategies, fn {type, _priority, _config} ->
      type in specific_strategies
    end)
  end

  defp try_strategies([], _goal, _opts) do
    {:error, :no_strategy_found}
  end

  defp try_strategies([{strategy_type, _priority, config} | rest], goal, _opts) do
    try do
      module = config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Trying #{strategy_type} execution strategy")

        case module.applicable?(goal) do
          true ->
            case module.execute(goal, _opts) do
              {:ok, result} ->
                Logger.info("Execution succeeded with #{strategy_type}")
                {:ok, result}

              {:error, reason} ->
                Logger.error("#{strategy_type} execution failed", reason: inspect(reason))
                {:error, reason}
            end

          false ->
            Logger.debug("#{strategy_type} not applicable")
            try_strategies(rest, goal, _opts)
        end
      else
        Logger.warning("Strategy module not found for #{strategy_type}")
        try_strategies(rest, goal, _opts)
      end
    rescue
      e ->
        Logger.error("Strategy execution failed for #{strategy_type}", error: inspect(e))
        try_strategies(rest, goal, _opts)
    end
  end
end
