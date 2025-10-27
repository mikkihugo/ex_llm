defmodule Singularity.Schemas.InstancePattern do
  @moduledoc """
  Schema for tracking pattern detections across instances.

  This table stores individual pattern detections from different instances
  to enable consensus calculation and cross-instance learning.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "instance_patterns" do
    field :pattern_key, :string, null: false
    field :instance_id, :string, null: false
    field :confidence_score, :float, null: false
    field :detected_at, :utc_datetime, null: false
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(instance_pattern, attrs) do
    instance_pattern
    |> cast(attrs, [:pattern_key, :instance_id, :confidence_score, :detected_at, :metadata])
    |> validate_required([:pattern_key, :instance_id, :confidence_score, :detected_at])
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint([:pattern_key, :instance_id])
  end
end