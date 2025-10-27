defmodule Singularity.Schemas.FileArchitecturePattern do
  @moduledoc """
  Schema for per-file architectural patterns detected during analysis.

  Stores architectural patterns found in individual files, linked to both
  the file and the detection run that found them.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.FileArchitecturePattern",
    "purpose": "Per-file architectural patterns detected and their confidence scores",
    "role": "schema",
    "layer": "analysis",
    "table": "file_architecture_patterns",
    "features": ["pattern_detection", "confidence_scoring", "architectural_analysis"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - file_id: Reference to code file
    - detection_id: Reference to detection run
    - pattern_type: Type of architectural pattern (MVC, CQRS, etc.)
    - pattern_data: JSONB with pattern details
    - confidence: Confidence score (0.0-1.0)
    - line_number: Where pattern starts in file
  ```

  ### Anti-Patterns
  - ❌ DO NOT store raw patterns - use codebase-level summaries
  - ❌ DO NOT duplicate TechnologyPattern data
  - ✅ DO use for fine-grained per-file pattern tracking
  - ✅ DO rely on this for architecture visualization

  ### Search Keywords
  architecture, patterns, architectural_analysis, design_patterns, pattern_detection,
  file_analysis, confidence_scoring, pattern_type, code_structure
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "file_architecture_patterns" do
    field :file_id, :binary_id
    field :detection_id, :id
    field :pattern_type, :string
    field :pattern_data, :map, default: %{}
    field :confidence, :float, default: 0.0
    field :line_number, :integer
    field :code_snippet, :string
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(pattern, attrs) do
    pattern
    |> cast(attrs, [
      :file_id,
      :detection_id,
      :pattern_type,
      :pattern_data,
      :confidence,
      :line_number,
      :code_snippet,
      :metadata
    ])
    |> validate_required([:file_id, :detection_id, :pattern_type])
    |> validate_inclusion(:pattern_type, [
      "microservice",
      "event_driven",
      "hexagonal",
      "layered",
      "clean_architecture",
      "cqrs",
      "event_sourcing",
      "saga",
      "api_gateway",
      "service_mesh"
    ])
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:line_number, greater_than: 0)
    |> unique_constraint([:file_id, :detection_id, :pattern_type])
  end

  @doc """
  Create a new file architecture pattern.
  """
  def create(repo, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> repo.insert()
  end

  @doc """
  Get patterns for a specific file.
  """
  def for_file(repo, file_id) do
    import Ecto.Query

    from(p in __MODULE__,
      where: p.file_id == ^file_id,
      order_by: [desc: p.confidence]
    )
    |> repo.all()
  end

  @doc """
  Get patterns for a specific detection run.
  """
  def for_detection(repo, detection_id) do
    import Ecto.Query

    from(p in __MODULE__,
      where: p.detection_id == ^detection_id,
      order_by: [desc: p.confidence]
    )
    |> repo.all()
  end

  @doc """
  Get patterns by type across all files.
  """
  def by_pattern_type(repo, pattern_type) do
    import Ecto.Query

    from(p in __MODULE__,
      where: p.pattern_type == ^pattern_type,
      order_by: [desc: p.confidence]
    )
    |> repo.all()
  end
end
