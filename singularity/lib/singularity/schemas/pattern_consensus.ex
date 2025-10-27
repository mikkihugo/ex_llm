defmodule Singularity.Schemas.PatternConsensus do
  @moduledoc """
  Schema for storing pattern consensus across instances.

  This table aggregates pattern confidence scores from multiple instances
  to determine the most reliable patterns and enable intelligent enhancement.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:pattern_key, :string, []}
  @foreign_key_type :binary_id
  schema "pattern_consensus" do
    field :total_instances, :integer
    field :average_confidence, :float
    field :consensus_level, :string

    timestamps()
  end

  @doc false
  def changeset(pattern_consensus, attrs) do
    pattern_consensus
    |> cast(attrs, [:pattern_key, :total_instances, :average_confidence, :consensus_level, :updated_at])
    |> validate_required([:pattern_key, :total_instances, :average_confidence, :consensus_level, :updated_at])
    |> validate_number(:average_confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_inclusion(:consensus_level, ["low", "medium", "high", "very_high"])
  end
end