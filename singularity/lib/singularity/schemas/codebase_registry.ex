defmodule Singularity.Schemas.CodebaseRegistry do
  @moduledoc """
  CodebaseRegistry schema - Track and manage registered codebases.

  Stores metadata about codebases that have been indexed:
  - Codebase identification (id, path, name)
  - Description and language/framework info
  - Analysis status and timestamps
  - Flexible metadata storage

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.CodebaseRegistry",
    "purpose": "Central registry of indexed codebases with analysis status tracking",
    "role": "schema",
    "layer": "infrastructure",
    "table": "codebase_registry",
    "relationships": {
      "has_many": "CodeFile - via project_name matching codebase_id",
      "has_many": "CodeChunk - via codebase_id",
      "has_many": "AnalysisRun - analysis runs for this codebase"
    }
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - id: Primary key (binary_id)
    - codebase_id: Unique codebase identifier
    - codebase_path: Filesystem path to codebase
    - codebase_name: Human-readable name
    - description: Codebase description
    - language: Primary programming language
    - framework: Primary framework detected
    - last_analyzed: Timestamp of last analysis
    - analysis_status: Status enum (pending, in_progress, completed, failed)
    - metadata: JSONB for additional codebase metadata

  indexes:
    - unique: codebase_id

  relationships:
    belongs_to: []
    has_many: [CodeFile, CodeChunk, AnalysisRun]
  ```

  ### Anti-Patterns
  - ❌ DO NOT create multiple CodebaseRegistry entries for same codebase
  - ❌ DO NOT bypass analysis_status validation - use enum values only
  - ✅ DO use CodebaseRegistry as single source of truth for codebase metadata
  - ✅ DO update analysis_status when running code analysis

  ### Search Keywords
  codebase registry, indexed codebases, analysis status, codebase metadata,
  project tracking, codebase identification, language detection
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "codebase_registry" do
    field :codebase_id, :string
    field :codebase_path, :string
    field :codebase_name, :string
    field :description, :string
    field :language, :string
    field :framework, :string
    field :last_analyzed, :utc_datetime
    field :analysis_status, :string, default: "pending"
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(registry, attrs) do
    registry
    |> cast(attrs, [
      :codebase_id,
      :codebase_path,
      :codebase_name,
      :description,
      :language,
      :framework,
      :last_analyzed,
      :analysis_status,
      :metadata
    ])
    |> validate_required([:codebase_id, :codebase_path, :codebase_name])
    |> unique_constraint(:codebase_id)
    |> validate_inclusion(:analysis_status, ["pending", "in_progress", "completed", "failed"])
  end
end
