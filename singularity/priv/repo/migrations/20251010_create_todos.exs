defmodule Singularity.Repo.Migrations.CreateTodos do
  use Ecto.Migration

  def up do
    create_if_not_exists table(:todos, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :title, :text, null: false
      add :description, :text
      add :status, :string, null: false, default: "pending"
      add :priority, :integer, null: false, default: 3
      add :complexity, :string, default: "medium"
      add :assigned_agent_id, :string
      add :parent_todo_id, :uuid
      add :depends_on_ids, {:array, :uuid}, default: []
      add :tags, {:array, :string}, default: []
      add :context, :jsonb, default: "{}"
      add :result, :jsonb
      add :error_message, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :failed_at, :utc_datetime
      add :embedding, :jsonb
      add :estimated_duration_seconds, :integer
      add :actual_duration_seconds, :integer
      add :retry_count, :integer, default: 0
      add :max_retries, :integer, default: 3

      timestamps()
    end

    # Indexes for queries
    execute("""
      CREATE INDEX IF NOT EXISTS todos_status_index
      ON todos (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS todos_priority_index
      ON todos (priority)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS todos_assigned_agent_id_index
      ON todos (assigned_agent_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS todos_parent_todo_id_index
      ON todos (parent_todo_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS todos_tags_index
      ON todos (tags)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS todos_context_index
      ON todos (context)
    """, "")

    # Vector similarity search index (disabled - pgvector not available)
    # execute """
    # CREATE INDEX todos_embedding_idx ON todos
    # USING ivfflat (embedding vector_cosine_ops)
    # WITH (lists = 100)
    # """

    # Check constraint for status
    create constraint(:todos, :valid_status,
      check: "status IN ('pending', 'assigned', 'in_progress', 'completed', 'failed', 'blocked', 'cancelled')"
    )

    # Check constraint for complexity
    create constraint(:todos, :valid_complexity,
      check: "complexity IN ('simple', 'medium', 'complex')"
    )

    # Check constraint for priority
    create constraint(:todos, :valid_priority,
      check: "priority >= 1 AND priority <= 5"
    )
  end

  def down do
    drop table(:todos)
  end
end
