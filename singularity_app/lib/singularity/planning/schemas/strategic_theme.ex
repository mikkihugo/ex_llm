defmodule Singularity.Planning.Schemas.StrategicTheme do
  @moduledoc """
  Strategic Theme schema for 3-5 year vision areas with SAFe 6.0 Essential framework alignment.

  Represents high-level strategic objectives that guide epic planning and
  provide long-term vision direction for autonomous software development
  with BLOC (Business Value, Learning, Operations, Compliance) tracking.

  ## Integration Points

  This module integrates with:
  - `Singularity.Planning.Schemas.Epic` - Epic relationships (has_many :epics)
  - PostgreSQL table: `strategic_themes` (stores strategic theme data)

  ## Usage

      # Create changeset
      changeset = StrategicTheme.changeset(%StrategicTheme{}, %{
        name: "Observability Platform",
        description: "Comprehensive monitoring and observability",
        target_bloc: 3.0,
        priority: 1
      })
      # => #Ecto.Changeset<...>

      # Convert to state map
      state_map = StrategicTheme.to_state_map(theme)
      # => %{id: "123", name: "Observability Platform", ...}
  """

  use Ecto.Schema
  import Ecto.Changeset

  # INTEGRATION: Epic relationships (has_many association)
  alias Singularity.Planning.Schemas.Epic

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "strategic_themes" do
    field :name, :string
    field :description, :string
    field :target_bloc, :float, default: 0.0
    field :priority, :integer, default: 0
    field :status, :string, default: "active"
    field :approved_by, :string

    has_many :epics, Epic, foreign_key: :theme_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a strategic theme.

  ## Validations
  - name: required, min 3 chars
  - description: required, min 10 chars
  - target_bloc: required, >= 0
  - priority: required, >= 0
  - status: required, one of: active, completed, archived
  """
  def changeset(theme, attrs) do
    theme
    |> cast(attrs, [:name, :description, :target_bloc, :priority, :status, :approved_by])
    |> validate_required([:name, :description])
    |> validate_length(:name, min: 3)
    |> validate_length(:description, min: 10)
    |> validate_number(:target_bloc, greater_than_or_equal_to: 0)
    |> validate_number(:priority, greater_than_or_equal_to: 0)
    |> validate_inclusion(:status, ["active", "completed", "archived"])
  end

  @doc """
  Converts schema to map format used by WorkPlanCoordinator GenServer state.
  """
  def to_state_map(%__MODULE__{} = theme) do
    %{
      id: theme.id,
      name: theme.name,
      description: theme.description,
      target_bloc: theme.target_bloc,
      priority: theme.priority,
      epic_ids: Enum.map(theme.epics || [], & &1.id),
      created_at: theme.inserted_at,
      approved_by: theme.approved_by
    }
  end
end
