defmodule Singularity.Repo.Migrations.CreateCodebaseRegistry do
  use Ecto.Migration

  def change do
    create table(:codebase_registry, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :codebase_id, :string, null: false
      add :codebase_path, :string, null: false
      add :codebase_name, :string, null: false
      add :description, :text
      add :language, :string
      add :framework, :string
      add :last_analyzed, :utc_datetime
      add :analysis_status, :string, default: "pending"
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    # Indexes for performance
    create unique_index(:codebase_registry, [:codebase_id])
    create index(:codebase_registry, [:codebase_path])
    create index(:codebase_registry, [:analysis_status])
  end
end
