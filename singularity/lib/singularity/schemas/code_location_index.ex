defmodule Singularity.Schemas.CodeLocationIndex do
  @moduledoc """
  Ecto schema for code location index.

  Stores indexed codebase files for fast pattern-based navigation.

  Questions answered:
  - "Where is X implemented?" → List of files
  - "What frameworks are used?" → List with files
  - "Where are pgmq microservices?" → Filtered list
  - "What does this file do?" → Pattern summary

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.CodeLocationIndex",
    "purpose": "Fast location index for code artifacts and patterns",
    "role": "schema",
    "layer": "infrastructure",
    "table": "code_location_index",
    "features": ["pattern_search", "framework_detection", "microservice_location"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - id: Primary key (binary_id)
    - filepath: File path relative to codebase root
    - patterns: Array of detected code patterns
    - language: Programming language
    - file_hash: Content hash for deduplication
    - lines_of_code: LOC count for size analysis
    - metadata: JSONB with exports, imports, summary
    - frameworks: Detected frameworks and versions
    - microservice: Microservice type and routing info
    - last_indexed: Timestamp of last indexing
  ```

  ### Anti-Patterns
  - ❌ DO NOT use CodeChunk for location queries - use this index instead
  - ❌ DO NOT store raw code content here - reference CodeFile instead
  - ✅ DO use for answering "where is X?" queries
  - ✅ DO rely on metadata field for dynamic data

  ### Search Keywords
  code_location, index, pattern_search, file_location, frameworks, microservice,
  fast_lookup, navigation, artifact_location, pattern_detection
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "code_location_index" do
    field :filepath, :string
    field :patterns, {:array, :string}, default: []
    field :language, :string
    field :file_hash, :string
    field :lines_of_code, :integer

    # JSONB fields - dynamic data from tool_doc_index
    # exports, imports, summary, etc.
    field :metadata, :map
    # detected frameworks from TechnologyDetector
    field :frameworks, :map
    # type, subjects, routes, etc.
    field :microservice, :map

    field :last_indexed, :utc_datetime

    timestamps()
  end

  @doc false
  def changeset(index, attrs) do
    index
    |> cast(attrs, [
      :filepath,
      :patterns,
      :language,
      :file_hash,
      :lines_of_code,
      :metadata,
      :frameworks,
      :microservice,
      :last_indexed
    ])
    |> validate_required([:filepath, :patterns, :language])
    |> unique_constraint(:filepath)
  end
end
