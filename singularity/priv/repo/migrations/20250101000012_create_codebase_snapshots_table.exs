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
    create_if_not_exists table(:codebase_snapshots) do
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
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS codebase_snapshots_codebase_id_snapshot_id_key
      ON codebase_snapshots (codebase_id, snapshot_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_snapshots_codebase_id_index
      ON codebase_snapshots (codebase_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_snapshots_snapshot_id_index
      ON codebase_snapshots (snapshot_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_snapshots_inserted_at_index
      ON codebase_snapshots (inserted_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_snapshots_detected_technologies_index
      ON codebase_snapshots (detected_technologies)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_snapshots_metadata_index
      ON codebase_snapshots (metadata)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_snapshots_features_index
      ON codebase_snapshots (features)
    """, "")

    # Drop old detection_events table if it exists
    # Created in migration 20240101000004_create_code_analysis_tables.exs
    execute """
    DROP TABLE IF EXISTS detection_events CASCADE
    """
  end

  def down do
    drop table(:codebase_snapshots)

    # Recreate detection_events table from original migration
    create_if_not_exists table(:detection_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_type, :string, null: false
      add :detector, :string, null: false
      add :confidence, :float, null: false
      add :data, :map, null: false
      add :metadata, :map, default: %{}
      timestamps()
    end

    execute("""
      CREATE INDEX IF NOT EXISTS detection_events_event_type_index
      ON detection_events (event_type)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS detection_events_detector_index
      ON detection_events (detector)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS detection_events_inserted_at_index
      ON detection_events (inserted_at)
    """, "")
  end
end
