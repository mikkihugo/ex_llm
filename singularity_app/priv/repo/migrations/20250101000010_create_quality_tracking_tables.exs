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
    create table(:quality_runs) do
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
    create index(:quality_runs, [:tool])
    create index(:quality_runs, [:status])
    create index(:quality_runs, [:tool, :status])
    create index(:quality_runs, [:inserted_at])
    create index(:quality_runs, [:started_at])
    create index(:quality_runs, [:metadata], using: :gin)

    # ===== QUALITY FINDINGS TABLE =====
    # Individual findings emitted by quality tool runs
    create table(:quality_findings) do
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
    create index(:quality_findings, [:run_id])
    create index(:quality_findings, [:category])
    create index(:quality_findings, [:severity])
    create index(:quality_findings, [:file])
    create index(:quality_findings, [:run_id, :severity])
    create index(:quality_findings, [:category, :severity])
    create index(:quality_findings, [:extra], using: :gin)

    # Composite index for common queries
    create index(:quality_findings, [:run_id, :category, :severity])
  end

  def down do
    drop table(:quality_findings)
    drop table(:quality_runs)
  end
end
