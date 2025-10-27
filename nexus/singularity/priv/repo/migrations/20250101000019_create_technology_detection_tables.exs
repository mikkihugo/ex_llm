defmodule Singularity.Repo.Migrations.CreateTechnologyDetectionTables do
  use Ecto.Migration

  @moduledoc """
  Creates technology detection tables for framework/language/tool detection.

  Replaces the generic 'technology_knowledge' table with two focused tables:
  - technology_patterns: Detection patterns for technologies (file patterns, commands, etc.)
  - technology_templates: Code generation templates for technologies

  These tables support:
  - Self-learning technology detection
  - Code generation from templates
  - Technology-specific build/dev/test commands

  Related schemas:
  - Singularity.Schemas.TechnologyPattern
  - Singularity.Schemas.TechnologyTemplate
  """

  def up do
    # ===== TECHNOLOGY PATTERNS TABLE =====
    # Technology detection patterns (formerly framework_detection_patterns)
    create_if_not_exists table(:technology_patterns) do
      # Technology identification
      add :technology_name, :string, null: false
      add :technology_type, :string, null: false  # framework, language, tool, runtime
      add :version_pattern, :string

      # File patterns for detection
      add :file_patterns, {:array, :string}, default: []
      add :directory_patterns, {:array, :string}, default: []
      add :config_files, {:array, :string}, default: []

      # Commands
      add :build_command, :string
      add :dev_command, :string
      add :install_command, :string
      add :test_command, :string

      # Metadata
      add :output_directory, :string
      add :confidence_weight, :float, default: 1.0

      # Self-learning metrics
      add :detection_count, :integer, default: 0
      add :success_rate, :float, default: 1.0
      add :last_detected_at, :utc_datetime

      # Extended metadata (for code patterns, detector signatures, etc.)
      add :extended_metadata, :map

      # Vector for semantic similarity (commented out until pgvector configured)
#       ##  add :pattern_embedding, :vector, size: 768  # pgvector - install via separate migration

      add :created_at, :utc_datetime, default: fragment("NOW()")
      add :updated_at, :utc_datetime, default: fragment("NOW()")
    end

    # Indexes for technology_patterns
    execute("""
      CREATE INDEX IF NOT EXISTS technology_patterns_technology_name_index
      ON technology_patterns (technology_name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_patterns_technology_type_index
      ON technology_patterns (technology_type)
    """, "")
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS technology_patterns_technology_name_technology_type_key
      ON technology_patterns (technology_name, technology_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_patterns_detection_count_index
      ON technology_patterns (detection_count)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_patterns_success_rate_index
      ON technology_patterns (success_rate)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_patterns_last_detected_at_index
      ON technology_patterns (last_detected_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_patterns_extended_metadata_index
      ON technology_patterns (extended_metadata)
    """, "")

    # ===== TECHNOLOGY TEMPLATES TABLE =====
    # Code generation templates for technologies
    create_if_not_exists table(:technology_templates) do
      # Template identification
      add :identifier, :string, null: false
      add :category, :string, null: false
      add :version, :string
      add :source, :string

      # Template content (JSON structure)
      add :template, :map, null: false

      # Metadata
      add :metadata, :map, default: %{}
      add :checksum, :string

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for technology_templates
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS technology_templates_identifier_key
      ON technology_templates (identifier)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_templates_category_index
      ON technology_templates (category)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_templates_version_index
      ON technology_templates (version)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_templates_category_version_index
      ON technology_templates (category, version)
    """, "")

    # Drop old technology_knowledge table if it exists
    # This table was created in migration 20240101000003 but is being replaced
    execute """
    DROP TABLE IF EXISTS technology_knowledge CASCADE
    """
  end

  def down do
    drop table(:technology_templates)
    drop table(:technology_patterns)

    # Recreate technology_knowledge table from original migration
    create_if_not_exists table(:technology_knowledge, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :technology, :string, null: false
      add :category, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :template, :text
      add :examples, {:array, :text}, default: []
      add :best_practices, :text
      add :antipatterns, {:array, :string}, default: []
      add :metadata, :map, default: %{}# 
#       add :embedding, :vector, size: 768  # pgvector - install via separate migration
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS technology_knowledge_technology_category_index
      ON technology_knowledge (technology, category)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS technology_knowledge_name_index
      ON technology_knowledge (name)
    """, "")
  end
end
