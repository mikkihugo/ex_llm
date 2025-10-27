defmodule Singularity.Evolution.RuleEvolutionProgressDashboard do
  @moduledoc """
  Rule Evolution Progress Dashboard - Track rule promotion and effectiveness over time.

  Monitors the complete rule evolution lifecycle:
  - Candidate rules (under confidence threshold)
  - Confident rules (at/above confidence threshold)
  - Published rules (deployed to Genesis)
  - Rule effectiveness tracking (success rates)
  - Consensus voting history
  - Confidence distribution

  Data sources:
  - RuleEvolutionSystem - Rule analysis and promotion tracking
  - Execution.Autonomy.Rule - Rule schema with versions and status
  - Execution.Autonomy.RuleEvolutionProposal - Consensus voting decisions
  - Execution.Autonomy.RuleExecution - Per-rule success/failure tracking

  Used by Rule Evolution Timeline Live View for visual rule progression monitoring.
  """

  require Logger
  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Execution.Autonomy.Rule
  alias Singularity.Evolution.RuleEvolutionSystem

  @doc """
  Get comprehensive rule evolution progress dashboard data.

  Returns a map containing:
  - `evolution_health`: Overall health status
  - `rule_counts`: Rules by stage (candidate/confident/published)
  - `confidence_distribution`: How rules are distributed across confidence levels
  - `recent_promotions`: Rules recently promoted to higher confidence
  - `effectiveness_metrics`: Success rates by rule
  - `proposal_voting`: Recent consensus decisions
  - `convergence_metrics`: How quickly rules reach high confidence
  - `timestamp`: Dashboard generation time
  """
  def get_dashboard do
    try do
      timestamp = DateTime.utc_now()

      # Get evolution health from system
      evolution_health = safe_get_evolution_health()

      # Get rule counts by stage
      rule_counts = get_rule_counts()

      # Get confidence distribution
      confidence_dist = get_confidence_distribution()

      # Get recent promotions
      recent_promotions = get_recent_promotions()

      # Get effectiveness metrics
      effectiveness = get_rule_effectiveness()

      # Get proposal voting stats
      proposals = get_proposal_voting_stats()

      # Calculate convergence metrics
      convergence = calculate_convergence_metrics()

      {:ok,
       %{
         evolution_health: evolution_health,
         rule_counts: rule_counts,
         confidence_distribution: confidence_dist,
         recent_promotions: recent_promotions,
         effectiveness_metrics: effectiveness,
         proposal_voting: proposals,
         convergence_metrics: convergence,
         timestamp: timestamp
       }}
    rescue
      error ->
        Logger.error("RuleEvolutionProgressDashboard: Error getting dashboard",
          error: inspect(error)
        )

        {:error, "Failed to load rule evolution metrics"}
    end
  end

  @doc """
  Get detailed rule promotion timeline showing progression of a specific rule.

  Returns rule's journey from candidate → confident → published with timing info.
  """
  def get_rule_timeline(rule_id) when is_binary(rule_id) do
    try do
      case Repo.get(Rule, rule_id) do
        nil ->
          {:error, "Rule not found"}

        rule ->
          # Get version history
          versions =
            Repo.all(
              from r in Rule,
                where: r.parent_id == ^rule.id or r.id == ^rule.id,
                order_by: [asc: r.version]
            )

          timeline =
            Enum.map(versions, fn v ->
              %{
                version: v.version,
                confidence: v.confidence_threshold,
                status: if(v.active, do: :active, else: :inactive),
                created_at: v.inserted_at,
                age_days: days_old(v.inserted_at)
              }
            end)

          {:ok,
           %{
             rule_id: rule_id,
             name: rule.name,
             category: rule.category,
             versions: length(versions),
             timeline: timeline,
             current_confidence: rule.confidence_threshold,
             is_active: rule.active
           }}
      end
    rescue
      error ->
        Logger.error("RuleEvolutionProgressDashboard: Error getting rule timeline",
          rule_id: rule_id,
          error: inspect(error)
        )

        {:error, "Failed to load rule timeline"}
    end
  end

  @doc """
  Get promotion velocity - how fast rules are being promoted to higher confidence.

  Returns metrics on promotion speed and effectiveness.
  """
  def get_promotion_velocity do
    try do
      # Get rules grouped by age and confidence
      all_rules = Repo.all(Rule)

      young_high_confidence =
        Enum.count(all_rules, fn r ->
          days_old(r.inserted_at) < 7 and r.confidence_threshold >= 0.90
        end)

      young_total = Enum.count(all_rules, fn r -> days_old(r.inserted_at) < 7 end)

      promotion_rate =
        if young_total > 0, do: young_high_confidence / young_total, else: 0.0

      {:ok,
       %{
         young_rules_promoted: young_high_confidence,
         young_rules_total: young_total,
         promotion_rate: Float.round(promotion_rate, 3),
         velocity_status:
           if(promotion_rate >= 0.5,
             do: :excellent,
             else: if(promotion_rate >= 0.3, do: :good, else: :needs_improvement)
           )
       }}
    rescue
      error ->
        Logger.error("RuleEvolutionProgressDashboard: Error getting promotion velocity",
          error: inspect(error)
        )

        {:error, "Failed to calculate promotion velocity"}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp safe_get_evolution_health do
    case RuleEvolutionSystem.get_evolution_health() do
      %{} = health ->
        health

      {:ok, health} when is_map(health) ->
        health

      _error ->
        Logger.warning("RuleEvolutionSystem.get_evolution_health returned no data")
        %{}
    end
  end

  defp get_rule_counts do
    all_rules = Repo.all(Rule)

    high_confidence = Enum.count(all_rules, &(&1.confidence_threshold >= 0.90))

    medium_confidence =
      Enum.count(all_rules, fn r ->
        r.confidence_threshold >= 0.70 and r.confidence_threshold < 0.90
      end)

    low_confidence = Enum.count(all_rules, &(&1.confidence_threshold < 0.70))
    active = Enum.count(all_rules, & &1.active)
    inactive = Enum.count(all_rules, &(not &1.active))

    %{
      total: length(all_rules),
      high_confidence: high_confidence,
      medium_confidence: medium_confidence,
      low_confidence: low_confidence,
      active: active,
      inactive: inactive,
      avg_confidence:
        if(Enum.empty?(all_rules),
          do: 0.0,
          else:
            Enum.reduce(all_rules, 0.0, &(&2 + &1.confidence_threshold)) /
              length(all_rules)
        )
    }
  end

  defp get_confidence_distribution do
    all_rules = Repo.all(Rule)

    if Enum.empty?(all_rules) do
      []
    else
      Enum.group_by(all_rules, fn r ->
        case r.confidence_threshold do
          c when c >= 0.95 -> "0.95-1.00"
          c when c >= 0.90 -> "0.90-0.95"
          c when c >= 0.85 -> "0.85-0.90"
          c when c >= 0.80 -> "0.80-0.85"
          c when c >= 0.75 -> "0.75-0.80"
          _c -> "Below 0.75"
        end
      end)
      |> Enum.map(fn {range, rules} ->
        %{
          confidence_range: range,
          count: length(rules),
          percentage: Float.round(length(rules) / max(length(all_rules), 1) * 100, 1)
        }
      end)
      |> Enum.sort_by(
        &String.to_float(String.split(&1.confidence_range, "-") |> List.first()),
        :desc
      )
    end
  end

  defp get_recent_promotions do
    # Get rules promoted in last 7 days
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7 * 86400)

    Repo.all(
      from rule in Rule,
        where: rule.inserted_at >= ^seven_days_ago,
        where: rule.confidence_threshold >= 0.85,
        order_by: [desc: rule.inserted_at],
        limit: 10
    )
    |> Enum.map(fn r ->
      %{
        name: r.name,
        category: r.category,
        confidence: r.confidence_threshold,
        promoted_at: r.inserted_at,
        age_days: days_old(r.inserted_at),
        status: if(r.active, do: :active, else: :inactive)
      }
    end)
  end

  defp get_rule_effectiveness do
    all_rules = Repo.all(Rule)

    Enum.map(all_rules, fn rule ->
      # Count executions for this rule
      executions =
        Repo.all(
          from re in Singularity.Execution.Autonomy.RuleExecution,
            where: re.rule_id == ^rule.id
        )

      success_count = Enum.count(executions, & &1.success)
      total_count = length(executions)

      success_rate =
        if total_count > 0, do: success_count / total_count, else: 0.0

      %{
        rule_id: rule.id,
        name: rule.name,
        confidence: rule.confidence_threshold,
        executions: total_count,
        successful: success_count,
        success_rate: Float.round(success_rate, 3),
        effectiveness:
          if(success_rate >= 0.95,
            do: :excellent,
            else:
              if(success_rate >= 0.85,
                do: :good,
                else: if(success_rate >= 0.75, do: :fair, else: :needs_improvement)
              )
          )
      }
    end)
    |> Enum.sort_by(&Map.get(&1, :success_rate), :desc)
    |> Enum.take(10)
  end

  defp get_proposal_voting_stats do
    # Get recent proposals (last 30 days)
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 86400)

    proposals =
      Repo.all(
        from proposal in Singularity.Execution.Autonomy.RuleEvolutionProposal,
          where: proposal.inserted_at >= ^thirty_days_ago,
          order_by: [desc: proposal.inserted_at],
          limit: 20
      )

    approved = Enum.count(proposals, &(&1.status == :approved))
    rejected = Enum.count(proposals, &(&1.status == :rejected))
    pending = Enum.count(proposals, &(&1.status == :pending))

    %{
      total_proposals: length(proposals),
      approved: approved,
      rejected: rejected,
      pending: pending,
      approval_rate:
        if(length(proposals) > 0,
          do: Float.round(approved / length(proposals), 3),
          else: 0.0
        )
    }
  end

  defp calculate_convergence_metrics do
    all_rules = Repo.all(Rule)

    if Enum.empty?(all_rules) do
      %{
        avg_time_to_high_confidence_days: 0,
        rules_converged: 0,
        convergence_rate: 0.0
      }
    else
      converged = Enum.filter(all_rules, &(&1.confidence_threshold >= 0.90))
      avg_age = Enum.reduce(all_rules, 0, &(&2 + days_old(&1.inserted_at))) / length(all_rules)

      converged_age =
        if Enum.empty?(converged),
          do: 0,
          else: Enum.reduce(converged, 0, &(&2 + days_old(&1.inserted_at))) / length(converged)

      %{
        avg_time_to_high_confidence_days: Float.round(converged_age, 1),
        rules_converged: length(converged),
        convergence_rate: Float.round(length(converged) / length(all_rules), 3),
        avg_rule_age_days: Float.round(avg_age, 1)
      }
    end
  end

  defp days_old(timestamp) do
    case DateTime.diff(DateTime.utc_now(), timestamp, :second) do
      seconds when seconds >= 0 -> round(seconds / 86400)
      _ -> 0
    end
  end
end
