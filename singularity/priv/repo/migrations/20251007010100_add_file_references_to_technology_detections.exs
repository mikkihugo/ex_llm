defmodule Singularity.Repo.Migrations.AddFileReferencesToTechnologyDetections20251007 do
  use Ecto.Migration

  @moduledoc """
  Add file references to technology_detections table for architecture analysis
  
  This migration adds:
  - analyzed_files: Array of file IDs that were analyzed
  - file_patterns: JSONB with file metadata and patterns
  - file_architecture_patterns: New table for per-file architectural patterns
  """

  def up do
    # Add file reference columns to technology_detections
    alter table(:technology_detections) do
      add :analyzed_files, {:array, :binary_id}, default: []
      add :file_patterns, :map, default: %{}
    end

    # Create index for analyzed_files
    execute("""
      CREATE INDEX IF NOT EXISTS technology_detections_analyzed_files_index
      ON technology_detections (analyzed_files)
    """, "")

    # Create file_architecture_patterns table for per-file analysis
    create_if_not_exists table(:file_architecture_patterns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_id, references(:codebase_chunks, type: :binary_id, on_delete: :delete_all), null: false
      add :detection_id, references(:technology_detections, type: :id, on_delete: :delete_all), null: false
      add :pattern_type, :string, null: false
      add :pattern_data, :map, default: %{}
      add :confidence, :float, default: 0.0
      add :line_number, :integer
      add :code_snippet, :text
      add :metadata, :map, default: %{}
      
      timestamps()
    end

    # Create indexes for file_architecture_patterns
    execute("""
      CREATE INDEX IF NOT EXISTS file_architecture_patterns_file_id_index
      ON file_architecture_patterns (file_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS file_architecture_patterns_detection_id_index
      ON file_architecture_patterns (detection_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS file_architecture_patterns_pattern_type_index
      ON file_architecture_patterns (pattern_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS file_architecture_patterns_confidence_index
      ON file_architecture_patterns (confidence)
    """, "")
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS file_architecture_patterns_file_id_detection_id_pattern_type_key
      ON file_architecture_patterns (file_id, detection_id, pattern_type)
    """, "")

    # Create file_naming_violations table for per-file naming issues
    create_if_not_exists table(:file_naming_violations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :file_id, references(:codebase_chunks, type: :binary_id, on_delete: :delete_all), null: false
      add :detection_id, references(:technology_detections, type: :id, on_delete: :delete_all), null: false
      add :violation_type, :string, null: false
      add :element_name, :string, null: false
      add :line_number, :integer, null: false
      add :severity, :string, default: "warning"
      add :message, :text
      add :suggested_fix, :string
      add :confidence, :float, default: 0.0
      add :metadata, :map, default: %{}
      
      timestamps()
    end

    # Create indexes for file_naming_violations
    execute("""
      CREATE INDEX IF NOT EXISTS file_naming_violations_file_id_index
      ON file_naming_violations (file_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS file_naming_violations_detection_id_index
      ON file_naming_violations (detection_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS file_naming_violations_violation_type_index
      ON file_naming_violations (violation_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS file_naming_violations_severity_index
      ON file_naming_violations (severity)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS file_naming_violations_line_number_index
      ON file_naming_violations (line_number)
    """, "")
  end

  def down do
    # Drop file_naming_violations table
    drop table(:file_naming_violations)

    # Drop file_architecture_patterns table
    drop table(:file_architecture_patterns)

    # Remove file reference columns from technology_detections
    alter table(:technology_detections) do
      remove :analyzed_files
      remove :file_patterns
    end
  end
end