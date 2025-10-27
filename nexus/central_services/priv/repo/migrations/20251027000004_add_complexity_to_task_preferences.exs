defmodule CentralCloud.Repo.Migrations.AddComplexityToTaskPreferences do
  use Ecto.Migration

  def change do
    alter table(:task_preferences) do
      add :complexity_level, :string, default: "medium", null: false  # simple, medium, complex
    end

    # Create composite index for (task_type, complexity_level, model_name) triplet lookups
    create index(:task_preferences, [:task_type, :complexity_level, :model_name],
      name: :task_preferences_task_complexity_model_idx
    )

    # For complexity-specific analysis
    create index(:task_preferences, [:complexity_level],
      name: :task_preferences_complexity_level_idx
    )

    # Composite for fast (task_type, complexity) aggregations
    create index(:task_preferences, [:task_type, :complexity_level],
      name: :task_preferences_task_complexity_idx
    )
  end
end
