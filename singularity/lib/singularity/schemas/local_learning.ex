defmodule Singularity.Schemas.LocalLearning do
  @moduledoc """
  Local learning data pending sync to central.

  Tracks template improvements learned from local usage,
  queued for contribution to central knowledge base.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "local_learning" do
    field :artifact_id, :string
    field :version, :string

    # Learning data
    field :usage_data, :map
    field :learned_improvements, :map

    # Sync status
    field :synced_to_central, :boolean, default: false
    field :synced_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(learning, attrs) do
    learning
    |> cast(attrs, [
      :artifact_id,
      :version,
      :usage_data,
      :learned_improvements,
      :synced_to_central,
      :synced_at
    ])
    |> validate_required([:artifact_id, :version, :usage_data])
  end
end
