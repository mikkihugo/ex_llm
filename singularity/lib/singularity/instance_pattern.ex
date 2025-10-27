defmodule Singularity.InstancePattern do
  @moduledoc """
  Schema for instance patterns table.

  Stores patterns learned per instance for cross-instance learning.
  Used by CentralCloud to aggregate and share pattern intelligence.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "instance_patterns" do
    field :instance_id, :string
    field :pattern_name, :string
    field :pattern_type, :string
    field :pattern_data, :map
    field :confidence, :float
    field :learned_at, :utc_datetime_usec
    field :source_codebase, :string
    field :usage_count, :integer, default: 0
    field :last_used_at, :utc_datetime_usec
    field :metadata, :map, default: %{}

    timestamps(updated_at: false)
  end

  @doc false
  def changeset(instance_pattern, attrs) do
    instance_pattern
    |> cast(attrs, [:instance_id, :pattern_name, :pattern_type, :pattern_data, :confidence, :learned_at, :source_codebase, :usage_count, :last_used_at, :metadata])
    |> validate_required([:instance_id, :pattern_name, :pattern_type, :pattern_data, :confidence, :learned_at])
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint([:instance_id, :pattern_name, :pattern_type])
  end
end