defmodule Singularity.Repo.Migrations.ConsolidateMetaRegistry do
  use Ecto.Migration

  @moduledoc """
  Consolidates meta-registry for YOUR codebase comprehension:

  1. Rename features → capabilities (better name for what it tracks)
  2. Add service_structure field (merge MicroserviceAnalyzer data)
  3. Rename codebase_snapshots → technology_detections (clearer name)

  This creates a unified meta-registry that stores:
  - Technology stack detected at analysis time
  - Service structure analysis (TypeScript/Rust/Python/Go services)
  - Architecture patterns
  - Framework/database/messaging detection
  - Capabilities (counts, metrics)

  NOT TimescaleDB - this is YOUR code metadata, queried by codebase_id, not time-series.

  Related modules:
  - Singularity.TechnologyDetections (renamed from CodebaseSnapshots)
  - Singularity.TechnologyAgent (now includes service structure analysis)
  - Singularity.CodebaseRegistry (meta-registry API)
  """

  def up do
    # Step 1: Rename features → capabilities (better name)
    rename table(:codebase_snapshots), :features, to: :capabilities

    # Step 2: Add service_structure field
    alter table(:codebase_snapshots) do
      add :service_structure, :map, default: %{}
    end

    # Step 3: Add GIN index for service_structure queries
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_snapshots_service_structure_index
      ON codebase_snapshots (service_structure)
    """, "")

    # Step 4: Rename table to better reflect its purpose
    rename table(:codebase_snapshots), to: table(:technology_detections)
  end

  def down do
    # Rename back
    rename table(:technology_detections), to: table(:codebase_snapshots)

    # Remove service_structure field
    alter table(:codebase_snapshots) do
      remove :service_structure
    end

    drop_if_exists index(:codebase_snapshots, [:service_structure])

    # Rename capabilities back to features
    rename table(:codebase_snapshots), :capabilities, to: :features
  end
end
