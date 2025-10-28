defmodule Singularity.Repo.Migrations.CreateGraphTypes do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:graph_types, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :graph_type, :string, null: false
      add :description, :text

      timestamps()
    end

    # Unique constraint via index
    execute("""
      CREATE UNIQUE INDEX IF NOT EXISTS graph_types_graph_type_key
      ON graph_types (graph_type)
    """, "")

    # Insert default graph types (idempotent via INSERT OR IGNORE)
    execute("""
    DO $$
    BEGIN
      INSERT INTO graph_types (id, graph_type, description, inserted_at, updated_at)
      VALUES
        (gen_random_uuid(), 'CallGraph', 'Function call dependencies (DAG)', NOW(), NOW()),
        (gen_random_uuid(), 'ImportGraph', 'Module import dependencies (DAG)', NOW(), NOW()),
        (gen_random_uuid(), 'SemanticGraph', 'Conceptual relationships (General Graph)', NOW(), NOW()),
        (gen_random_uuid(), 'DataFlowGraph', 'Variable and data dependencies (DAG)', NOW(), NOW())
      ON CONFLICT (graph_type) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END $$;
    """)
  end
end
