defmodule Singularity.Repo.Migrations.AddPromptIntelligenceToDependencyCatalog do
  use Ecto.Migration

  def up do
    alter table(:dependency_catalog) do
      add :prompt_templates, :map, default: %{}, null: false
      add :prompt_snippets, :map, default: %{}, null: false
      add :version_guidance, :map, default: %{}, null: false
      add :prompt_usage_stats, :map, default: %{}, null: false
    end

    create table(:dependency_catalog_prompt_usage, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :dependency_id,
          references(:dependency_catalog, type: :binary_id, on_delete: :delete_all),
          null: false

      add :prompt_id, :string, null: false
      add :task, :string
      add :package_context, :map, default: %{}
      add :success, :boolean
      add :feedback, :text
      add :usage_metadata, :map, default: %{}
      add :used_at, :utc_datetime, default: fragment("timezone('utc', now())")

      timestamps(type: :utc_datetime)
    end

    create index(:dependency_catalog_prompt_usage, [:dependency_id])
    create index(:dependency_catalog_prompt_usage, [:prompt_id])
  end

  def down do
    drop table(:dependency_catalog_prompt_usage)

    alter table(:dependency_catalog) do
      remove :prompt_usage_stats
      remove :version_guidance
      remove :prompt_snippets
      remove :prompt_templates
    end
  end
end
