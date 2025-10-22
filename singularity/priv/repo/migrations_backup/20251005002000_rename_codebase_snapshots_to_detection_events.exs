defmodule Singularity.Repo.Migrations.RenameCodebaseSnapshotsToDetectionEvents do
  use Ecto.Migration

  def up do
    # Rename table to reflect it's an event log of detections, not code snapshots
    # TimescaleDB hypertable for time-series analysis
    execute "ALTER TABLE codebase_snapshots RENAME TO detection_events"

    # Update hypertable metadata (TimescaleDB stores table name internally)
    # Note: TimescaleDB automatically handles hypertable rename

    # Rename index
    execute "ALTER INDEX codebase_snapshots_codebase_id_snapshot_id_index RENAME TO detection_events_codebase_id_snapshot_id_index"
  end

  def down do
    # Reverse the rename
    execute "ALTER TABLE detection_events RENAME TO codebase_snapshots"
    execute "ALTER INDEX detection_events_codebase_id_snapshot_id_index RENAME TO codebase_snapshots_codebase_id_snapshot_id_index"
  end
end
