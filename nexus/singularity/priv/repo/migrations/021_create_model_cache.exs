defmodule Singularity.Repo.Migrations.CreateModelCache do
  use Ecto.Migration

  def change do
    create table(:model_cache, primary_key: false) do
      add :key, :string, primary_key: true, null: false
      add :content, :text, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:model_cache, [desc: :updated_at], name: :model_cache_updated_at_idx)

    # Allow TTL cleanup: models.dev data cached for 2 hours
    # Other model caches (provider APIs, etc.) as needed
  end
end
