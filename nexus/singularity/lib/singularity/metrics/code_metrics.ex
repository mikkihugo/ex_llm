defmodule Singularity.Metrics.CodeMetrics do
  @moduledoc """
  CodeMetrics - Ecto schema for storing AI-powered code metrics

  Stores comprehensive code analysis metrics calculated by the Rust NIF engine:
  - Type Safety Score (0-100)
  - Dependency Coupling Score (0-100)
  - Error Handling Coverage (0-100)
  - Plus traditional metrics: complexity, LOC, etc.

  ## Example

      iex> Singularity.Metrics.CodeMetrics.create(%{
      ...>   file_path: "lib/my_module.ex",
      ...>   language: "elixir",
      ...>   type_safety_score: 85.5,
      ...>   coupling_score: 72.0,
      ...>   error_handling_score: 90.0
      ...> })
      {:ok, metrics}
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID

  schema "code_metrics" do
    # File & Language
    field :file_path, :string
    field :language, :string
    field :project_id, :string

    # AI-Powered Metrics (0-100 scale)
    field :type_safety_score, :float
    # {annotation_coverage, generics, unsafe_ratio, ...}
    field :type_safety_details, :map

    field :coupling_score, :float
    # {import_density, cyclic_dependencies, ...}
    field :coupling_details, :map

    field :error_handling_score, :float
    # {error_type_coverage, unhandled_paths, ...}
    field :error_handling_details, :map

    # Traditional Metrics
    field :cyclomatic_complexity, :integer
    field :cognitive_complexity, :integer
    field :lines_of_code, :integer
    field :comment_lines, :integer
    field :blank_lines, :integer
    field :maintainability_index, :float

    # Composite Scores
    field :overall_quality_score, :float
    # Weighted factors breakdown
    field :overall_quality_factors, :map

    # Analysis Context
    # SHA256 of code for deduplication
    field :code_hash, :string
    field :analysis_timestamp, :utc_datetime_usec
    field :git_commit, :string
    field :branch, :string

    # Enrichment Data (from PostgreSQL pattern database)
    field :similar_patterns_found, :integer, default: 0
    # Similarity scores to known patterns
    field :pattern_matches, :map
    field :refactoring_opportunities, :integer, default: 0
    # Predicted test coverage (0-1)
    field :test_coverage_predicted, :float

    # Status & Metadata
    # analyzed, enriched, anomaly
    field :status, :string, default: "analyzed"
    field :error_message, :string
    field :processing_time_ms, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Create a new code metrics record with validation
  """
  def create(attrs \\ %{}) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Singularity.Repo.insert()
  end

  @doc """
  Update an existing code metrics record
  """
  def update(metrics, attrs) do
    metrics
    |> changeset(attrs)
    |> Singularity.Repo.update()
  end

  @doc """
  Fetch metrics for a specific file
  """
  def get_by_file_path(file_path) do
    Singularity.Repo.get_by(__MODULE__, file_path: file_path)
  end

  @doc """
  Get metrics for multiple files ordered by quality score (descending)
  """
  def list_by_language(language, limit \\ 50) do
    __MODULE__
    |> where(language: ^language)
    |> order_by(desc: :overall_quality_score)
    |> limit(^limit)
    |> Singularity.Repo.all()
  end

  @doc """
  Find files with low type safety scores (< 50)
  """
  def risky_type_safety(language \\ nil) do
    query =
      __MODULE__
      |> where([m], m.type_safety_score < 50.0)
      |> order_by(asc: :type_safety_score)

    query =
      case language do
        nil -> query
        lang -> where(query, language: ^lang)
      end

    Singularity.Repo.all(query)
  end

  @doc """
  Find high coupling modules (> 70) that need refactoring
  """
  def high_coupling_modules(language \\ nil) do
    query =
      __MODULE__
      |> where([m], m.coupling_score > 70.0)
      |> order_by(desc: :coupling_score)

    query =
      case language do
        nil -> query
        lang -> where(query, language: ^lang)
      end

    Singularity.Repo.all(query)
  end

  @doc """
  Get average metrics across all files in a language
  """
  def average_by_language(language) do
    __MODULE__
    |> where(language: ^language)
    |> select([m], %{
      avg_type_safety: avg(m.type_safety_score),
      avg_coupling: avg(m.coupling_score),
      avg_error_handling: avg(m.error_handling_score),
      avg_quality: avg(m.overall_quality_score),
      file_count: count(m.id)
    })
    |> Singularity.Repo.one()
  end

  @doc """
  Changeset for validation and casting
  """
  def changeset(metrics, attrs) do
    metrics
    |> cast(attrs, [
      :file_path,
      :language,
      :project_id,
      :type_safety_score,
      :type_safety_details,
      :coupling_score,
      :coupling_details,
      :error_handling_score,
      :error_handling_details,
      :cyclomatic_complexity,
      :cognitive_complexity,
      :lines_of_code,
      :comment_lines,
      :blank_lines,
      :maintainability_index,
      :overall_quality_score,
      :overall_quality_factors,
      :code_hash,
      :analysis_timestamp,
      :git_commit,
      :branch,
      :similar_patterns_found,
      :pattern_matches,
      :refactoring_opportunities,
      :test_coverage_predicted,
      :status,
      :error_message,
      :processing_time_ms
    ])
    |> validate_required([:file_path, :language])
    |> validate_number(:type_safety_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_number(:coupling_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_number(:error_handling_score,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 100.0
    )
    |> validate_inclusion(:status, ["analyzed", "enriched", "anomaly"])
    |> unique_constraint(:code_hash)
  end
end
