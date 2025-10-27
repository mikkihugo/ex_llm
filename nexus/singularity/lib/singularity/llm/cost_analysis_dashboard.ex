defmodule Singularity.LLM.CostAnalysisDashboard do
  @moduledoc """
  Cost Analysis Dashboard - Track and analyze LLM spending patterns.

  Provides comprehensive cost monitoring including:
  - Total spending by provider, model, and task type
  - Token efficiency metrics (cost per token, tokens per task)
  - Time-based spending trends (daily, weekly, monthly)
  - Cost forecasting based on historical patterns
  - Per-provider and per-model cost breakdowns
  - High-cost anomaly detection

  Data sources:
  - ExecutionMetric table - Individual LLM call costs
  - MetricsAggregation - Time-series cost events
  - Provider configurations - For pricing models

  Used by Cost Analytics Live View for real-time spending monitoring.
  """

  require Logger
  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.ExecutionMetric

  @doc """
  Get comprehensive cost analysis dashboard data.

  Returns a map containing:
  - `total_cost_cents`: Total spending across all executions
  - `cost_by_provider`: Breakdown by provider (Claude, GPT, Gemini, etc.)
  - `cost_by_model`: Breakdown by specific model
  - `cost_by_task_type`: Breakdown by task type
  - `time_series_daily`: Daily spending trend for last 30 days
  - `token_efficiency`: Cost per token by provider/model
  - `high_cost_executions`: Anomalously expensive calls
  - `forecasted_monthly_cost`: Projection based on current burn rate
  - `timestamp`: Dashboard generation time
  """
  def get_dashboard do
    try do
      timestamp = DateTime.utc_now()

      total_cost = get_total_cost()
      cost_by_provider = get_cost_by_provider()
      cost_by_model = get_cost_by_model()
      cost_by_task_type = get_cost_by_task_type()
      daily_costs = get_daily_costs()
      token_efficiency = get_token_efficiency()
      high_cost_calls = get_high_cost_executions()
      forecast = calculate_monthly_forecast(daily_costs)

      {:ok,
       %{
         total_cost_cents: total_cost,
         cost_by_provider: cost_by_provider,
         cost_by_model: cost_by_model,
         cost_by_task_type: cost_by_task_type,
         time_series_daily: daily_costs,
         token_efficiency: token_efficiency,
         high_cost_executions: high_cost_calls,
         forecasted_monthly_cost_cents: forecast,
         timestamp: timestamp
       }}
    rescue
      error ->
        Logger.error("CostAnalysisDashboard: Error getting dashboard",
          error: inspect(error)
        )

        {:error, "Failed to load cost analysis metrics"}
    end
  end

  @doc """
  Get cost analysis for a specific time period.

  ## Options
  - `:days` - Number of days to look back (default: 30)
  - `:provider` - Filter by provider (optional)
  - `:model` - Filter by model (optional)
  - `:task_type` - Filter by task type (optional)
  """
  def get_cost_analysis(opts \\ []) do
    try do
      days = Keyword.get(opts, :days, 30)
      provider = Keyword.get(opts, :provider)
      model = Keyword.get(opts, :model)
      task_type = Keyword.get(opts, :task_type)

      from_date = DateTime.utc_now() |> DateTime.add(-days * 86400)

      query =
        from em in ExecutionMetric,
          where: em.inserted_at >= ^from_date,
          order_by: [desc: em.inserted_at]

      query =
        if provider do
          query |> where([em], em.provider == ^provider)
        else
          query
        end

      query =
        if model do
          query |> where([em], em.model == ^model)
        else
          query
        end

      query =
        if task_type do
          query |> where([em], em.task_type == ^task_type)
        else
          query
        end

      metrics = Repo.all(query)

      total_cost = Enum.reduce(metrics, 0, &(&2 + &1.cost_cents))
      total_tokens = Enum.reduce(metrics, 0, &(&2 + &1.tokens_used))
      success_count = Enum.count(metrics, & &1.success)
      avg_latency = if Enum.empty?(metrics), do: 0, else: avg_value(metrics, :latency_ms)

      {:ok,
       %{
         period_days: days,
         total_cost_cents: total_cost,
         total_executions: length(metrics),
         successful_executions: success_count,
         failed_executions: length(metrics) - success_count,
         success_rate: if(length(metrics) > 0, do: success_count / length(metrics), else: 0.0),
         total_tokens: total_tokens,
         avg_cost_per_execution:
           if(length(metrics) > 0, do: total_cost / length(metrics), else: 0),
         cost_per_token: if(total_tokens > 0, do: total_cost / total_tokens, else: 0),
         avg_latency_ms: avg_latency,
         provider_filter: provider,
         model_filter: model,
         task_type_filter: task_type
       }}
    rescue
      error ->
        Logger.error("CostAnalysisDashboard: Error getting cost analysis",
          error: inspect(error)
        )

        {:error, "Failed to load cost analysis"}
    end
  end

  @doc """
  Get spending rate per provider for cost attribution and budgeting.
  """
  def get_provider_spending_rates do
    try do
      # Get last 7 days of spending
      seven_days_ago = DateTime.utc_now() |> DateTime.add(-7 * 86400)

      providers =
        Repo.all(
          from em in ExecutionMetric,
            where: em.inserted_at >= ^seven_days_ago,
            select: em.provider,
            distinct: true
        )

      provider_rates =
        Enum.map(providers, fn provider ->
          metrics =
            Repo.all(
              from em in ExecutionMetric,
                where: em.provider == ^provider and em.inserted_at >= ^seven_days_ago
            )

          total_cost = Enum.reduce(metrics, 0, &(&2 + &1.cost_cents))
          daily_rate = total_cost / 7.0

          %{
            provider: provider,
            total_cost_last_7_days: total_cost,
            avg_daily_cost: daily_rate,
            executions: length(metrics),
            avg_cost_per_execution:
              if(length(metrics) > 0, do: total_cost / length(metrics), else: 0)
          }
        end)
        |> Enum.sort_by(&Map.get(&1, :total_cost_last_7_days), :desc)

      {:ok, provider_rates}
    rescue
      error ->
        Logger.error("CostAnalysisDashboard: Error getting provider spending rates",
          error: inspect(error)
        )

        {:error, "Failed to get provider spending rates"}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp get_total_cost do
    case Repo.one(
           from em in ExecutionMetric,
             select: sum(em.cost_cents)
         ) do
      nil -> 0
      value -> round(value) || 0
    end
  end

  defp get_cost_by_provider do
    try do
      Repo.all(
        from em in ExecutionMetric,
          group_by: em.provider,
          select: %{
            provider: em.provider,
            total_cost_cents: sum(em.cost_cents),
            execution_count: count(em.id),
            avg_cost_per_execution: avg(em.cost_cents)
          },
          order_by: [desc: sum(em.cost_cents)]
      )
    rescue
      _error -> []
    end
  end

  defp get_cost_by_model do
    try do
      Repo.all(
        from em in ExecutionMetric,
          group_by: em.model,
          select: %{
            model: em.model,
            provider: em.provider,
            total_cost_cents: sum(em.cost_cents),
            execution_count: count(em.id),
            avg_cost_per_execution: avg(em.cost_cents),
            total_tokens: sum(em.tokens_used)
          },
          order_by: [desc: sum(em.cost_cents)],
          limit: 10
      )
    rescue
      _error -> []
    end
  end

  defp get_cost_by_task_type do
    try do
      Repo.all(
        from em in ExecutionMetric,
          group_by: em.task_type,
          select: %{
            task_type: em.task_type,
            total_cost_cents: sum(em.cost_cents),
            execution_count: count(em.id),
            avg_cost_per_execution: avg(em.cost_cents),
            success_rate:
              fragment("CAST(SUM(CASE WHEN ? THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*)", em.success)
          },
          order_by: [desc: sum(em.cost_cents)]
      )
    rescue
      _error -> []
    end
  end

  defp get_daily_costs do
    try do
      thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 86400)

      daily_costs =
        Repo.all(
          from em in ExecutionMetric,
            where: em.inserted_at >= ^thirty_days_ago,
            group_by: fragment("DATE(?)", em.inserted_at),
            select: %{
              date: fragment("DATE(?)", em.inserted_at),
              total_cost_cents: sum(em.cost_cents),
              execution_count: count(em.id),
              total_tokens: sum(em.tokens_used)
            },
            order_by: [asc: fragment("DATE(?)", em.inserted_at)]
        )

      Enum.map(daily_costs, fn day ->
        %{
          date: day.date,
          total_cost_cents: round(day.total_cost_cents) || 0,
          execution_count: day.execution_count,
          total_tokens: day.total_tokens || 0,
          avg_cost_per_execution:
            if(day.execution_count > 0,
              do: round(day.total_cost_cents / day.execution_count),
              else: 0
            )
        }
      end)
    rescue
      _error -> []
    end
  end

  defp get_token_efficiency do
    try do
      Repo.all(
        from em in ExecutionMetric,
          group_by: [em.provider, em.model],
          select: %{
            provider: em.provider,
            model: em.model,
            total_cost_cents: sum(em.cost_cents),
            total_tokens: sum(em.tokens_used),
            prompt_tokens: sum(em.prompt_tokens),
            completion_tokens: sum(em.completion_tokens),
            execution_count: count(em.id),
            avg_latency_ms: avg(em.latency_ms)
          },
          order_by: [desc: sum(em.cost_cents)]
      )
      |> Enum.map(fn entry ->
        %{
          entry
          | cost_per_token:
              if(entry.total_tokens > 0,
                do: entry.total_cost_cents / entry.total_tokens,
                else: 0
              ),
            completion_ratio:
              if(entry.total_tokens > 0,
                do: entry.completion_tokens / entry.total_tokens,
                else: 0
              )
        }
      end)
    rescue
      _error -> []
    end
  end

  defp get_high_cost_executions do
    try do
      # Get average cost to identify anomalies
      avg_cost =
        case Repo.one(from em in ExecutionMetric, select: avg(em.cost_cents)) do
          nil -> 0
          value -> value
        end

      # Get executions that cost 3x the average
      threshold = avg_cost * 3.0

      Repo.all(
        from em in ExecutionMetric,
          where: em.cost_cents > ^threshold,
          select: %{
            run_id: em.run_id,
            model: em.model,
            provider: em.provider,
            task_type: em.task_type,
            cost_cents: em.cost_cents,
            tokens_used: em.tokens_used,
            success: em.success,
            inserted_at: em.inserted_at
          },
          order_by: [desc: em.cost_cents],
          limit: 10
      )
    rescue
      _error -> []
    end
  end

  defp calculate_monthly_forecast(daily_costs) do
    case daily_costs do
      [] ->
        0

      costs ->
        # Calculate average daily cost from last 7 days
        recent_costs = Enum.take(costs, -7)

        avg_daily =
          if Enum.empty?(recent_costs) do
            0
          else
            total = Enum.reduce(recent_costs, 0, &(&2 + &1.total_cost_cents))
            round(total / length(recent_costs))
          end

        # Project to 30 days
        round(avg_daily * 30)
    end
  end

  defp avg_value(metrics, field) do
    total = Enum.reduce(metrics, 0, &(&2 + Map.get(&1, field, 0)))
    round(total / max(length(metrics), 1))
  end
end
