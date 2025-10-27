defmodule CentralCloud.ModelLearning.Monitoring do
  @moduledoc """
  Monitoring and dashboard queries for model learning system.

  Provides SQL queries for observability and debugging:
  - Model usage patterns
  - Success rates
  - Response time trends
  - Cross-instance behavior
  - Learnings applied
  """

  alias CentralCloud.Repo

  @doc """
  Get models used per instance in the last 24 hours.
  """
  def models_by_instance do
    Repo.query("""
      SELECT
        instance_id,
        model,
        COUNT(*) as usage_count,
        COUNT(CASE WHEN outcome = 'success' THEN 1 END) as success_count,
        ROUND(
          COUNT(CASE WHEN outcome = 'success' THEN 1 END)::float /
          COUNT(*)::float * 100, 2
        ) as success_rate
      FROM routing_records
      WHERE timestamp > NOW() - INTERVAL '24 hours'
      GROUP BY instance_id, model
      ORDER BY instance_id, usage_count DESC
    """)
  end

  @doc """
  Get success rates for all models by complexity level.
  """
  def success_rates_by_model_complexity do
    Repo.query("""
      SELECT
        model_name,
        complexity_level,
        usage_count,
        success_count,
        ROUND(
          CASE WHEN usage_count = 0 THEN 0
          ELSE success_count::float / usage_count * 100
          END, 2
        ) as success_rate
      FROM model_routing_metrics
      ORDER BY complexity_level, success_rate DESC
    """)
  end

  @doc """
  Get response time statistics by model.
  """
  def response_time_stats do
    Repo.query("""
      SELECT
        model_name,
        complexity_level,
        ROUND(avg_response_time::numeric, 0) as avg_ms,
        array_length(response_times, 1) as sample_count,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY response_times) OVER (
          PARTITION BY model_name, complexity_level
        )::numeric, 0) as median_ms
      FROM model_routing_metrics
      WHERE avg_response_time IS NOT NULL
      ORDER BY avg_response_time DESC NULLS LAST
    """)
  end

  @doc """
  Get models with highest success rates (good performers).
  """
  def top_performing_models(limit \\ 10) do
    Repo.query("""
      SELECT
        model_name,
        complexity_level,
        usage_count,
        ROUND(
          success_count::float / NULLIF(usage_count, 0) * 100, 2
        ) as success_rate,
        ROUND(avg_response_time::numeric, 0) as avg_ms
      FROM model_routing_metrics
      WHERE usage_count >= 50
      ORDER BY success_rate DESC, usage_count DESC
      LIMIT $1
    """, [limit])
  end

  @doc """
  Get models with lowest success rates (problematic performers).
  """
  def bottom_performing_models(limit \\ 10) do
    Repo.query("""
      SELECT
        model_name,
        complexity_level,
        usage_count,
        ROUND(
          success_count::float / NULLIF(usage_count, 0) * 100, 2
        ) as success_rate
      FROM model_routing_metrics
      WHERE usage_count >= 20
      ORDER BY success_rate ASC
      LIMIT $1
    """, [limit])
  end

  @doc """
  Get complexity level distribution across instances.
  """
  def complexity_distribution do
    Repo.query("""
      SELECT
        complexity,
        COUNT(*) as count,
        COUNT(DISTINCT instance_id) as instances,
        ROUND(
          COUNT(CASE WHEN outcome = 'success' THEN 1 END)::float /
          COUNT(*)::float * 100, 2
        ) as success_rate
      FROM routing_records
      WHERE timestamp > NOW() - INTERVAL '24 hours'
      GROUP BY complexity
      ORDER BY count DESC
    """)
  end

  @doc """
  Get provider preference patterns (which providers get routed for which complexity).
  """
  def provider_preferences do
    Repo.query("""
      SELECT
        complexity,
        provider,
        COUNT(*) as usage_count,
        ROUND(
          COUNT(CASE WHEN outcome = 'success' THEN 1 END)::float /
          COUNT(*)::float * 100, 2
        ) as success_rate,
        ROUND(AVG(response_time_ms)::numeric, 0) as avg_response_ms
      FROM routing_records
      WHERE timestamp > NOW() - INTERVAL '7 days'
      GROUP BY complexity, provider
      ORDER BY complexity, usage_count DESC
    """)
  end

  @doc """
  Get recent learnings (score updates made).
  """
  def recent_learnings(limit \\ 20) do
    Repo.query("""
      SELECT
        model_name,
        complexity_level,
        usage_count,
        ROUND(
          success_count::float / NULLIF(usage_count, 0) * 100, 2
        ) as success_rate,
        ROUND(avg_response_time::numeric, 0) as avg_ms,
        updated_at
      FROM model_routing_metrics
      ORDER BY updated_at DESC
      LIMIT $1
    """, [limit])
  end

  @doc """
  Get system health summary.
  """
  def health_summary do
    with {:ok, res1} <- Repo.query("SELECT COUNT(*) as total FROM routing_records"),
         {:ok, res2} <- Repo.query("SELECT COUNT(*) as models FROM model_routing_metrics"),
         {:ok, res3} <- Repo.query("""
           SELECT ROUND(AVG(success_count::float / NULLIF(usage_count, 0)) * 100, 2)
           as overall_success_rate FROM model_routing_metrics WHERE usage_count > 0
         """) do
      total = res1.rows |> List.first() |> List.first()
      models = res2.rows |> List.first() |> List.first()
      success = res3.rows |> List.first() |> List.first()

      {:ok, %{
        total_routing_decisions: total,
        tracked_model_variants: models,
        overall_success_rate: success
      }}
    end
  end
end
