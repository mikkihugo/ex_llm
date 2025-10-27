defmodule Singularity.Repo.Migrations.CreateCodebaseRegistry do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:codebase_registry, primary_key: false) do
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
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS codebase_registry_codebase_id_key
      ON codebase_registry (codebase_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_registry_codebase_path_index
      ON codebase_registry (codebase_path)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS codebase_registry_analysis_status_index
      ON codebase_registry (analysis_status)
    """, "")
  end
end
