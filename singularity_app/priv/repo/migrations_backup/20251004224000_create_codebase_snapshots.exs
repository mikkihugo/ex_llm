defmodule Singularity.Repo.Migrations.CreateCodebaseSnapshots do
  use Ecto.Migration

  def up do
    execute("CREATE EXTENSION IF NOT EXISTS timescaledb")

    create table(:codebase_snapshots) do
      add :codebase_id, :string, null: false
      add :snapshot_id, :bigint, null: false
      add :metadata, :map
      add :summary, :map
      add :detected_technologies, {:array, :string}, default: []
      add :features, :map
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    execute("SELECT create_hypertable('codebase_snapshots', 'inserted_at', if_not_exists => TRUE)")
    create unique_index(:codebase_snapshots, [:codebase_id, :snapshot_id])
  end

  def down do
    drop table(:codebase_snapshots)
  end
end
