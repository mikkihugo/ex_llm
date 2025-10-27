defmodule CentralCloud.Repo.Migrations.CreateTaskPreferences do
  use Ecto.Migration

  def change do
    create table(:task_preferences) do
      add :task_type, :string, null: false  # :architecture, :coding, :research, etc.
      add :model_name, :string, null: false
      add :provider, :string
      add :prompt, :string
      add :response_quality, :float, null: false  # 0.0-1.0
      add :success, :boolean, null: false, default: false
      add :response_time_ms, :integer
      add :instance_id, :string, null: false
      add :feedback_text, :string

      timestamps(type: :utc_datetime)
    end

    # Indexes for aggregation queries
    create index(:task_preferences, [:task_type, :model_name],
      name: :task_preferences_task_model_idx
    )

    create index(:task_preferences, [:task_type], name: :task_preferences_task_type_idx)
    create index(:task_preferences, [:model_name], name: :task_preferences_model_name_idx)
    create index(:task_preferences, [:instance_id], name: :task_preferences_instance_idx)
    create index(:task_preferences, [:inserted_at], name: :task_preferences_inserted_at_idx)

    # For recent data queries - use descending index on inserted_at
    # Note: WHERE clause removed because NOW() is not IMMUTABLE in PostgreSQL
    create index(:task_preferences, [desc: :inserted_at],
      name: :task_preferences_recent_idx
    )
  end
end
