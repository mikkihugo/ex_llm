defmodule Singularity.Planning.Schemas.Capability do
  @moduledoc """
  Capability - 3-6 month cross-team feature

  Represents a set of related features that deliver a cohesive capability.
  Inherits WSJF score from parent epic.
  Aligned with SAFe 6.0 Essential framework.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Singularity.Planning.Schemas.{Epic, Feature, CapabilityDependency}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "agent_capability_registry" do
    field :name, :string
    field :description, :string
    field :status, :string, default: "backlog"
    field :wsjf_score, :float, default: 0.0
    field :approved_by, :string

    belongs_to :epic, Epic, foreign_key: :epic_id
    has_many :features, Feature, foreign_key: :capability_id

    # Dependencies
    has_many :capability_dependencies, CapabilityDependency, foreign_key: :capability_id
    has_many :depends_on, through: [:capability_dependencies, :depends_on_capability]

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a capability.

  ## Validations
  - name: required, min 3 chars
  - description: required, min 10 chars
  - status: one of: backlog, analyzing, implementing, validating, done
  """
  def changeset(capability, attrs) do
    capability
    |> cast(attrs, [:epic_id, :name, :description, :status, :wsjf_score, :approved_by])
    |> validate_required([:name, :description])
    |> validate_length(:name, min: 3)
    |> validate_length(:description, min: 10)
    |> validate_inclusion(:status, ["backlog", "analyzing", "implementing", "validating", "done"])
    |> foreign_key_constraint(:epic_id)
  end

  @doc """
  Converts schema to map format used by WorkPlanCoordinator GenServer state.
  """
  def to_state_map(%__MODULE__{} = capability) do
    %{
      id: capability.id,
      name: capability.name,
      description: capability.description,
      epic_id: capability.epic_id,
      wsjf_score: capability.wsjf_score,
      feature_ids: Enum.map(capability.features || [], & &1.id),
      depends_on: Enum.map(capability.depends_on || [], & &1.id),
      status: String.to_atom(capability.status),
      created_at: capability.inserted_at,
      approved_by: capability.approved_by
    }
  end
end
