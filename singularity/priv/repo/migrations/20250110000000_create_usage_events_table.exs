defmodule Singularity.Repo.Migrations.CreateUsageEventsTable do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:usage_events, primary_key: false) do
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

    execute("""
      CREATE INDEX IF NOT EXISTS usage_events_codebase_id_index
      ON usage_events (codebase_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS usage_events_category_index
      ON usage_events (category)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS usage_events_accepted_index
      ON usage_events (accepted)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS usage_events_inserted_at_index
      ON usage_events (inserted_at)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS usage_events_codebase_id_category_index
      ON usage_events (codebase_id, category)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS usage_events_codebase_id_accepted_index
      ON usage_events (codebase_id, accepted)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS usage_events_category_accepted_index
      ON usage_events (category, accepted)
    """, "")
  end
end