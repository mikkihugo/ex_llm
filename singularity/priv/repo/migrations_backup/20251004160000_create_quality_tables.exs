defmodule Singularity.Repo.Migrations.CreateQualityTables do
  use Ecto.Migration

  def change do
    create table(:quality_runs) do
      add :tool, :string, null: false
      add :status, :string, null: false
      add :warning_count, :integer, null: false, default: 0
      add :metadata, :map, null: false, default: %{}
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec

      timestamps()
    end

    create index(:quality_runs, [:tool])
    create index(:quality_runs, [:inserted_at])

    create table(:quality_findings) do
      add :run_id, references(:quality_runs, on_delete: :delete_all), null: false
      add :category, :string
      add :message, :text, null: false
      add :file, :string
      add :line, :integer
      add :severity, :string
      add :extra, :map, null: false, default: %{}

      timestamps(updated_at: false)
    end

    create index(:quality_findings, [:run_id])
    create index(:quality_findings, [:severity])
  end
end
