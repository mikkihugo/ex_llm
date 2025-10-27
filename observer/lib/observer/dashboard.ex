defmodule Observer.Dashboard do
  @moduledoc """
  Safe wrappers around Singularity dashboard modules so the Observer UI
  can render metrics without crashing when data sources are unavailable.
  """

  require Logger

  def agent_performance do
    call_dashboard(&Singularity.Agents.AgentPerformanceDashboard.get_dashboard/0)
  end

  def code_quality do
    call_dashboard(&Singularity.Analysis.CodeQualityDashboard.get_dashboard/0)
  end

  def cost_analysis do
    call_dashboard(&Singularity.LLM.CostAnalysisDashboard.get_dashboard/0)
  end

  def rule_evolution do
    call_dashboard(&Singularity.Evolution.RuleEvolutionProgressDashboard.get_dashboard/0)
  end

  def task_execution do
    call_dashboard(&Singularity.Execution.TaskExecutionMetricsDashboard.get_dashboard/0)
  end

  def todos do
    safe_call(fn ->
      # Get todo statistics
      pending_count = Singularity.Execution.TodoStore.count_by_status("pending")
      in_progress_count = Singularity.Execution.TodoStore.count_by_status("in_progress")
      completed_count = Singularity.Execution.TodoStore.count_by_status("completed")
      failed_count = Singularity.Execution.TodoStore.count_by_status("failed")
      
      # Get swarm status
      swarm_status = Singularity.Execution.TodoSwarmCoordinator.get_status()
      
      # Get recent todos
      recent_todos = Singularity.Execution.TodoStore.list_recent(limit: 10)
      
      {:ok, %{
        counts: %{
          pending: pending_count,
          in_progress: in_progress_count,
          completed: completed_count,
          failed: failed_count
        },
        swarm: swarm_status,
        recent_todos: recent_todos
      }}
    end)
  end

  def knowledge_base do
    call_dashboard(&Singularity.Embedding.KnowledgeBaseMetricsDashboard.get_dashboard/0)
  end

  def llm_health do
    call_dashboard(&Singularity.LLM.LLMHealthDashboard.get_dashboard/0)
  end

  def validation_metrics do
    call_dashboard(&Singularity.Validation.ValidationDashboard.get_dashboard/0)
  end

  def validation_metrics_store do
    safe_call(fn ->
      {:ok,
       %{
         validation_accuracy: Singularity.Storage.ValidationMetricsStore.get_validation_accuracy(:last_week),
         execution_success_rate: Singularity.Storage.ValidationMetricsStore.get_execution_success_rate(:last_week),
         avg_validation_time: Singularity.Storage.ValidationMetricsStore.get_avg_validation_time(:last_week),
         effectiveness_scores: Singularity.Storage.ValidationMetricsStore.get_effectiveness_scores(:last_week),
         aggregated_metrics: Singularity.Storage.ValidationMetricsStore.get_aggregated_metrics(:last_week, :model)
       }}
    end)
  end

  def failure_patterns do
    safe_call(fn ->
      {:ok,
       %{
         top_patterns: Singularity.Storage.FailurePatternStore.find_patterns(limit: 10),
         recent_failures: Singularity.Storage.FailurePatternStore.query(%{since: DateTime.add(DateTime.utc_now(), -7, :day), limit: 20}),
         successful_fixes: Singularity.Storage.FailurePatternStore.get_successful_fixes(%{limit: 10})
       }}
    end)
  end

  def adaptive_threshold do
    safe_call(fn ->
      {:ok,
       %{
         status: Singularity.Evolution.AdaptiveConfidenceGating.get_tuning_status(),
         convergence: Singularity.Evolution.AdaptiveConfidenceGating.get_convergence_metrics()
       }}
    end)
  end

  def system_health do
    safe_call(fn ->
      {:ok,
       %{
         llm: result_or_nil(llm_health()),
         validation: result_or_nil(validation_metrics()),
         adaptive_threshold: result_or_nil(adaptive_threshold()),
         task_execution: result_or_nil(task_execution()),
         cost: result_or_nil(cost_analysis())
       }}
    end)
  end

  defp call_dashboard(fun) do
    safe_call(fn ->
      case fun.() do
        {:ok, data} -> {:ok, data}
        {:error, reason} -> {:error, normalize_reason(reason)}
        data -> {:ok, data}
      end
    end)
  end

  defp safe_call(fun) when is_function(fun, 0) do
    try do
      fun.()
    rescue
      error ->
        Logger.warning("Observer dashboard call failed",
          error: inspect(error),
          stacktrace: inspect(__STACKTRACE__)
        )

        {:error, normalize_reason(error)}
    end
  end

  defp result_or_nil({:ok, data}), do: data
  defp result_or_nil(_), do: nil

  defp normalize_reason(%{message: message}), do: message
  defp normalize_reason(message) when is_binary(message), do: message
  defp normalize_reason(other), do: inspect(other)
end
