defmodule Singularity.Planning.Schemas.Epic do
  @moduledoc """
  Epic - 6-12 month initiative (Business or Enabler)

  Represents large-scale work that delivers significant business value.
  Uses WSJF (Weighted Shortest Job First) for prioritization.
  Aligned with SAFe 6.0 Essential framework.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Singularity.Planning.Schemas.{StrategicTheme, Capability}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "epics" do
    field :name, :string
    field :description, :string
    field :type, :string
    field :status, :string, default: "ideation"

    # WSJF scoring
    field :wsjf_score, :float, default: 0.0
    field :business_value, :integer, default: 5
    field :time_criticality, :integer, default: 5
    field :risk_reduction, :integer, default: 5
    field :job_size, :integer, default: 8

    field :approved_by, :string

    belongs_to :theme, StrategicTheme, foreign_key: :theme_id
    has_many :capabilities, Capability, foreign_key: :epic_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates a changeset for an epic.

  ## Validations
  - name: required, min 3 chars
  - description: required, min 10 chars
  - type: required, one of: business, enabler
  - status: one of: ideation, analysis, implementation, done
  - WSJF inputs: 1-10 for value/criticality/risk, 1-20 for job_size
  """
  def changeset(epic, attrs) do
    epic
    |> cast(attrs, [
      :theme_id,
      :name,
      :description,
      :type,
      :status,
      :business_value,
      :time_criticality,
      :risk_reduction,
      :job_size,
      :approved_by
    ])
    |> validate_required([:name, :description, :type])
    |> validate_length(:name, min: 3)
    |> validate_length(:description, min: 10)
    |> validate_inclusion(:type, ["business", "enabler"])
    |> validate_inclusion(:status, ["ideation", "analysis", "implementation", "done"])
    |> validate_number(:business_value, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_number(:time_criticality, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_number(:risk_reduction, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> validate_number(:job_size, greater_than_or_equal_to: 1, less_than_or_equal_to: 20)
    |> foreign_key_constraint(:theme_id)
    |> calculate_wsjf()
  end

  @doc """
  Calculates WSJF score: (Business Value + Time Criticality + Risk Reduction) / Job Size
  """
  defp calculate_wsjf(changeset) do
    bv = get_field(changeset, :business_value) || 5
    tc = get_field(changeset, :time_criticality) || 5
    rr = get_field(changeset, :risk_reduction) || 5
    js = get_field(changeset, :job_size) || 8

    wsjf = (bv + tc + rr) / max(js, 1)

    put_change(changeset, :wsjf_score, Float.round(wsjf, 2))
  end

  @doc """
  Converts schema to map format used by WorkPlanCoordinator GenServer state.
  """
  def to_state_map(%__MODULE__{} = epic) do
    %{
      id: epic.id,
      name: epic.name,
      description: epic.description,
      type: String.to_atom(epic.type),
      theme_id: epic.theme_id,
      wsjf_score: epic.wsjf_score,
      business_value: epic.business_value,
      time_criticality: epic.time_criticality,
      risk_reduction: epic.risk_reduction,
      job_size: epic.job_size,
      capability_ids: Enum.map(epic.capabilities || [], & &1.id),
      status: String.to_atom(epic.status),
      created_at: epic.inserted_at,
      approved_by: epic.approved_by
    }
  end
end
