defmodule Singularity.Repo.Migrations.CreateUsageEventsTable do
  use Ecto.Migration

  def change do
    create table(:usage_events, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :codebase_id, :string, null: false
      add :category, :string, null: false
      add :suggestion, :string, null: false
      add :accepted, :boolean, null: false
      add :context, :map, default: %{}
      add :confidence, :float, default: 0.5
      add :inserted_at, :utc_datetime, null: false, default: fragment("NOW()")
      add :updated_at, :utc_datetime, null: false, default: fragment("NOW()")
    end

    create index(:usage_events, [:codebase_id])
    create index(:usage_events, [:category])
    create index(:usage_events, [:accepted])
    create index(:usage_events, [:inserted_at])
    create index(:usage_events, [:codebase_id, :category])
    create index(:usage_events, [:codebase_id, :accepted])
    create index(:usage_events, [:category, :accepted])
  end
end