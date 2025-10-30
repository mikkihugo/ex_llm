defmodule Singularity.RCA.LearningQueries do
  @moduledoc """
  RCA Learning Queries - Extract patterns for self-improvement

  Enables the self-evolution system to learn from every code generation attempt.

  ## Questions Answered

  - "What strategies work best for this type of problem?"
  - "Which templates should I use more often?"
  - "What's the optimal number of refinement iterations?"
  - "Which agents should handle which tasks?"
  - "What cost/quality tradeoffs exist?"
  """

  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Schemas.RCA.{GenerationSession, RefinementStep}

  @doc """
  Get the most cost-effective strategies (low cost, high quality outcomes).

  Returns: List of efficient generation strategies
  """
  def efficient_strategies(min_success_rate \\ 80.0, limit \\ 20) do
    from(gs in GenerationSession,
      where: gs.status == "completed" and gs.final_outcome == "success",
      group_by: [gs.template_id, gs.agent_version],
      having:
        fragment(
          "CAST(SUM(CASE WHEN ? = ? THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 >= ?",
          gs.final_outcome,
          "success",
          ^min_success_rate
        ),
      select: {
        gs.template_id,
        gs.agent_version,
        count(gs.id),
        avg(gs.generation_cost_tokens)
      },
      order_by: [asc: avg(gs.generation_cost_tokens)],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.map(fn {template_id, agent_version, count, avg_cost} ->
      %{
        template_id: template_id,
        agent_version: agent_version,
        usage_count: count,
        avg_cost_tokens: avg_cost,
        status: "recommended"
      }
    end)
  end

  @doc """
  Get the highest quality strategies (best quality outcomes, regardless of cost).

  Returns: List of high-quality strategies
  """
  def highest_quality_strategies(limit \\ 20) do
    from(gs in GenerationSession,
      where: gs.status == "completed",
      group_by: [gs.template_id, gs.agent_version],
      select: {
        gs.template_id,
        gs.agent_version,
        count(gs.id),
        fragment("AVG(CAST((? ->> 'quality_score')::FLOAT AS FLOAT))", gs.success_metrics)
      },
      order_by: [
        desc: fragment("AVG(CAST((? ->> 'quality_score')::FLOAT AS FLOAT))", gs.success_metrics)
      ],
      limit: ^limit
    )
    |> Repo.all()
    |> Enum.map(fn {template_id, agent_version, count, avg_quality} ->
      %{
        template_id: template_id,
        agent_version: agent_version,
        usage_count: count,
        avg_quality_score: avg_quality,
        status: "high_quality"
      }
    end)
  end

  @doc """
  Analyze which refinement actions are most effective.

  Returns: List of agent actions with success rates
  """
  def most_effective_refinement_actions do
    from(rs in RefinementStep,
      left_join: gs in GenerationSession,
      on: rs.generation_session_id == gs.id,
      group_by: [rs.agent_action],
      select: {
        rs.agent_action,
        count(rs.id),
        sum(fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", gs.final_outcome, "success"))
      },
      order_by: [desc: count(rs.id)]
    )
    |> Repo.all()
    |> Enum.map(fn {action, total, successful} ->
      %{
        action: action,
        total_attempts: total,
        successful: successful || 0,
        success_rate:
          if(total > 0, do: ((successful || 0) / total * 100) |> Float.round(2), else: 0.0)
      }
    end)
  end

  @doc """
  Analyze optimal refinement depth (how many iterations typically needed).

  Returns: Distribution of iterations for success vs failure
  """
  def optimal_refinement_depth do
    from(gs in GenerationSession,
      left_join: rs in RefinementStep,
      on: rs.generation_session_id == gs.id,
      where: gs.status == "completed",
      group_by: [gs.id, gs.final_outcome],
      select: {gs.final_outcome, count(rs.id)}
    )
    |> Repo.all()
    |> Enum.group_by(fn {outcome, _} -> outcome end, fn {_, count} -> count end)
    |> Enum.map(fn {outcome, counts} ->
      min_steps = Enum.min(counts, fn -> 0 end)
      max_steps = Enum.max(counts, fn -> 0 end)

      avg_steps =
        if Enum.empty?(counts) do
          0
        else
          Enum.sum(counts) / length(counts)
        end

      {outcome,
       %{
         min_steps: min_steps,
         max_steps: max_steps,
         avg_steps: Float.round(avg_steps, 2)
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Get recommendations for improving generation success.

  Returns: List of actionable improvement recommendations
  """
  def improvement_recommendations do
    # Analyze what's working
    efficient = efficient_strategies(80.0, 5)
    quality = highest_quality_strategies(5)
    effective_actions = most_effective_refinement_actions() |> Enum.take(3)

    # Identify gaps
    failure_analysis = Singularity.RCA.FailureAnalysis.difficult_to_fix_failures(2, 50.0)

    %{
      most_efficient_strategies: efficient,
      highest_quality_strategies: quality,
      most_effective_refinement_actions: effective_actions,
      improvement_areas: failure_analysis |> Enum.take(5),
      recommendations:
        [
          if(Enum.any?(efficient),
            do: "Focus on most cost-efficient strategies for routine tasks"
          ),
          if(Enum.any?(quality), do: "Invest in high-quality strategies for critical code"),
          if(Enum.any?(effective_actions),
            do: "Use recommended refinement actions in preference to others"
          ),
          if(Enum.any?(failure_analysis),
            do: "Prioritize improving handling of difficult failure modes"
          )
        ]
        |> Enum.filter(& &1)
    }
  end

  @doc """
  Get performance trends over time (learning curve analysis).

  Returns: Time-series data showing improvement
  """
  def performance_trends(time_window_minutes \\ 60) do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-1 * time_window_minutes * 60, :second)

    from(gs in GenerationSession,
      where: gs.started_at > ^cutoff_time and gs.status == "completed",
      order_by: [asc: gs.started_at],
      select: {gs.started_at, gs.final_outcome, gs.generation_cost_tokens}
    )
    |> Repo.all()
    |> Enum.reduce(%{success_count: 0, failure_count: 0, total_cost: 0, timeline: []}, fn {time,
                                                                                           outcome,
                                                                                           cost},
                                                                                          acc ->
      %{
        success_count:
          if(outcome == "success", do: acc.success_count + 1, else: acc.success_count),
        failure_count:
          if(outcome != "success", do: acc.failure_count + 1, else: acc.failure_count),
        total_cost: acc.total_cost + (cost || 0),
        timeline: [
          %{
            timestamp: time,
            outcome: outcome,
            cost: cost,
            cumulative_success_rate:
              (if(outcome == "success", do: acc.success_count + 1, else: acc.success_count) /
                 (acc.success_count + acc.failure_count + 1) * 100)
              |> Float.round(2)
          }
          | acc.timeline
        ]
      }
    end)
  end

  @doc """
  Analyze agent specialization (which agents are best at which tasks).

  Returns: Agent performance by task type
  """
  def agent_specialization do
    from(gs in GenerationSession,
      where: gs.status == "completed",
      group_by: [gs.agent_id, gs.agent_version],
      select: {
        gs.agent_id,
        gs.agent_version,
        count(gs.id),
        sum(fragment("CASE WHEN ? = ? THEN 1 ELSE 0 END", gs.final_outcome, "success")),
        avg(gs.generation_cost_tokens)
      }
    )
    |> Repo.all()
    |> Enum.map(fn {agent_id, version, total, successful, avg_cost} ->
      %{
        agent_id: agent_id,
        agent_version: version,
        total_tasks: total,
        successful_tasks: successful || 0,
        success_rate:
          if(total > 0, do: ((successful || 0) / total * 100) |> Float.round(2), else: 0.0),
        avg_cost_tokens: avg_cost,
        recommendation: recommend_agent(successful || 0, total)
      }
    end)
  end

  @doc """
  Get the cost-quality Pareto frontier (best ROI strategies).

  Returns: Strategies on the efficiency frontier
  """
  def pareto_frontier do
    all_strategies =
      Repo.all(
        from gs in GenerationSession,
          where: gs.status == "completed",
          group_by: [gs.template_id, gs.agent_version],
          select: {
            gs.template_id,
            gs.agent_version,
            avg(gs.generation_cost_tokens),
            fragment("AVG(CAST((? ->> 'quality_score')::FLOAT AS FLOAT))", gs.success_metrics)
          }
      )

    # Filter to Pareto frontier (strategies with no strictly better alternative)
    frontier =
      Enum.filter(all_strategies, fn strategy ->
        not Enum.any?(all_strategies, fn other ->
          # Lower or equal cost
          # Higher quality
          other != strategy and
            elem(other, 2) < elem(strategy, 2) and
            elem(other, 3) > elem(strategy, 3)
        end)
      end)

    Enum.map(frontier, fn {template_id, agent_version, avg_cost, quality} ->
      %{
        template_id: template_id,
        agent_version: agent_version,
        avg_cost_tokens: avg_cost,
        quality_score: quality,
        status: "optimal"
      }
    end)
  end

  # Helper to generate agent recommendation
  defp recommend_agent(successful, total) when successful / total >= 0.9, do: "excellent"
  defp recommend_agent(successful, total) when successful / total >= 0.75, do: "good"
  defp recommend_agent(successful, total) when successful / total >= 0.5, do: "fair"
  defp recommend_agent(_, _), do: "needs_improvement"
end
