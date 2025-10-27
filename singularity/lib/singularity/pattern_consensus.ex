defmodule Singularity.PatternConsensus do
  @moduledoc """
  Schema for pattern consensus table.

  Stores cross-instance consensus patterns that have been validated
  across multiple Singularity instances. Used for high-confidence pattern sharing.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "pattern_consensus" do
    field :pattern_name, :string
    field :pattern_type, :string
    field :consensus_data, :map
    field :consensus_confidence, :float
    field :instance_count, :integer
    field :last_updated, :utc_datetime_usec
    field :metadata, :map, default: %{}

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(pattern_consensus, attrs) do
    pattern_consensus
    |> cast(attrs, [:pattern_name, :pattern_type, :consensus_data, :consensus_confidence, :instance_count, :last_updated, :metadata])
    |> validate_required([:pattern_name, :pattern_type, :consensus_data, :consensus_confidence, :instance_count, :last_updated])
    |> validate_number(:consensus_confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:instance_count, greater_than: 0)
    |> unique_constraint([:pattern_name, :pattern_type], name: :pattern_consensus_unique_idx)
  end
end