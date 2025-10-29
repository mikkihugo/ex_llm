defmodule CentralCloud.Schemas.Template do
  @moduledoc """
  Template Schema - Single schema for ALL knowledge artifacts
  
  Handles:
  - Templates: base, code_generation, framework, prompt, quality_standard, workflow, bit
  - Models: model (AI model definitions), complexity_model (ML models)
  - Patterns: task_complexity, pattern
  - Code: code_snippet
  
  All artifacts stored in CentralCloud PostgreSQL with pgvector embeddings,
  distributed via pgflow, and mirrored to Singularity instances.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Pgvector.Ecto.Vector

  @primary_key {:id, :string, autogenerate: false}
  @foreign_key_type :string

  schema "templates" do
    field :category, :string  # base, bit, code_generation, framework, prompt, quality_standard, workflow
    field :metadata, :map  # JSONB: name, description, language, framework, tags, etc.
    field :content, :map  # JSONB: code, snippets, prompt, quality requirements, etc.
    field :extends, :string  # Base template ID
    field :compose, {:array, :string}  # Bit template IDs
    field :quality_standard, :string
    field :usage_stats, :map, default: %{count: 0, success_rate: 0.0, last_used: nil}
    field :quality_score, :float, default: 0.8
    field :embedding, Vector  # 2560-dim vector for semantic search
    field :version, :string, default: "1.0.0"
    field :deprecated, :boolean, default: false
    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime
    field :last_synced_at, :utc_datetime
  end

  @valid_categories [
    # Templates
    "base",
    "bit",
    "code_generation",
    "code_snippet",
    "framework",
    "prompt",
    "quality_standard",
    "workflow",
    # Models
    "model",  # AI model definitions (from models.dev, YAML, custom)
    "complexity_model",  # ML complexity prediction models
    # Patterns
    "pattern",
    "task_complexity"  # Task complexity patterns/definitions
  ]

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :id,
      :category,
      :metadata,
      :content,
      :extends,
      :compose,
      :quality_standard,
      :usage_stats,
      :quality_score,
      :embedding,
      :version,
      :deprecated,
      :created_at,
      :updated_at,
      :last_synced_at
    ])
    |> validate_required([:id, :category, :metadata, :content, :version])
    |> validate_inclusion(:category, @valid_categories)
    |> validate_format(:version, ~r/^\d+\.\d+\.\d+$/, message: "must be semantic version (e.g., 1.0.0)")
    |> validate_metadata()
    |> validate_content()
  end

  defp validate_metadata(changeset) do
    case get_field(changeset, :metadata) do
      %{} = metadata ->
        required_fields = ["name", "description"]
        missing = Enum.reject(required_fields, &Map.has_key?(metadata, &1))
        
        if Enum.empty?(missing) do
          changeset
        else
          add_error(changeset, :metadata, "missing required fields: #{Enum.join(missing, ", ")}")
        end

      _ ->
        add_error(changeset, :metadata, "must be a map")
    end
  end

  defp validate_content(changeset) do
    case get_field(changeset, :content) do
      %{} = _content ->
        changeset  # Content structure validated by category-specific validators

      _ ->
        add_error(changeset, :content, "must be a map")
    end
  end
end
