defmodule Singularity.Planning.Schemas.StrategicTheme do
  @moduledoc """
  Strategic Theme - 3-5 year vision area

  Represents high-level strategic objectives that guide epic planning.
  Aligned with SAFe 6.0 Essential framework.
  """

  use Ecto.Schema
  import Ecto.Changeset

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
