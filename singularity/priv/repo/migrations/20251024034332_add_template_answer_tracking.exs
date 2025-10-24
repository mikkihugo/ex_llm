defmodule Singularity.Repo.Migrations.AddTemplateAnswerTracking do
  use Ecto.Migration

  def change do
    # Track what templates generated what code
    create table(:template_generations) do
      add :template_id, :string, null: false
      add :template_version, :string
      add :generated_at, :utc_datetime, null: false
      add :file_path, :string
      add :answers, :jsonb, null: false
      add :success, :boolean, default: true
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    create index(:template_generations, [:template_id])
    create index(:template_generations, [:file_path])
    create index(:template_generations, [:generated_at])
    create index(:template_generations, [:answers], using: :gin)
  end
end
