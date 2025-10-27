defmodule Singularity.Execution.Planning.Schemas.Capability do
  @moduledoc """
  Capability schema for 3-6 month cross-team features with dependency management and SAFe 6.0 Essential framework alignment.

  Represents a set of related features that deliver a cohesive capability
  with dependency tracking, WSJF score inheritance from parent epic,
  and integration with features and other capabilities.

  ## AI Navigation Metadata

  ### Module Identity
  ```json
  {
    "module": "Singularity.Execution.Planning.Schemas.Capability",
    "purpose": "Stores 3-6 month cross-team capabilities with dependency tracking",
    "role": "schema",
    "layer": "domain_services",
    "table": "agent_capability_registry",
    "framework": "SAFe 6.0 Essential with dependency management",
    "relationships": ["belongs_to: Epic", "has_many: Feature", "has_many: CapabilityDependency"]
  }
  ```

  ### Anti-Patterns
  - ❌ DO NOT create circular dependencies - validation prevents this
  - ❌ DO NOT use Feature for cross-team work - use Capability
  - ✅ DO use this for 3-6 month cross-team capabilities
  - ✅ DO track dependencies for proper work ordering

  ### Search Keywords
  capability, SAFe 6.0, cross-team feature, dependency tracking, WSJF inheritance,
  3-6 month work, capability dependency, work ordering, capability registry

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.Schemas.Epic` - Epic relationships (belongs_to :epic)
  - `Singularity.Execution.Planning.Schemas.Feature` - Feature relationships (has_many :features)
  - `Singularity.Execution.Planning.Schemas.CapabilityDependency` - Dependency management (has_many :capability_dependencies)
  - PostgreSQL table: `agent_capability_registry` (stores capability data)

  ## Usage

      # Create changeset
      changeset = Capability.changeset(%Capability{}, %{
        name: "Service Mesh",
        description: "Implement service mesh for microservice communication",
        epic_id: "epic-123",
        status: "backlog"
      })
      # => #Ecto.Changeset<...>

      # Convert to state map
      state_map = Capability.to_state_map(capability)
      # => %{id: "123", name: "Service Mesh", feature_ids: [...], ...}
  """

  use Ecto.Schema
  import Ecto.Changeset

  # INTEGRATION: Schema relationships (epic, features, and dependencies)
  alias Singularity.Execution.Planning.Schemas.{Epic, Feature, CapabilityDependency}

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
