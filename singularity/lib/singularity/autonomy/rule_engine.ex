defmodule Singularity.Autonomy.RuleEngine do
  @moduledoc """
  Rule Engine for autonomous decision making.

  Executes rules based on categories and contexts to make decisions
  about task execution, agent behavior, and system optimization.
  """

  require Logger
  alias Singularity.Autonomy.RuleEngineV2, as: RuleEngineV2

  @doc """
  Execute rules for a specific category.

  ## Parameters
  - `category` - Rule category (atom)
  - `context` - Context map for rule evaluation

  ## Returns
  - Rule execution result
  """
  def execute_category(category, context) do
    try do
      Logger.debug("Executing rules for category", category: category)

      # Delegate to RuleEngineV2 for actual execution
      case RuleEngineV2.execute_rules(category, context) do
        {:ok, result} ->
          Logger.debug("Rule execution successful", category: category, result: result)
          result
        {:error, reason} ->
          Logger.warning("Rule execution failed", category: category, reason: reason)
          {:error, reason}
        _ ->
          Logger.warning("Rule execution returned unexpected result", category: category)
          {:error, :unexpected_result}
      end
    rescue
      e ->
        Logger.error("Error executing rules for category",
          category: category,
          error: inspect(e)
        )
        {:error, :execution_failed}
    end
  end

  @doc """
  Get available rule categories.
  """
  def get_categories do
    [
      :cost_optimization,
      :quality_enhancement,
      :performance_monitoring,
      :resource_allocation,
      :task_prioritization,
      :error_handling,
      :learning_adaptation
    ]
  end

  @doc """
  Validate rule execution context.
  """
  def validate_context(category, context) do
    required_fields = get_required_fields(category)

    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(context, field)
    end)

    if Enum.empty?(missing_fields) do
      {:ok, context}
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end

  @doc """
  Get rules for a category.
  """
  def get_rules_for_category(category) do
    # This would typically load rules from a database or configuration
    # For now, return a basic structure
    case category do
      :cost_optimization ->
        [
          %{id: :check_cost_limits, priority: :high, conditions: [], actions: []},
          %{id: :optimize_resource_usage, priority: :medium, conditions: [], actions: []}
        ]
      :quality_enhancement ->
        [
          %{id: :validate_output_quality, priority: :high, conditions: [], actions: []},
          %{id: :apply_quality_checks, priority: :medium, conditions: [], actions: []}
        ]
      _ ->
        []
    end
  end

  # Private Functions

  defp get_required_fields(category) do
    case category do
      :cost_optimization -> [:budget, :task_complexity]
      :quality_enhancement -> [:quality_threshold, :output_type]
      :performance_monitoring -> [:metrics, :thresholds]
      :resource_allocation -> [:available_resources, :requirements]
      :task_prioritization -> [:deadline, :priority_level]
      :error_handling -> [:error_type, :context]
      :learning_adaptation -> [:performance_data, :learning_goals]
      _ -> []
    end
  end
end