defmodule CentralCloud.Repo.Migrations.CreateApprovedPatternsTable do
  use Ecto.Migration

  def change do
    create table(:approved_patterns, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v7()")
      add :name, :string, null: false
      add :ecosystem, :string, null: false  # elixir, python, typescript, etc.
      add :frequency, :integer, null: false, default: 0  # How many times seen
      add :confidence, :float, null: false, default: 0.0  # 0.0-1.0
      add :instances_count, :integer, null: false, default: 0  # How many instances reported it
      add :description, :text
      add :examples, :jsonb, default: %{}  # Code examples
      add :best_practices, {:array, :text}, default: []
      add :approved_at, :utc_datetime_usec, null: false
      add :last_synced_at, :utc_datetime_usec  # When last synced to Singularity instances
      add :synced_instance_count, :integer, default: 0  # How many instances received it

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes for common queries
    create index(:approved_patterns, [:ecosystem])
    create index(:approved_patterns, [:confidence])
    create index(:approved_patterns, [:last_synced_at])
    create unique_index(:approved_patterns, [:name, :ecosystem])
  end
end
