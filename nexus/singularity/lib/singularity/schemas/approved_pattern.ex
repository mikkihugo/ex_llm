defmodule Singularity.Schemas.ApprovedPattern do
  @moduledoc """
  Read-only schema for the replicated `approved_patterns` table.

  CentralCloud publishes high-confidence patterns into this table via
  logical replication. Singularity treats the data as immutable and
  never attempts to write to it directly.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "approved_patterns" do
    field :name, :string
    field :ecosystem, :string
    field :frequency, :integer
    field :confidence, :float
    field :description, :string
    field :examples, :map
    field :best_practices, {:array, :string}
    field :approved_at, :utc_datetime_usec
    field :last_synced_at, :utc_datetime_usec
    field :instances_count, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(pattern, attrs) do
    pattern
    |> cast(attrs, [
      :name,
      :ecosystem,
      :frequency,
      :confidence,
      :description,
      :examples,
      :best_practices,
      :approved_at,
      :last_synced_at,
      :instances_count
    ])
    |> validate_required([:name, :ecosystem])
  end
end
