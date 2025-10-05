defmodule Singularity.Planning.Schemas.Feature do
  @moduledoc """
  Feature - 1-3 month team deliverable

  Represents work that can be broken down into HTDAG tasks and stories.
  Features are the primary work items that agents execute.
  Aligned with SAFe 6.0 Essential framework.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Singularity.Planning.Schemas.Capability

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "features" do
    field :name, :string
    field :description, :string
    field :status, :string, default: "backlog"
    field :htdag_id, :string
    field :acceptance_criteria, {:array, :string}, default: []
    field :approved_by, :string

    belongs_to :capability, Capability, foreign_key: :capability_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a feature.

  ## Validations
  - name: required, min 3 chars
  - description: required, min 10 chars
  - status: one of: backlog, in_progress, done
  """
  def changeset(feature, attrs) do
    feature
    |> cast(attrs, [
      :capability_id,
      :name,
      :description,
      :status,
      :htdag_id,
      :acceptance_criteria,
      :approved_by
    ])
    |> validate_required([:name, :description])
    |> validate_length(:name, min: 3)
    |> validate_length(:description, min: 10)
    |> validate_inclusion(:status, ["backlog", "in_progress", "done"])
    |> foreign_key_constraint(:capability_id)
  end

  @doc """
  Converts schema to map format used by WorkPlanCoordinator GenServer state.
  """
  def to_state_map(%__MODULE__{} = feature) do
    %{
      id: feature.id,
      name: feature.name,
      description: feature.description,
      capability_id: feature.capability_id,
      htdag_id: feature.htdag_id,
      acceptance_criteria: feature.acceptance_criteria || [],
      status: String.to_atom(feature.status),
      created_at: feature.inserted_at,
      approved_by: feature.approved_by
    }
  end
end
