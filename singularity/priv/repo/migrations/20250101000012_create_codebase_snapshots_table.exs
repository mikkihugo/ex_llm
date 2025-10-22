defmodule Singularity.Repo.Migrations.CreateCodebaseSnapshotsTable do
  use Ecto.Migration

  @moduledoc """
  Creates codebase_snapshots table to replace detection_events table.

  The detection_events table was too generic. This migration creates a focused
  codebase_snapshots table that stores detected technology snapshots from
  TechnologyDetector with proper schema matching CodebaseSnapshot.

  Related schema:
  - Singularity.Schemas.CodebaseSnapshot
  """

  def up do
    # ===== CODEBASE SNAPSHOTS TABLE =====
    # Stores detected technology snapshots from TechnologyDetector
    create table(:codebase_snapshots) do
      # Codebase identification
      add :codebase_id, :string, null: false
      add :snapshot_id, :integer, null: false

      # Snapshot data
      add :metadata, :map
      add :summary, :map
      add :detected_technologies, {:array, :string}, default: []
      add :features, :map

      # Only inserted_at, not updated (snapshots are immutable)
      add :inserted_at, :utc_datetime, default: fragment("NOW()")
    end

    # Indexes for codebase_snapshots
    create unique_index(:codebase_snapshots, [:codebase_id, :snapshot_id])
    create index(:codebase_snapshots, [:codebase_id])
    create index(:codebase_snapshots, [:snapshot_id])
    create index(:codebase_snapshots, [:inserted_at])
    create index(:codebase_snapshots, [:detected_technologies], using: :gin)
    create index(:codebase_snapshots, [:metadata], using: :gin)
    create index(:codebase_snapshots, [:features], using: :gin)

    # Drop old detection_events table if it exists
    # Created in migration 20240101000004_create_code_analysis_tables.exs
    execute """
    DROP TABLE IF EXISTS detection_events CASCADE
    """
  end

  def down do
    drop table(:codebase_snapshots)

    # Recreate detection_events table from original migration
    create table(:detection_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :detector, :string, null: false
      add :confidence, :float, null: false
      add :data, :map, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    create index(:detection_events, [:event_type])
    create index(:detection_events, [:detector])
    create index(:detection_events, [:inserted_at])
  end
end
