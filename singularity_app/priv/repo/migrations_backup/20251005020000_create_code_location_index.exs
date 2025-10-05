defmodule Singularity.Repo.Migrations.CreateCodeLocationIndex do
  use Ecto.Migration

  def change do
    create table(:code_location_index, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :filepath, :text, null: false
      add :patterns, {:array, :text}, null: false, default: []
      add :language, :text
      add :file_hash, :text
      add :lines_of_code, :integer

      # JSONB for flexible, dynamic data from tool_doc_index
      add :metadata, :jsonb, default: "{}"  # Exports, imports, summary, etc.
      add :frameworks, :jsonb, default: "{}"  # From TechnologyDetector
      add :microservice, :jsonb  # Type, subjects, routes, etc.

      add :last_indexed, :utc_datetime

      timestamps()
    end

    # Unique filepath
    create unique_index(:code_location_index, [:filepath])

    # GIN index for pattern array queries
    create index(:code_location_index, [:patterns], using: :gin)

    # Index for language filtering
    create index(:code_location_index, [:language])

    # Index for hash-based change detection
    create index(:code_location_index, [:file_hash])

    # GIN indexes for JSONB fields
    create index(:code_location_index, [:metadata], using: :gin)
    create index(:code_location_index, [:frameworks], using: :gin)
    create index(:code_location_index, [:microservice], using: :gin)

    # Dependencies table
    create table(:code_dependencies, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :from_file, references(:code_location_index, column: :filepath, type: :text, on_delete: :delete_all)
      add :to_file, :text
      add :import_type, :text
      add :resolved, :boolean, default: false

      timestamps()
    end

    create index(:code_dependencies, [:from_file])
    create index(:code_dependencies, [:to_file])
    create unique_index(:code_dependencies, [:from_file, :to_file, :import_type])
  end
end
