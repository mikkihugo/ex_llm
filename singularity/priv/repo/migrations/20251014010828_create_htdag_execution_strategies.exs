defmodule Singularity.Repo.Migrations.CreateHtdagExecutionStrategies do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:htdag_execution_strategies, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Identity
      add :name, :string, null: false
      add :description, :text
      add :task_pattern, :string  # Regex to match task descriptions

      # Lua scripts for each execution phase
      add :decomposition_script, :text
      add :agent_spawning_script, :text
      add :orchestration_script, :text
      add :completion_script, :text

      # Metadata
      add :status, :string, default: "active", null: false
      add :version, :integer, default: 1, null: false
      add :priority, :integer, default: 0, null: false

      # Performance tracking
      add :usage_count, :integer, default: 0, null: false
      add :success_rate, :float, default: 1.0, null: false
      add :avg_execution_time_ms, :float, default: 0.0, null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes for fast lookups
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS htdag_execution_strategies_name_key
      ON htdag_execution_strategies (name)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS htdag_execution_strategies_status_index
      ON htdag_execution_strategies (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS htdag_execution_strategies_priority_index
      ON htdag_execution_strategies (priority)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS htdag_execution_strategies_task_pattern_index
      ON htdag_execution_strategies (task_pattern)
    """, "")
  end
end
