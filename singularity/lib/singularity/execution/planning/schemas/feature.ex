defmodule Singularity.Execution.Planning.Schemas.Feature do
  @moduledoc """
  Feature schema for 1-3 month team deliverables with HTDAG integration and SAFe 6.0 Essential framework alignment.

  Represents work that can be broken down into HTDAG tasks and stories
  with acceptance criteria tracking and integration with capabilities
  for autonomous agent execution and work planning.

  ## Integration Points

  This module integrates with:
  - `Singularity.Execution.Planning.Schemas.Capability` - Capability relationships (belongs_to :capability)
  - HTDAG system - Task decomposition (htdag_id field for HTDAG integration)
  - PostgreSQL table: `safe_methodology_features` (stores feature data)

  ## Usage

      # Create changeset
      changeset = Feature.changeset(%Feature{}, %{
        name: "User Authentication",
        description: "Implement OAuth2-based user authentication",
        capability_id: "cap-123",
        acceptance_criteria: ["User can login with Google", "Session is maintained"]
      })
      # => #Ecto.Changeset<...>

      # Convert to state map
      state_map = Feature.to_state_map(feature)
      # => %{id: "123", name: "User Authentication", htdag_id: "htdag-456", ...}
  """

  use Ecto.Schema
  import Ecto.Changeset

  # INTEGRATION: Capability relationships (belongs_to association)
  alias Singularity.Execution.Planning.Schemas.Capability

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "safe_methodology_features" do
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
