defmodule CentralCloud.TemplateGenerationGlobal do
  @moduledoc """
  Global template generation tracking across all Singularity instances.

  Stores template generation data from ALL instances for cross-instance intelligence.

  ## Schema

  - `template_id` - Template identifier (e.g., "quality_template:elixir-production")
  - `template_version` - Version of template used (e.g., "2.4.0")
  - `generated_at` - When code was generated
  - `answers` - JSONB map of all answers (questions + metadata)
  - `success` - Whether generation succeeded
  - `quality_score` - Quality score of generated code
  - `instance_id` - Which Singularity instance generated this
  - `file_path` - Anonymized file path (e.g., "lib/cache.ex")

  ## Purpose

  Enables CentralCloud to learn patterns like:
  - "72% of instances use `use_ets: true` with GenServer"
  - "GenServer + ETS + one_for_one = 98% success rate across 5 instances"
  - "Template v2.4.0 has 15% higher success rate than v2.3.0"

  ## Privacy

  File paths are anonymized (only relative paths, no user/project names).
  Only metadata and answers are stored, not actual code.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "template_generations_global" do
    field :template_id, :string
    field :template_version, :string
    field :generated_at, :utc_datetime
    field :answers, :map
    field :success, :boolean, default: true
    field :quality_score, :float
    field :instance_id, :string
    field :file_path, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating/updating global generation records.
  """
  def changeset(generation, attrs) do
    generation
    |> cast(attrs, [
      :template_id,
      :template_version,
      :generated_at,
      :answers,
      :success,
      :quality_score,
      :instance_id,
      :file_path
    ])
    |> validate_required([:template_id, :answers, :instance_id])
    |> validate_format(:template_id, ~r/^[a-z_]+:[a-z_-]+$/, message: "must be in format type:name")
  end
end
