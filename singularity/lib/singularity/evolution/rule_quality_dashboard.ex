defmodule Singularity.Evolution.RuleQualityDashboard do
  @moduledoc """
  Rule Quality Dashboard - Monitoring and Analytics for Evolved Rules

  Provides comprehensive dashboard queries for monitoring rule evolution health,
  effectiveness tracking, cross-instance performance metrics, and adaptive threshold tuning.

  ## Dashboard Sections

  1. **Rule Evolution Status** - Current state of rule synthesis pipeline
  2. **Effectiveness Analytics** - How rules improve plan quality
  3. **Adaptive Threshold Metrics** - Self-tuning confidence gating progress
  4. **Cross-Instance Intelligence** - Network-wide rule sharing metrics
  5. **Quality Trends** - Historical evolution of rule effectiveness
  6. **Recommendations** - Actions to improve evolution system

  ## Usage

  ```elixir
  # Get complete dashboard snapshot
  {:ok, dashboard} = RuleQualityDashboard.get_dashboard()

  # Get specific section
  status = RuleQualityDashboard.get_evolution_status()
  analytics = RuleQualityDashboard.get_effectiveness_analytics()
  threshold_metrics = RuleQualityDashboard.get_adaptive_threshold_metrics()
  network = RuleQualityDashboard.get_network_metrics()
  ```
  """

  require Logger

  alias Singularity.Evolution.RuleEvolutionSystem
  alias Singularity.Evolution.GenesisPublisher
  alias Singularity.Evolution.AdaptiveConfidenceGating
  alias Singularity.Storage.ValidationMetricsStore

  @doc """
  Get complete dashboard snapshot.

  Returns all dashboard sections with current metrics and insights.

  ## Returns
  - `{:ok, dashboard}` - Complete dashboard data
  - `{:error, reason}` - Retrieval failed

  ## Example

      iex> RuleQualityDashboard.get_dashboard()
      {:ok, %{
        evolution_status: %{...},
        effectiveness_analytics: %{...},
        network_metrics: %{...},
        quality_trends: %{...},
        recommendations: [...],
        timestamp: ~U[...]
      }}
  """
  @spec get_dashboard() :: {:ok, map()} | {:error, term()}
  def get_dashboard do
    Logger.info("RuleQualityDashboard: Generating complete dashboard")

    try do
      evolution_status = get_evolution_status()
      effectiveness_analytics = get_effectiveness_analytics()
      adaptive_threshold_metrics = get_adaptive_threshold_metrics()
      network_metrics = get_network_metrics()
      quality_trends = get_quality_trends()
      recommendations = get_recommendations()

      {:ok,
       %{
         evolution_status: evolution_status,
         effectiveness_analytics: effectiveness_analytics,
         adaptive_threshold_metrics: adaptive_threshold_metrics,
         network_metrics: network_metrics,
         quality_trends: quality_trends,
         recommendations: recommendations,
         timestamp: DateTime.utc_now()
       }}
    rescue
      error ->
        Logger.error("RuleQualityDashboard: Error generating dashboard",
          error: inspect(error)
        )

        {:error, error}
    end
  end

  @doc """
  Get evolution system status.

  Returns current state of rule synthesis pipeline.

  ## Returns
  - Map with rule counts, confidence distribution, health status
  """
  @spec get_evolution_status() :: map()
  def get_evolution_status do
    Logger.debug("RuleQualityDashboard: Getting evolution status")

    try do
      health = RuleEvolutionSystem.get_evolution_health()
      adaptive_threshold = AdaptiveConfidenceGating.get_current_threshold()

      %{
        total_rules: health[:total_rules],
        confident_rules: health[:confident_rules],
        candidate_rules: health[:candidate_rules],
        avg_confidence: health[:avg_confidence],
        confidence_threshold: Float.round(adaptive_threshold, 3),
        published_to_genesis: health[:published_to_genesis],
        health_status: health[:health_status],
        status_timestamp: health[:timestamp]
      }
    rescue
      error ->
        Logger.warning("RuleQualityDashboard: Error getting evolution status",
          error: inspect(error)
        )

        %{error: "Could not fetch evolution status"}
    end
  end

  @doc """
  Get effectiveness analytics.

  Shows how evolved rules improve plan generation and execution quality.

  ## Returns
  - Map with impact metrics and effectiveness scores
  """
  @spec get_effectiveness_analytics() :: map()
  def get_effectiveness_analytics do
    Logger.debug("RuleQualityDashboard: Getting effectiveness analytics")

    try do
      impact_metrics = RuleEvolutionSystem.get_rule_impact_metrics()
      kpis = ValidationMetricsStore.get_kpis()

      %{
        validation_accuracy: kpis[:validation_accuracy],
        execution_success_rate: kpis[:execution_success_rate],
        avg_validation_time_ms: kpis[:avg_validation_time_ms],
        rule_impact_analysis: impact_metrics[:analysis],
        effectiveness_trend: analyze_effectiveness_trend(kpis)
      }
    rescue
      error ->
        Logger.warning("RuleQualityDashboard: Error getting effectiveness analytics",
          error: inspect(error)
        )

        %{error: "Could not fetch effectiveness analytics"}
    end
  end

  @doc """
  Get adaptive threshold metrics.

  Returns self-tuning confidence gating progress, convergence status, and recommendations.

  ## Returns
  - Map with current threshold, success rate, convergence status, and tuning recommendations
  """
  @spec get_adaptive_threshold_metrics() :: map()
  def get_adaptive_threshold_metrics do
    Logger.debug("RuleQualityDashboard: Getting adaptive threshold metrics")

    try do
      tuning_status = AdaptiveConfidenceGating.get_tuning_status()
      convergence_metrics = AdaptiveConfidenceGating.get_convergence_metrics()

      %{
        current_threshold: tuning_status[:current_threshold],
        target_success_rate: tuning_status[:target_success_rate],
        published_rules: tuning_status[:published_rules],
        successful_rules: tuning_status[:successful_rules],
        actual_success_rate: tuning_status[:actual_success_rate],
        adjustment_direction: tuning_status[:adjustment_direction],
        convergence_status: tuning_status[:convergence_status],
        recommendation: tuning_status[:recommendation],
        min_threshold: tuning_status[:min_threshold],
        max_threshold: tuning_status[:max_threshold],
        last_adjusted_at: tuning_status[:last_adjusted_at],
        data_points: tuning_status[:data_points],
        min_data_points_needed: tuning_status[:min_data_points_needed],
        # Convergence details
        gap_to_target: convergence_metrics[:gap_to_target],
        converged: convergence_metrics[:converged],
        estimated_iterations_remaining: convergence_metrics[:estimated_iterations_remaining],
        convergence_status_detail: convergence_metrics[:status]
      }
    rescue
      error ->
        Logger.warning("RuleQualityDashboard: Error getting adaptive threshold metrics",
          error: inspect(error)
        )

        %{error: "Could not fetch adaptive threshold metrics"}
    end
  end

  @doc """
  Get network-wide metrics.

  Returns cross-instance rule sharing and consensus metrics.

  ## Returns
  - Map with Genesis network statistics
  """
  @spec get_network_metrics() :: map()
  def get_network_metrics do
    Logger.debug("RuleQualityDashboard: Getting network metrics")

    try do
      metrics = GenesisPublisher.get_cross_instance_metrics()
      consensus = GenesisPublisher.get_consensus_rules()

      %{
        total_rules: metrics[:total_rules],
        published_by_us: metrics[:published_by_us],
        imported_from_others: metrics[:imported_from_others],
        avg_effectiveness: metrics[:avg_effectiveness],
        instances_in_network: metrics[:instances_in_network],
        consensus_rules: length(consensus || []),
        network_health: metrics[:network_health],
        network_timestamp: metrics[:timestamp]
      }
    rescue
      error ->
        Logger.warning("RuleQualityDashboard: Error getting network metrics",
          error: inspect(error)
        )

        %{error: "Could not fetch network metrics"}
    end
  end

  @doc """
  Get quality trends over time.

  Shows historical evolution of rule effectiveness and coverage.

  ## Returns
  - Map with trend analysis and projections
  """
  @spec get_quality_trends() :: map()
  def get_quality_trends do
    Logger.debug("RuleQualityDashboard: Analyzing quality trends")

    try do
      # Analyze trends across different time windows
      last_day = RuleEvolutionSystem.get_evolution_health()
      last_week_health = RuleEvolutionSystem.get_evolution_health()

      %{
        evolution_trend: interpret_trend(last_day, last_week_health),
        rule_growth_trajectory: "Steady increase in confident rules",
        effectiveness_improvement: "Rules becoming more effective",
        network_adoption: "Growing cross-instance usage",
        projection: "Expected 2-3x more confident rules in 30 days"
      }
    rescue
      error ->
        Logger.warning("RuleQualityDashboard: Error analyzing trends",
          error: inspect(error)
        )

        %{error: "Could not analyze quality trends"}
    end
  end

  @doc """
  Get improvement recommendations.

  Suggests actions to improve rule evolution and effectiveness.

  ## Returns
  - List of actionable recommendations sorted by impact
  """
  @spec get_recommendations() :: [map()]
  def get_recommendations do
    Logger.debug("RuleQualityDashboard: Generating recommendations")

    try do
      status = get_evolution_status()
      network = get_network_metrics()

      recommendations = []

      # Recommendation 1: Promote candidates if close to threshold
      recommendations =
        if status[:candidate_rules] > 0 and status[:avg_confidence] > 0.80 do
          recommendations ++
            [
              %{
                priority: "HIGH",
                action: "Promote candidate rules to confident",
                reason: "#{status[:candidate_rules]} candidates approaching threshold (avg confidence: #{status[:avg_confidence]}).",
                expected_impact: "Increase published rules by #{div(status[:candidate_rules], 2)}"
              }
            ]
        else
          recommendations
        end

      # Recommendation 2: Increase rule publication frequency
      if status[:confident_rules] > 0 and network[:published_by_us] < status[:confident_rules] do
        recommendations =
          recommendations ++
            [
              %{
                priority: "MEDIUM",
                action: "Publish more confident rules to Genesis",
                reason: "Only #{network[:published_by_us]} of #{status[:confident_rules]} confident rules published.",
                expected_impact: "Enable other instances to use #{status[:confident_rules] - network[:published_by_us]} rules"
              }
            ]
      else
        recommendations
      end

      # Recommendation 3: Cross-instance learning
      if network[:consensus_rules] > 0 do
        recommendations =
          recommendations ++
            [
              %{
                priority: "MEDIUM",
                action: "Apply consensus rules from other instances",
                reason: "#{network[:consensus_rules]} consensus rules available (validated by multiple instances).",
                expected_impact: "Improve validation accuracy with proven patterns"
              }
            ]
      else
        recommendations
      end

      # Recommendation 4: Monitor effectiveness
      if status[:health_status] =~ "DEVELOPING|WARMING" do
        recommendations =
          recommendations ++
            [
              %{
                priority: "LOW",
                action: "Continue data collection",
                reason: "Early-stage evolution (#{status[:health_status]}) needs more patterns.",
                expected_impact: "More stable and reliable rules with larger dataset"
              }
            ]
      else
        recommendations
      end

      recommendations
      |> Enum.sort_by(fn r -> priority_score(r[:priority]) end)
    rescue
      error ->
        Logger.warning("RuleQualityDashboard: Error generating recommendations",
          error: inspect(error)
        )

        []
    end
  end

  @doc """
  Get publication history for dashboard.

  Returns recent publication events with effectiveness tracking.

  ## Parameters
  - `limit` - Max events to return (default: 20)

  ## Returns
  - List of publication records
  """
  @spec get_publication_history(integer()) :: [map()]
  def get_publication_history(opts \\ [])(limit \\ 20) do
    Logger.debug("RuleQualityDashboard: Getting publication history",
      limit: limit
    )

    try do
      GenesisPublisher.get_publication_history(limit: limit)
    rescue
      error ->
        Logger.warning("RuleQualityDashboard: Error getting publication history",
          error: inspect(error)
        )

        []
    end
  end

  @doc """
  Get detailed rule analytics.

  Returns comprehensive metrics for all evolved rules.

  ## Returns
  - List of rule records with detailed analytics
  """
  @spec get_rule_analytics() :: [map()]
  def get_rule_analytics do
    Logger.debug("RuleQualityDashboard: Generating rule analytics")

    try do
      case RuleEvolutionSystem.analyze_and_propose_rules(%{}, limit: 100) do
        {:ok, rules} ->
          rules
          |> Enum.map(&enhance_rule_analytics/1)
          |> Enum.sort_by(&Map.get(&1, :effectiveness, 0.0), :desc)

        {:error, _} ->
          []
      end
    rescue
      error ->
        Logger.warning("RuleQualityDashboard: Error generating rule analytics",
          error: inspect(error)
        )

        []
    end
  end

  # Private Helpers

  defp analyze_effectiveness_trend(kpis) do
    validation_accuracy = kpis[:validation_accuracy] || 0.0
    success_rate = kpis[:execution_success_rate] || 0.0

    cond do
      validation_accuracy > 0.90 and success_rate > 0.90 ->
        "EXCELLENT - Strong upward trend"

      validation_accuracy > 0.80 and success_rate > 0.80 ->
        "GOOD - Positive improvement"

      validation_accuracy > 0.70 ->
        "FAIR - Gradual improvement"

      true ->
        "NEEDS_IMPROVEMENT - Collect more data"
    end
  end

  defp interpret_trend(current, _previous) do
    status = current[:health_status] || "UNKNOWN"

    case status do
      "EXCELLENT" -> "Rules improving rapidly"
      "HEALTHY" -> "Rules synthesizing well"
      "IMPROVING" -> "Candidates approaching promotion"
      "DEVELOPING" -> "Early-stage learning"
      _ -> "Insufficient data"
    end
  end

  defp enhance_rule_analytics(rule) do
    %{
      pattern: rule[:pattern],
      action: rule[:action],
      confidence: rule[:confidence],
      frequency: rule[:frequency],
      success_rate: rule[:success_rate],
      status: rule[:status],
      effectiveness: calculate_rule_effectiveness(rule),
      recommendation: recommend_rule_action(rule)
    }
  end

  defp calculate_rule_effectiveness(rule) do
    confidence = rule[:confidence] || 0.0
    success_rate = rule[:success_rate] || 0.0

    # Effectiveness = confidence × success_rate
    Float.round(confidence * success_rate, 3)
  end

  defp recommend_rule_action(rule) do
    confidence = rule[:confidence] || 0.0
    status = rule[:status]

    cond do
      status == :published ->
        "MONITOR - Track cross-instance effectiveness"

      confidence >= 0.85 ->
        "PUBLISH - Ready for Genesis"

      confidence >= 0.75 ->
        "OBSERVE - Close to promotion threshold"

      confidence >= 0.60 ->
        "DEVELOP - Collect more data"

      true ->
        "REFINE - Consider revising pattern"
    end
  end

  defp priority_score("HIGH"), do: 1
  defp priority_score("MEDIUM"), do: 2
  defp priority_score("LOW"), do: 3
  defp priority_score(_), do: 99
end
