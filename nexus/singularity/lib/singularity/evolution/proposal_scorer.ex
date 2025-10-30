defmodule Singularity.Evolution.ProposalScorer do
  @moduledoc """
  Proposal Priority Scorer - Calculates priority scores for code change proposals.

  Scores proposals based on multiple factors to determine execution order:
  - impact_factor: How much does this improve the system? (1-10)
  - agent_success_rate: Historical success of the agent (0.0-1.0)
  - cost_factor: Computational cost, lower is better (1-10)
  - risk_factor: Safety risk, lower is better (1-10)
  - urgency_factor: Time since proposal created (older = higher priority)

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Evolution.ProposalScorer",
    "purpose": "Calculates priority scores for proposals based on impact/cost/risk",
    "role": "service",
    "layer": "domain_services",
    "features": ["priority_calculation", "proposal_ranking", "multi_factor_scoring"]
  }
  ```

  ### Call Graph (YAML)
  ```yaml
  ProposalScorer:
    calls_from:
      - ProposalQueue.submit_proposal
    calls_to:
      - Repo (for agent metrics)
      - Telemetry
  ```

  ### Anti-Patterns
  - ❌ DO NOT use static scores without agent history
  - ❌ DO NOT ignore urgency (old proposals should have higher priority)
  - ✅ DO consult agent success rates when scoring
  - ✅ DO rebalance scores daily (as agent success rates improve)

  ### Search Keywords
  priority scoring, proposal ranking, impact assessment, cost calculation,
  risk scoring, proposal prioritization, agent success rates

  ## Scoring Formula

  ```
  base_score = (impact × success_rate) / (cost × risk)
  urgency_multiplier = 1.0 + (hours_since_creation / 24.0) * 0.1
  final_priority = base_score × urgency_multiplier
  ```

  ## Examples

  ```elixir
  # Bug fix: high impact (8), high success (0.95), low cost (2), low risk (1)
  base = (8 × 0.95) / (2 × 1) = 3.8
  urgency = 1.0 + (2 hours / 24) × 0.1 = 1.008
  priority = 3.8 × 1.008 ≈ 3.83

  # Optimization: medium impact (5), low success (0.60), high cost (8), medium risk (5)
  base = (5 × 0.60) / (8 × 5) = 0.075
  urgency = 1.0 + (1 hour / 24) × 0.1 = 1.004
  priority = 0.075 × 1.004 ≈ 0.075

  # Refactoring: medium impact (6), medium success (0.75), low cost (3), medium risk (4)
  base = (6 × 0.75) / (3 × 4) = 0.375
  urgency = 1.0 + (4 hours / 24) × 0.1 = 1.017
  priority = 0.375 × 1.017 ≈ 0.382
  ```

  Result: Bug fix (3.83) > Refactoring (0.382) > Optimization (0.075)
  """

  require Logger
  import Ecto.Query

  alias Singularity.Repo
  alias Singularity.Schemas.Evolution.Proposal

  @doc """
  Score a proposal and return updated with priority score.

  Returns proposal with calculated priority_score field.

  ## Example
  ```elixir
  proposal = %Proposal{
    impact_score: 8.0,
    risk_score: 1.0,
    safety_profile: %{success_rate: 0.95, cost_factor: 2.0},
    created_at: DateTime.utc_now()
  }

  scored = ProposalScorer.score_proposal(proposal)
  # scored.priority_score ≈ 3.83
  ```
  """
  def score_proposal(proposal) do
    priority_score = calculate_priority(proposal)
    Map.put(proposal, :priority_score, priority_score)
  end

  @doc """
  Calculate priority score for a proposal.

  Formula: (impact × success_rate) / (cost × risk) × urgency_multiplier

  Returns float >= 0.0
  """
  def calculate_priority(proposal) do
    impact = proposal.impact_score || 5.0
    risk = proposal.risk_score || 5.0

    safety_profile = proposal.safety_profile || %{}
    success_rate = Map.get(safety_profile, :success_rate, 0.5)
    cost = Map.get(safety_profile, :cost_factor, 5.0)

    # Base score formula
    base_score = (impact * success_rate) / max(cost * risk, 0.1)

    # Urgency multiplier (older proposals get higher priority)
    urgency_multiplier = calculate_urgency(proposal.created_at)

    # Final priority score
    final_score = base_score * urgency_multiplier

    # Ensure non-negative
    max(final_score, 0.0)
  end

  @doc """
  Rebalance priority scores for all pending proposals.

  Useful to run periodically as agent success rates improve.
  Returns {:ok, count_updated}
  """
  def rebalance_all_pending do
    Logger.info("Rebalancing priority scores for pending proposals")

    pending = Repo.all(
      from p in Proposal,
      where: p.status == "pending"
    )

    updated_count =
      Enum.reduce(pending, 0, fn proposal, acc ->
        case update_priority_score(proposal) do
          {:ok, _} -> acc + 1
          {:error, reason} ->
            Logger.warning("Failed to rebalance proposal #{proposal.id}: #{inspect(reason)}")
            acc
        end
      end)

    Logger.info("Rebalanced #{updated_count} proposals")
    {:ok, updated_count}
  end

  @doc """
  Update a proposal's priority score in the database.

  Returns `{:ok, proposal}` or `{:error, reason}`.
  """
  def update_priority_score(proposal) do
    scored = score_proposal(proposal)

    Repo.update(
      Proposal.changeset(proposal, %{priority_score: scored.priority_score})
    )
  end

  @doc """
  Get agent success rate from historical data.

  Returns float 0.0-1.0 based on recent execution history.
  """
  def get_agent_success_rate(agent_type) do
    # Query recent proposals from this agent
    recent_proposals = Repo.all(
      from p in Proposal,
      where: p.agent_type == ^agent_type and p.status in ~w(applied failed),
      order_by: [desc: p.created_at],
      limit: 100
    )

    case recent_proposals do
      [] ->
        0.5  # Default if no history

      proposals ->
        successful = Enum.count(proposals, &(&1.status == "applied"))
        successful / length(proposals)
    end
  end

  @doc """
  Calculate cost factor for a proposal based on typical agent costs.

  Returns 1.0-10.0 where lower is cheaper.
  """
  def get_agent_cost_factor(agent_type) do
    case agent_type do
      "BugFixerAgent" -> 3.0
      "RefactoringAgent" -> 2.0
      "OptimizationAgent" -> 8.0
      "DocumentationGenerator" -> 1.0
      "QualityCodeGenerator" -> 5.0
      "FeatureSynthesizer" -> 7.0
      _ -> 5.0  # Default
    end
  end

  @doc """
  Validate proposal scoring parameters.

  Returns `:ok` or `{:error, reason}`.
  """
  def validate_scoring_params(proposal) do
    cond do
      proposal.impact_score < 0 or proposal.impact_score > 10 ->
        {:error, :invalid_impact_score}

      proposal.risk_score < 0 or proposal.risk_score > 10 ->
        {:error, :invalid_risk_score}

      true ->
        :ok
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp calculate_urgency(created_at) do
    hours_elapsed = DateTime.diff(DateTime.utc_now(), created_at, :second) / 3600

    # Urgency multiplier: increases slowly over time
    # At 24 hours: 1.0 + (24/24) * 0.1 = 1.1
    # At 48 hours: 1.0 + (48/24) * 0.1 = 1.2
    1.0 + (hours_elapsed / 24.0) * 0.1
  end
end
