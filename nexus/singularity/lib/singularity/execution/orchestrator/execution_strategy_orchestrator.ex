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
  alias Singularity.LLM.Config

  @doc """
  Execute a goal with automatic strategy detection.

  Tries execution strategies in priority order until one succeeds.
  """
  def execute(goal, opts \\ []) when is_map(goal) or is_binary(goal) do
    try do
      strategies = load_strategies_for_attempt(opts)
      
      # Enrich opts with complexity from centralized config if not already set
      opts = enrich_opts_with_complexity(goal, opts)

      Logger.info("ExecutionStrategyOrchestrator: Executing goal", goal: inspect(goal))

      case try_strategies(strategies, goal, opts) do
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

  defp enrich_opts_with_complexity(goal, opts) do
    # Only add complexity if not already set
    if Keyword.has_key?(opts, :complexity) do
      opts
    else
      # Get complexity from centralized config
      provider = Keyword.get(opts, :provider, "auto")
      task_type = extract_task_type_from_goal(goal)
      context = %{task_type: task_type}
      
      case Config.get_task_complexity(provider, context) do
        {:ok, complexity} ->
          Keyword.put(opts, :complexity, complexity)
        {:error, _} ->
          opts  # Keep opts as-is if config fails
      end
    end
  end

  defp extract_task_type_from_goal(goal) when is_map(goal) do
    goal[:task_type] || goal["task_type"] || goal[:type] || goal["type"] || :coder
  end
  
  defp extract_task_type_from_goal(goal) when is_binary(goal) do
    # Try to infer from goal text
    cond do
      String.contains?(String.downcase(goal), ["architect", "design", "system"]) -> :architect
      String.contains?(String.downcase(goal), ["refactor", "improve"]) -> :refactoring
      String.contains?(String.downcase(goal), ["generate", "create", "code"]) -> :code_generation
      true -> :coder
    end
  end
  
  defp extract_task_type_from_goal(_), do: :coder

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

  defp try_strategies([], _goal, opts) do
    {:error, :no_strategy_found}
  end

  defp try_strategies([{strategy_type, _priority, config} | rest], goal, opts) do
    try do
      module = config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Trying #{strategy_type} execution strategy")

        case module.applicable?(goal) do
          true ->
            case module.execute(goal, opts) do
              {:ok, result} ->
                Logger.info("Execution succeeded with #{strategy_type}")
                {:ok, result}

              {:error, reason} ->
                Logger.error("#{strategy_type} execution failed", reason: inspect(reason))
                {:error, reason}
            end

          false ->
            Logger.debug("#{strategy_type} not applicable")
            try_strategies(rest, goal, opts)
        end
      else
        Logger.warning("Strategy module not found for #{strategy_type}")
        try_strategies(rest, goal, opts)
      end
    rescue
      e ->
        Logger.error("Strategy execution failed for #{strategy_type}", error: inspect(e))
        try_strategies(rest, goal, opts)
    end
  end
end
