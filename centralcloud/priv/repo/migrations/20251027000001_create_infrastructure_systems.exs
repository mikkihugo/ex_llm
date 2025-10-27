defmodule CentralCloud.Repo.Migrations.CreateInfrastructureSystems do
  use Ecto.Migration

  def change do
    create table(:infrastructure_systems, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :name, :string, null: false
      add :category, :string, null: false
      add :description, :text
      add :detection_patterns, :jsonb, default: []
      add :fields, :jsonb, default: %{}
      add :source, :string, default: "manual"
      add :confidence, :float, default: 0.5
      add :last_validated_at, :utc_datetime_usec
      add :learned_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for common queries
    create unique_index(:infrastructure_systems, [:name, :category])
    create index(:infrastructure_systems, [:category])
    create index(:infrastructure_systems, [:confidence])
    create index(:infrastructure_systems, [:inserted_at])
  end
end
