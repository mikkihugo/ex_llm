defmodule Singularity.Repo.Migrations.CreateTechnologyTemplates do
  use Ecto.Migration

  def change do
    create table(:technology_templates) do
      add :identifier, :text, null: false
      add :category, :text, null: false
      add :version, :text
      add :source, :text, default: "manual"
      add :template, :map, null: false
      add :metadata, :map, default: %{}
      add :checksum, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:technology_templates, [:identifier])
    create index(:technology_templates, [:category])

    create constraint(:technology_templates, :template_is_object,
      check: "jsonb_typeof(template::jsonb) = 'object'")
  end
end
