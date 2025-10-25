defmodule Singularity.Repo.Migrations.AddTemplateAnswerTracking do
  use Ecto.Migration

  def change do
    # Track what templates generated what code
    create_if_not_exists table(:template_generations) do
      add :template_id, :string, null: false
      add :template_version, :string
      add :generated_at, :utc_datetime, null: false
      add :file_path, :string
      add :answers, :jsonb, null: false
      add :success, :boolean, default: true
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS template_generations_template_id_index
      ON template_generations (template_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS template_generations_file_path_index
      ON template_generations (file_path)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS template_generations_generated_at_index
      ON template_generations (generated_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS template_generations_answers_index
      ON template_generations (answers)
    """, "")
  end
end
