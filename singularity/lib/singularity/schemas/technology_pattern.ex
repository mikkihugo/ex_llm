defmodule Singularity.Schemas.TechnologyPattern do
  @moduledoc """
  Ecto schema for technology_patterns table (formerly framework_detection_patterns).
  Stores technology detection patterns for frameworks, languages, and tools.

  ## AI Navigation Metadata

  ### Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Schemas.TechnologyPattern",
    "purpose": "Detection patterns for technologies (frameworks, languages, tools)",
    "role": "schema",
    "layer": "infrastructure",
    "table": "technology_patterns",
    "features": ["pattern_detection", "version_detection", "technology_identification"]
  }
  ```

  ### Key Fields (YAML)
  ```yaml
  fields:
    - technology_name: Technology identifier (react, express, tokio, etc.)
    - technology_type: Type (framework, language, database, etc.)
    - version_pattern: Regex for detecting versions
    - detection_patterns: Array of JSONB patterns for matching
  ```

  ### Anti-Patterns
  - ❌ DO NOT use for storing detected technologies - use TechnologyDetection
  - ❌ DO NOT duplicate patterns from package metadata
  - ✅ DO use for defining detection logic
  - ✅ DO rely on version_pattern for version identification

  ### Search Keywords
  technology_patterns, detection_patterns, framework_detection, language_detection,
  version_detection, technology_identification, pattern_matching
  ```
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :id, autogenerate: true}
  schema "technology_patterns" do
    field :technology_name, :string
    field :technology_type, :string
    field :version_pattern, :string

    # File patterns for detection
    field :file_patterns, {:array, :string}, default: []
    field :directory_patterns, {:array, :string}, default: []
    field :config_files, {:array, :string}, default: []

    # Commands
    field :build_command, :string
    field :dev_command, :string
    field :install_command, :string
    field :test_command, :string

    # Metadata
    field :output_directory, :string
    field :confidence_weight, :float, default: 1.0

    # Self-learning metrics
    field :detection_count, :integer, default: 0
    field :success_rate, :float, default: 1.0
    field :last_detected_at, :utc_datetime

    # Extended metadata (for code patterns, detector signatures, etc.)
    field :extended_metadata, :map

    # Vector for semantic similarity
    # field :pattern_embedding, Pgvector.Ecto.Vector  # Uncomment when pgvector is configured

    field :created_at, :utc_datetime
    field :updated_at, :utc_datetime
  end

  @doc false
  def changeset(pattern, attrs) do
    pattern
    |> cast(attrs, [
      :technology_name,
      :technology_type,
      :version_pattern,
      :file_patterns,
      :directory_patterns,
      :config_files,
      :build_command,
      :dev_command,
      :install_command,
      :test_command,
      :output_directory,
      :confidence_weight,
      :detection_count,
      :success_rate,
      :last_detected_at,
      :extended_metadata
    ])
    |> validate_required([:technology_name, :technology_type])
    |> unique_constraint([:technology_name, :technology_type])
  end

  @doc """
  Get file patterns for template variables extraction.
  """
  def file_patterns_query do
    from p in __MODULE__,
      where:
        not is_nil(p.file_patterns) and fragment("jsonb_array_length(?)", p.file_patterns) > 0,
      select: fragment("jsonb_array_elements_text(?)", p.file_patterns)
  end

  @doc """
  Get config files for template variables extraction.
  """
  def config_files_query do
    from p in __MODULE__,
      where: not is_nil(p.config_files) and fragment("jsonb_array_length(?)", p.config_files) > 0,
      select: fragment("jsonb_array_elements_text(?)", p.config_files)
  end

  @doc """
  Get code patterns from extended_metadata.
  """
  def code_patterns_query do
    from p in __MODULE__,
      where: fragment("? \\? ?", p.extended_metadata, "detect"),
      select: fragment("jsonb_path_query_array(?, '$.detect.patterns[*]')", p.extended_metadata)
  end
end
