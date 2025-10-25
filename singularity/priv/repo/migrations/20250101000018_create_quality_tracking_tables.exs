defmodule Singularity.Repo.Migrations.CreateQualityTrackingTables do
  use Ecto.Migration

  @moduledoc """
  Creates quality tracking tables for security and code quality analysis.

  These tables track quality tool executions and their findings:
  - quality_runs: Individual quality tool executions (Sobelow, mix_audit, Dialyzer, etc.)
  - quality_findings: Individual findings/warnings from quality runs

  Related schemas:
  - Singularity.Quality.Run
  - Singularity.Quality.Finding
  """

  def up do
    # ===== QUALITY RUNS TABLE =====
    # Tracks individual quality tool executions
    create_if_not_exists table(:quality_runs) do
      # Tool identification
      add :tool, :string, null: false  # sobelow, mix_audit, dialyzer, custom

      # Run status
      add :status, :string, null: false  # ok, warning, error
      add :warning_count, :integer, null: false, default: 0

      # Execution metadata
      add :metadata, :map, default: %{}
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec

      timestamps()
    end

    # Indexes for quality_runs
    execute("""
      CREATE INDEX IF NOT EXISTS quality_runs_tool_index
      ON quality_runs (tool)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_runs_status_index
      ON quality_runs (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_runs_tool_status_index
      ON quality_runs (tool, status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_runs_inserted_at_index
      ON quality_runs (inserted_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_runs_started_at_index
      ON quality_runs (started_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_runs_metadata_index
      ON quality_runs (metadata)
    """, "")

    # ===== QUALITY FINDINGS TABLE =====
    # Individual findings emitted by quality tool runs
    create_if_not_exists table(:quality_findings) do
      add :run_id, references(:quality_runs, on_delete: :delete_all), null: false

      # Finding details
      add :category, :string
      add :message, :string, null: false
      add :file, :string
      add :line, :integer
      add :severity, :string

      # Additional context
      add :extra, :map, default: %{}

      # Only inserted_at, no updated_at for immutable findings
      timestamps(updated_at: false)
    end

    # Indexes for quality_findings
    execute("""
      CREATE INDEX IF NOT EXISTS quality_findings_run_id_index
      ON quality_findings (run_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_findings_category_index
      ON quality_findings (category)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_findings_severity_index
      ON quality_findings (severity)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_findings_file_index
      ON quality_findings (file)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_findings_run_id_severity_index
      ON quality_findings (run_id, severity)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_findings_category_severity_index
      ON quality_findings (category, severity)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS quality_findings_extra_index
      ON quality_findings (extra)
    """, "")

    # Composite index for common queries
    execute("""
      CREATE INDEX IF NOT EXISTS quality_findings_run_id_category_severity_index
      ON quality_findings (run_id, category, severity)
    """, "")
  end

  def down do
    drop table(:quality_findings)
    drop table(:quality_runs)
  end
end
