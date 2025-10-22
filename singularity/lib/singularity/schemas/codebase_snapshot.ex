defmodule Singularity.Schemas.CodebaseSnapshot do
  @moduledoc """
  Ecto schema for codebase_snapshots table.
  Stores detected technology snapshots from TechnologyDetector.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "codebase_snapshots" do
    field :codebase_id, :string
    field :snapshot_id, :integer
    field :metadata, :map
    field :summary, :map
    field :detected_technologies, {:array, :string}
    field :features, :map
    field :inserted_at, :utc_datetime
  end

  @doc false
  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :codebase_id,
      :snapshot_id,
      :metadata,
      :summary,
      :detected_technologies,
      :features
    ])
    |> validate_required([:codebase_id, :snapshot_id])
    |> unique_constraint([:codebase_id, :snapshot_id])
  end

  @doc """
  Create or update a codebase snapshot.
  """
  def upsert(repo, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> repo.insert(
      on_conflict: {:replace, [:metadata, :summary, :detected_technologies, :features]},
      conflict_target: [:codebase_id, :snapshot_id]
    )
  end
end
