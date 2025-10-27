defmodule CentralCloud.Repo.Migrations.CreateTemplateGenerationsGlobal do
  use Ecto.Migration

  def change do
    create table(:template_generations_global, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_id, :string, null: false
      add :template_version, :string
      add :generated_at, :utc_datetime, null: false
      add :answers, :jsonb, null: false
      add :success, :boolean, default: true
      add :quality_score, :float
      add :instance_id, :string, null: false
      add :file_path, :string

      timestamps(type: :utc_datetime)
    end

    # Index for querying by template
    create index(:template_generations_global, [:template_id])

    # Index for querying by instance
    create index(:template_generations_global, [:instance_id])

    # Index for time-based queries
    create index(:template_generations_global, [:generated_at])

    # GIN index for JSONB answer queries
    create index(:template_generations_global, [:answers], using: :gin)

    # Composite index for answer pattern queries (template + success + quality)
    create index(:template_generations_global, [:template_id, :success, :quality_score])

    # Composite index for instance-specific queries
    create index(:template_generations_global, [:template_id, :instance_id])
  end
end
