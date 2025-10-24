defmodule Singularity.Execution.Autonomy.RuleEvolutionProposal do
  @moduledoc """
  Consensus-based rule evolution proposals.

  Agents propose changes, other agents vote, changes applied if consensus reached.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Execution.Autonomy.RuleEvolutionProposal",
    "purpose": "Tracks consensus-based rule evolution with voting and trial results",
    "role": "schema",
    "layer": "domain_services",
    "table": "rule_evolution_proposals",
    "relationships": {
      "belongs_to": "Rule - the rule being evolved"
    }
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - id: Primary key (binary_id)
    - rule_id: Foreign key to rule being evolved
    - proposer_agent_id: Agent proposing the evolution
    - proposed_patterns: Array of proposed pattern changes
    - proposed_threshold: Proposed confidence threshold
    - evolution_reasoning: Why this evolution is needed
    - trial_results: JSONB with trial execution results
    - trial_confidence: Confidence from trial runs
    - votes: JSONB mapping agent_id → {vote, confidence, voted_at}
    - consensus_reached: Boolean - true if >= 3 agents, avg confidence > 0.85
    - status: Enum (proposed, approved, rejected, expired)

  relationships:
    belongs_to: [Rule]
    has_many: []
  ```

  ### Anti-Patterns
  - ❌ DO NOT modify rules without RuleEvolutionProposal - bypasses governance
  - ❌ DO NOT approve proposals without consensus (3+ votes, 0.85+ confidence)
  - ✅ DO use RuleEvolutionProposal for all rule changes
  - ✅ DO track trial_results before proposing evolution

  ### Search Keywords
  rule evolution, consensus voting, agent governance, rule proposals,
  trial results, confidence voting, autonomous evolution, rule changes
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rule_evolution_proposals" do
    belongs_to :rule, Singularity.Execution.Autonomy.Rule
    field :proposer_agent_id, :string

    field :proposed_patterns, {:array, :map}
    field :proposed_threshold, :float
    field :evolution_reasoning, :string

    field :trial_results, :map
    field :trial_confidence, :float

    field :votes, :map
    field :consensus_reached, :boolean
    field :status, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(proposal, attrs) do
    proposal
    |> cast(attrs, [
      :rule_id,
      :proposer_agent_id,
      :proposed_patterns,
      :proposed_threshold,
      :evolution_reasoning
    ])
    |> validate_required([
      :rule_id,
      :proposer_agent_id,
      :proposed_patterns,
      :evolution_reasoning
    ])
    |> validate_inclusion(:status, ["proposed", "approved", "rejected", "expired"])
    |> foreign_key_constraint(:rule_id)
  end

  def vote_changeset(proposal, agent_id, vote, confidence) do
    current_votes = proposal.votes || %{}

    new_votes =
      Map.put(current_votes, agent_id, %{
        "vote" => vote,
        "confidence" => confidence,
        "voted_at" => DateTime.utc_now()
      })

    proposal
    |> change(%{votes: new_votes})
    |> check_consensus()
  end

  defp check_consensus(changeset) do
    votes = get_field(changeset, :votes) || %{}

    # Consensus rules:
    # 1. At least 3 agents voted
    # 2. Average confidence > 0.85
    # 3. No strong rejections

    vote_list = Map.values(votes)

    consensus =
      length(vote_list) >= 3 and
        avg_confidence(vote_list) > 0.85 and
        no_strong_rejections?(vote_list)

    if consensus do
      changeset
      |> put_change(:consensus_reached, true)
      |> put_change(:status, "approved")
    else
      changeset
    end
  end

  defp avg_confidence(votes) do
    if Enum.empty?(votes) do
      0.0
    else
      votes
      |> Enum.map(& &1["confidence"])
      |> Enum.sum()
      |> Kernel./(length(votes))
    end
  end

  defp no_strong_rejections?(votes) do
    Enum.all?(votes, fn vote ->
      vote["vote"] != "reject" or vote["confidence"] < 0.7
    end)
  end
end
