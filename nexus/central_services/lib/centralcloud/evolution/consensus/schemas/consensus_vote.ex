defmodule CentralCloud.Evolution.Consensus.Schemas.ConsensusVote do
  @moduledoc """
  Schema for tracking consensus votes on evolution proposals.

  Records votes from all instances with confidence scores and reasoning
  for transparent governance and audit trails.

  ## Table Structure

  - Primary Key: `id` (UUID, autogenerate)
  - Indexes: change_id, instance_id, voted_at
  - Composite Unique: (change_id, instance_id) - one vote per instance per change

  ## Module Identity (JSON)
  ```json
  {
    "module": "CentralCloud.Evolution.Consensus.Schemas.ConsensusVote",
    "purpose": "Track distributed votes for consensus-based governance",
    "role": "schema",
    "layer": "centralcloud",
    "table": "consensus_votes",
    "relationships": {}
  }
  ```

  ## Anti-Patterns

  - ❌ DO NOT allow multiple votes from same instance - use unique constraint
  - ❌ DO NOT delete votes - immutable governance record
  - ✅ DO track confidence with every vote - quality signal
  - ✅ DO record reason - explainable governance
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "consensus_votes" do
    field :change_id, :string
    field :instance_id, :string
    field :vote, :string
    field :confidence, :float
    field :reason, :string
    field :voted_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for recording consensus votes.

  ## Required Fields
  - change_id
  - instance_id
  - vote (must be "approve" or "reject")
  - confidence (0.0-1.0)
  - reason
  - voted_at

  ## Validations
  - vote must be "approve" or "reject"
  - confidence must be between 0.0 and 1.0
  - reason must be at least 10 characters (meaningful explanation)
  """
  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [
      :change_id,
      :instance_id,
      :vote,
      :confidence,
      :reason,
      :voted_at
    ])
    |> validate_required([
      :change_id,
      :instance_id,
      :vote,
      :confidence,
      :reason,
      :voted_at
    ])
    |> validate_inclusion(:vote, ["approve", "reject"])
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_length(:reason, min: 10)
    |> unique_constraint([:change_id, :instance_id])
  end
end
