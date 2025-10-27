defmodule Singularity.Repo.Migrations.AddLuaSupportToRules do
  use Ecto.Migration

  def change do
    # Add execution_type enum (defaults to :elixir_patterns for backward compat)
    execute(
      """
      CREATE TYPE rule_execution_type AS ENUM ('elixir_patterns', 'lua_script')
      """,
      """
      DROP TYPE rule_execution_type
      """
    )

    alter table(:agent_behavior_confidence_rules) do
      add :execution_type, :rule_execution_type, default: "elixir_patterns", null: false
      add :lua_script, :text
    end

    # Add index for faster queries by execution type
    execute("""
      CREATE INDEX IF NOT EXISTS agent_behavior_confidence_rules_execution_type_index
      ON agent_behavior_confidence_rules (execution_type)
    """, "")
  end
end
