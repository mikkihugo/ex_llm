defmodule Singularity.Schemas.Evolution.Proposal do
  @moduledoc """
  Schema for Change Proposal Queue - per-instance proposal management.

  Manages code change proposals from agents, prioritization, and tracking through
  the consensus approval process in CentralCloud.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Schemas.Evolution.Proposal",
    "purpose": "Manages agent-generated change proposals with priority scoring",
    "role": "schema",
    "layer": "domain_services",
    "table": "evolution_proposals",
    "features": ["proposal_queuing", "priority_scoring", "consensus_tracking"]
  }
  ```

  ### Anti-Patterns
  - ❌ DO NOT bypass CentralCloud consensus for high-risk agents
  - ❌ DO NOT submit proposals without safety profile
  - ✅ DO use AgentCoordinator to submit proposals
  - ✅ DO track proposal status through lifecycle

  ### Search Keywords
  change proposal, evolution queue, proposal priority, consensus tracking,
  code change management, agent proposals, priority scoring, proposal lifecycle

  ## Proposal Lifecycle

  1. **pending** - Agent submits proposal, waiting in local queue
  2. **sent_for_consensus** - Sent to CentralCloud for voting
  3. **consensus_reached** - CentralCloud approved (2/3+ votes)
  4. **consensus_failed** - CentralCloud rejected proposal
  5. **executing** - Approved proposal is being applied
  6. **applied** - Successfully executed and metrics reported
  7. **failed** - Execution failed, rollback triggered
  8. **rolled_back** - CentralCloud Guardian initiated rollback

  ## Priority Scoring

  Formula: (impact × success_rate × urgency) / (cost × risk)

  - impact_factor: 1-10 (how much does this improve the system?)
  - success_rate: 0.0-1.0 (historical success of agent)
  - cost_factor: 1-10 (computational cost, lower is better)
  - risk_factor: 1-10 (safety risk, lower is better)
  - urgency_factor: time since created (older = higher priority)

  Examples:
  - Bug fix: high impact (8), high success (0.95), low cost → priority ≈ 7.6
  - Optimization: medium impact (5), low success (0.60), high cost → priority ≈ 1.0
  - Refactoring: medium impact (6), medium success (0.75), low cost → priority ≈ 4.5
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "evolution_proposals" do
    # Agent information
    field :agent_type, :string
    field :agent_id, :string

    # Proposal content
    field :code_change, :map
    field :metadata, :map

    # Safety and risk assessment
    field :safety_profile, :map
    field :impact_score, :float, default: 5.0
    field :risk_score, :float, default: 5.0
    field :priority_score, :float, default: 0.0

    # Lifecycle states
    field :status, :string, default: "pending"
    # pending | sent_for_consensus | consensus_reached | consensus_failed |
    # executing | applied | failed | rolled_back

    # CentralCloud consensus tracking
    field :consensus_votes, :map, default: %{}
    field :consensus_sent_at, :utc_datetime_usec
    field :consensus_result, :string
    field :consensus_required, :boolean, default: true

    # Execution tracking
    field :execution_started_at, :utc_datetime_usec
    field :execution_completed_at, :utc_datetime_usec
    field :execution_error, :string

    # Metrics before/after
    field :metrics_before, :map
    field :metrics_after, :map

    # Rollback information
    field :rollback_triggered_at, :utc_datetime_usec
    field :rollback_reason, :string

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(proposal, attrs) do
    proposal
    |> cast(attrs, [
      :agent_type,
      :agent_id,
      :code_change,
      :metadata,
      :safety_profile,
      :impact_score,
      :risk_score,
      :priority_score,
      :status,
      :consensus_votes,
      :consensus_sent_at,
      :consensus_result,
      :consensus_required,
      :execution_started_at,
      :execution_completed_at,
      :execution_error,
      :metrics_before,
      :metrics_after,
      :rollback_triggered_at,
      :rollback_reason
    ])
    |> validate_required([:agent_type, :code_change, :status])
    |> validate_inclusion(:status, ~w(
      pending sent_for_consensus consensus_reached consensus_failed
      executing applied failed rolled_back
    ))
  end

  @doc "Create a new proposal from agent"
  def new_proposal(agent_type, code_change, opts \\ []) do
    %__MODULE__{}
    |> changeset(%{
      agent_type: agent_type,
      agent_id: Keyword.get(opts, :agent_id),
      code_change: code_change,
      metadata: Keyword.get(opts, :metadata, %{}),
      safety_profile: Keyword.get(opts, :safety_profile, %{}),
      impact_score: Keyword.get(opts, :impact_score, 5.0),
      risk_score: Keyword.get(opts, :risk_score, 5.0),
      consensus_required: Keyword.get(opts, :consensus_required, true),
      status: "pending"
    })
  end

  @doc "Mark proposal as sent for consensus"
  def mark_sent_for_consensus(proposal) do
    changeset(proposal, %{
      status: "sent_for_consensus",
      consensus_sent_at: DateTime.utc_now()
    })
  end

  @doc "Mark proposal as approved by consensus"
  def mark_consensus_reached(proposal, votes) do
    changeset(proposal, %{
      status: "consensus_reached",
      consensus_votes: votes,
      consensus_result: "approved"
    })
  end

  @doc "Mark proposal as rejected by consensus"
  def mark_consensus_failed(proposal, votes) do
    changeset(proposal, %{
      status: "consensus_failed",
      consensus_votes: votes,
      consensus_result: "rejected"
    })
  end

  @doc "Mark proposal execution as started"
  def mark_executing(proposal) do
    changeset(proposal, %{
      status: "executing",
      execution_started_at: DateTime.utc_now()
    })
  end

  @doc "Mark proposal as successfully applied"
  def mark_applied(proposal, metrics_after \\ %{}) do
    changeset(proposal, %{
      status: "applied",
      execution_completed_at: DateTime.utc_now(),
      metrics_after: metrics_after
    })
  end

  @doc "Mark proposal execution as failed"
  def mark_failed(proposal, error_msg) do
    changeset(proposal, %{
      status: "failed",
      execution_completed_at: DateTime.utc_now(),
      execution_error: error_msg
    })
  end

  @doc "Mark proposal as rolled back"
  def mark_rolled_back(proposal, reason) do
    changeset(proposal, %{
      status: "rolled_back",
      rollback_triggered_at: DateTime.utc_now(),
      rollback_reason: reason
    })
  end

  @doc "Set metrics before execution"
  def set_metrics_before(proposal, metrics) do
    changeset(proposal, %{metrics_before: metrics})
  end

  @doc "Recalculate priority score based on factors"
  def recalculate_priority(proposal) do
    priority = calculate_priority_score(
      proposal.impact_score,
      proposal.risk_score,
      proposal.safety_profile
    )

    changeset(proposal, %{priority_score: priority})
  end

  # Private helper to calculate priority
  defp calculate_priority_score(impact, risk, safety_profile) do
    success_rate = Map.get(safety_profile, :success_rate, 0.5)
    cost = Map.get(safety_profile, :cost_factor, 5.0)

    # Formula: (impact × success_rate) / (risk × cost)
    (impact * success_rate) / (risk * cost)
  end
end
