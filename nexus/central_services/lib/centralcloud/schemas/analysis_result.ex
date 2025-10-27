defmodule CentralCloud.Schemas.AnalysisResult do
  @moduledoc """
  Analysis result schema (timeseries) for package quality metrics.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "analysis_results" do
    belongs_to :package, CentralCloud.Schemas.Package

    field :analysis_type, :string
    field :score, :float
    field :metrics, :map, default: %{}
    field :recommendations, {:array, :string}, default: []
    field :complexity_score, :integer
    field :maintainability_score, :integer
    field :test_coverage, :float

    field :created_at, :utc_datetime
  end

  def changeset(result, attrs) do
    result
    |> cast(attrs, [
      :package_id,
      :analysis_type,
      :score,
      :metrics,
      :recommendations,
      :complexity_score,
      :maintainability_score,
      :test_coverage,
      :created_at
    ])
    |> validate_required([:analysis_type])
    |> validate_inclusion(:analysis_type, ["code_quality", "performance", "architecture"])
    |> foreign_key_constraint(:package_id)
  end
end
