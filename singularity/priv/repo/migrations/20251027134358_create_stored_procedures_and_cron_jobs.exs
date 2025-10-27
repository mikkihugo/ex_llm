defmodule Singularity.Repo.Migrations.CreateStoredProceduresAndCronJobs do
  use Ecto.Migration

  def up do
    # ============================================================================
    # STORED PROCEDURES FOR COMMON OPERATIONS
    # ============================================================================

    # UUID Generation Functions
    execute """
    CREATE OR REPLACE FUNCTION generate_uuid_v7()
    RETURNS uuid
    LANGUAGE sql
    AS $$
      SELECT uuidv7();
    $$;
    """

    execute """
    CREATE OR REPLACE FUNCTION generate_uuid_v4()
    RETURNS uuid
    LANGUAGE sql
    AS $$
      SELECT gen_random_uuid();
    $$;
    """

    execute """
    CREATE OR REPLACE FUNCTION generate_deterministic_uuid(content text)
    RETURNS uuid
    LANGUAGE sql
    AS $$
      SELECT uuid_generate_v5(uuid_ns_url(), sha256(content::bytea)::text);
    $$;
    """

    # SHA Hashing Functions
    execute """
    CREATE OR REPLACE FUNCTION hash_sha256(content text)
    RETURNS text
    LANGUAGE sql
    AS $$
      SELECT encode(sha256(content::bytea), 'hex');
    $$;
    """

    execute """
    CREATE OR REPLACE FUNCTION hash_sha1(content text)
    RETURNS text
    LANGUAGE sql
    AS $$
      SELECT encode(digest(content, 'sha1'), 'hex');
    $$;
    """

    # Todo Management Functions
    execute """
    CREATE OR REPLACE FUNCTION create_todo_with_uuid(
      p_title text,
      p_description text DEFAULT NULL,
      p_priority integer DEFAULT 3,
      p_complexity text DEFAULT 'medium',
      p_source text DEFAULT 'manual',
      p_file_uuid uuid DEFAULT NULL,
      p_context jsonb DEFAULT '{}'::jsonb
    )
    RETURNS uuid
    LANGUAGE plpgsql
    AS $$
    DECLARE
      new_uuid uuid;
      todo_id uuid;
    BEGIN
      -- Generate UUID if not provided
      new_uuid := COALESCE(p_file_uuid, generate_uuid_v7());
      
      -- Insert todo
      INSERT INTO todos (
        id, title, description, priority, complexity, source, file_uuid, context,
        status, created_at, updated_at
      ) VALUES (
        gen_random_uuid(), p_title, p_description, p_priority, p_complexity, 
        p_source, new_uuid, p_context, 'pending', NOW(), NOW()
      ) RETURNING id INTO todo_id;
      
      RETURN todo_id;
    END;
    $$;
    """

    execute """
    CREATE OR REPLACE FUNCTION update_todo_status(
      p_todo_id uuid,
      p_status text,
      p_agent_id text DEFAULT NULL,
      p_result jsonb DEFAULT NULL,
      p_error_message text DEFAULT NULL
    )
    RETURNS boolean
    LANGUAGE plpgsql
    AS $$
    DECLARE
      current_status text;
    BEGIN
      -- Get current status
      SELECT status INTO current_status FROM todos WHERE id = p_todo_id;
      
      -- Validate status transition
      IF current_status IS NULL THEN
        RETURN false; -- Todo not found
      END IF;
      
      -- Update todo with status-specific fields
      UPDATE todos SET
        status = p_status,
        assigned_agent_id = COALESCE(p_agent_id, assigned_agent_id),
        result = COALESCE(p_result, result),
        error_message = COALESCE(p_error_message, error_message),
        started_at = CASE WHEN p_status = 'in_progress' AND started_at IS NULL THEN NOW() ELSE started_at END,
        completed_at = CASE WHEN p_status = 'completed' THEN NOW() ELSE completed_at END,
        failed_at = CASE WHEN p_status = 'failed' THEN NOW() ELSE failed_at END,
        updated_at = NOW()
      WHERE id = p_todo_id;
      
      RETURN true;
    END;
    $$;
    """

    # Embedding and Search Functions
    execute """
    CREATE OR REPLACE FUNCTION find_similar_todos(
      p_query_embedding vector(2560),
      p_limit integer DEFAULT 10,
      p_threshold float DEFAULT 0.7
    )
    RETURNS TABLE(
      id uuid,
      title text,
      description text,
      similarity float
    )
    LANGUAGE sql
    AS $$
      SELECT 
        t.id,
        t.title,
        t.description,
        1 - (t.embedding <=> p_query_embedding) as similarity
      FROM todos t
      WHERE t.embedding IS NOT NULL
        AND 1 - (t.embedding <=> p_query_embedding) > p_threshold
      ORDER BY t.embedding <=> p_query_embedding
      LIMIT p_limit;
    $$;
    """

    # Cleanup and Maintenance Functions
    execute """
    CREATE OR REPLACE FUNCTION cleanup_old_todos()
    RETURNS integer
    LANGUAGE plpgsql
    AS $$
    DECLARE
      deleted_count integer;
    BEGIN
      -- Delete completed todos older than 30 days
      DELETE FROM todos 
      WHERE status = 'completed' 
        AND completed_at < NOW() - INTERVAL '30 days';
      
      GET DIAGNOSTICS deleted_count = ROW_COUNT;
      
      -- Delete failed todos older than 7 days
      DELETE FROM todos 
      WHERE status = 'failed' 
        AND failed_at < NOW() - INTERVAL '7 days';
      
      GET DIAGNOSTICS deleted_count = deleted_count + ROW_COUNT;
      
      RETURN deleted_count;
    END;
    $$;
    """

    execute """
    CREATE OR REPLACE FUNCTION update_todo_embeddings()
    RETURNS integer
    LANGUAGE plpgsql
    AS $$
    DECLARE
      updated_count integer := 0;
      todo_record RECORD;
    BEGIN
      -- Update todos without embeddings (this would call your embedding service)
      -- For now, just mark them as needing updates
      UPDATE todos 
      SET context = context || '{"needs_embedding": true}'::jsonb
      WHERE embedding IS NULL 
        AND status IN ('pending', 'assigned', 'in_progress');
      
      GET DIAGNOSTICS updated_count = ROW_COUNT;
      
      RETURN updated_count;
    END;
    $$;
    """

    # ============================================================================
    # PG_CRON JOBS FOR AUTOMATED MAINTENANCE
    # ============================================================================

    # Cleanup old todos every day at 2 AM
    execute """
    SELECT cron.schedule(
      'cleanup-old-todos',
      '0 2 * * *',
      'SELECT cleanup_old_todos();'
    );
    """

    # Update embeddings every 6 hours
    execute """
    SELECT cron.schedule(
      'update-todo-embeddings',
      '0 */6 * * *',
      'SELECT update_todo_embeddings();'
    );
    """

    # Database statistics update every hour
    execute """
    SELECT cron.schedule(
      'update-db-stats',
      '0 * * * *',
      'ANALYZE;'
    );
    """

    # Vacuum analyze every day at 3 AM
    execute """
    SELECT cron.schedule(
      'vacuum-analyze',
      '0 3 * * *',
      'VACUUM ANALYZE;'
    );
    """

    # ============================================================================
    # INDEXES FOR PERFORMANCE
    # ============================================================================

    # Indexes for todo queries
    create index(:todos, [:status, :priority])
    create index(:todos, [:source, :created_at])
    create index(:todos, [:file_uuid], unique: true, where: "file_uuid IS NOT NULL")
    
    # GIN index for context JSONB queries
    create index(:todos, [:context], using: :gin)
    
    # Partial indexes for common queries
    create index(:todos, [:created_at], where: "status = 'pending'")
    create index(:todos, [:completed_at], where: "status = 'completed'")
    create index(:todos, [:failed_at], where: "status = 'failed'")

    # ============================================================================
    # VIEWS FOR COMMON QUERIES
    # ============================================================================

    execute """
    CREATE OR REPLACE VIEW todo_stats AS
    SELECT 
      status,
      COUNT(*) as count,
      AVG(priority) as avg_priority,
      COUNT(*) FILTER (WHERE complexity = 'simple') as simple_count,
      COUNT(*) FILTER (WHERE complexity = 'medium') as medium_count,
      COUNT(*) FILTER (WHERE complexity = 'complex') as complex_count
    FROM todos
    GROUP BY status;
    """

    execute """
    CREATE OR REPLACE VIEW recent_todos AS
    SELECT 
      id,
      title,
      status,
      priority,
      complexity,
      source,
      created_at,
      updated_at
    FROM todos
    WHERE created_at > NOW() - INTERVAL '7 days'
    ORDER BY created_at DESC;
    """
  end

  def down do
    # Drop cron jobs
    execute "SELECT cron.unschedule('cleanup-old-todos');"
    execute "SELECT cron.unschedule('update-todo-embeddings');"
    execute "SELECT cron.unschedule('update-db-stats');"
    execute "SELECT cron.unschedule('vacuum-analyze');"

    # Drop views
    execute "DROP VIEW IF EXISTS recent_todos;"
    execute "DROP VIEW IF EXISTS todo_stats;"

    # Drop indexes
    drop index(:todos, [:context])
    drop index(:todos, [:file_uuid])
    drop index(:todos, [:source, :created_at])
    drop index(:todos, [:status, :priority])
    drop index(:todos, [:created_at], where: "status = 'pending'")
    drop index(:todos, [:completed_at], where: "status = 'completed'")
    drop index(:todos, [:failed_at], where: "status = 'failed'")

    # Drop functions
    execute "DROP FUNCTION IF EXISTS generate_uuid_v7();"
    execute "DROP FUNCTION IF EXISTS generate_uuid_v4();"
    execute "DROP FUNCTION IF EXISTS generate_deterministic_uuid(text);"
    execute "DROP FUNCTION IF EXISTS hash_sha256(text);"
    execute "DROP FUNCTION IF EXISTS hash_sha1(text);"
    execute "DROP FUNCTION IF EXISTS create_todo_with_uuid(text, text, integer, text, text, uuid, jsonb);"
    execute "DROP FUNCTION IF EXISTS update_todo_status(uuid, text, text, jsonb, text);"
    execute "DROP FUNCTION IF EXISTS find_similar_todos(vector, integer, float);"
    execute "DROP FUNCTION IF EXISTS cleanup_old_todos();"
    execute "DROP FUNCTION IF EXISTS update_todo_embeddings();"
  end
end