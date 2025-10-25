defmodule Singularity.Repo.Migrations.CreateAutonomousStoredProcedures do
  use Ecto.Migration

  def up do
    # ============================================================================
    # 1. PATTERN LEARNING PROCEDURE
    # ============================================================================
    execute("""
    CREATE OR REPLACE FUNCTION learn_patterns_from_analysis()
    RETURNS TABLE(patterns_learned INT, patterns_queued INT) AS $$
    DECLARE
      v_patterns_learned INT := 0;
      v_patterns_queued INT := 0;
      v_analysis RECORD;
    BEGIN
      -- Process unlearned analysis results (last 100)
      FOR v_analysis IN
        SELECT id, agent_id, result, confidence, created_at
        FROM analysis_results
        WHERE learned = FALSE
        ORDER BY created_at DESC
        LIMIT 100
      LOOP
        -- Insert learned pattern
        INSERT INTO learned_patterns (
          agent_id,
          pattern,
          confidence,
          learned_from_analysis_id,
          created_at
        ) VALUES (
          v_analysis.agent_id,
          v_analysis.result,
          COALESCE(v_analysis.confidence, 0.5),
          v_analysis.id,
          v_analysis.created_at
        );
        
        v_patterns_learned := v_patterns_learned + 1;
        
        -- Queue for CentralCloud sync via pgmq
        PERFORM pgmq.send(
          'centralcloud-new-patterns',
          jsonb_build_object(
            'agent_id', v_analysis.agent_id,
            'pattern', v_analysis.result,
            'confidence', COALESCE(v_analysis.confidence, 0.5),
            'learned_at', NOW(),
            'source', 'singularity-learning'
          )::text
        );
        
        v_patterns_queued := v_patterns_queued + 1;
        
        -- Mark as learned
        UPDATE analysis_results SET learned = TRUE WHERE id = v_analysis.id;
      END LOOP;
      
      RETURN QUERY SELECT v_patterns_learned, v_patterns_queued;
    END;
    $$ LANGUAGE plpgsql;
    """)

    # ============================================================================
    # 2. SESSION PERSISTENCE - TRIGGER + PROCEDURE
    # ============================================================================
    execute("""
    CREATE OR REPLACE FUNCTION persist_agent_session()
    RETURNS TRIGGER AS $$
    DECLARE
      v_session_json JSONB;
    BEGIN
      -- Build session JSON for queueing
      v_session_json := jsonb_build_object(
        'agent_id', NEW.agent_id,
        'session_id', NEW.id,
        'session_state', COALESCE(NEW.state, '{}'::jsonb),
        'confidence', COALESCE(NEW.confidence, 0.5),
        'synced_at', NOW(),
        'ulid', gen_ulid()
      );
      
      -- Queue to CentralCloud (survives restarts)
      PERFORM pgmq.send(
        'agent-sessions',
        v_session_json::text
      );
      
      -- Update sync timestamp
      NEW.last_synced_at := NOW();
      
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """)

    # Create table if it doesn't exist (for trigger)
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT FROM information_schema.triggers
        WHERE trigger_name = 'agent_session_persist'
      ) THEN
        CREATE TRIGGER agent_session_persist
          BEFORE UPDATE ON agent_sessions
          FOR EACH ROW
          WHEN (OLD.state IS DISTINCT FROM NEW.state OR OLD.confidence IS DISTINCT FROM NEW.confidence)
          EXECUTE FUNCTION persist_agent_session();
      END IF;
    END $$;
    """)

    # ============================================================================
    # 3. KNOWLEDGE UPDATE PROCEDURE
    # ============================================================================
    execute("""
    CREATE OR REPLACE FUNCTION update_agent_knowledge()
    RETURNS TABLE(agents_updated INT, total_patterns INT) AS $$
    DECLARE
      v_agents_updated INT := 0;
      v_total_patterns INT := 0;
    BEGIN
      -- Update each agent's knowledge from learned patterns (last 24h)
      WITH updated_agents AS (
        UPDATE agents a
        SET 
          known_patterns = COALESCE((
            SELECT jsonb_agg(
              jsonb_build_object(
                'pattern', pattern,
                'confidence', confidence,
                'learned_at', learned_at
              )
            ) 
            FROM learned_patterns 
            WHERE agent_id = a.id
              AND learned_at > NOW() - INTERVAL '24 hours'
          ), '[]'::jsonb),
          pattern_confidence = COALESCE((
            SELECT AVG(confidence)
            FROM learned_patterns
            WHERE agent_id = a.id
              AND learned_at > NOW() - INTERVAL '24 hours'
          ), 0),
          knowledge_updated_at = NOW()
        WHERE EXISTS (
          SELECT 1 FROM learned_patterns
          WHERE agent_id = a.id
            AND learned_at > NOW() - INTERVAL '24 hours'
        )
        RETURNING a.id, jsonb_array_length(a.known_patterns) as pattern_count
      )
      SELECT 
        COUNT(*)::INT,
        COALESCE(SUM(pattern_count)::INT, 0)
      INTO v_agents_updated, v_total_patterns
      FROM updated_agents;
      
      -- Queue knowledge update to CentralCloud
      IF v_agents_updated > 0 THEN
        PERFORM pgmq.send(
          'agent-knowledge-updates',
          jsonb_build_object(
            'agents_updated', v_agents_updated,
            'total_patterns', v_total_patterns,
            'updated_at', NOW()
          )::text
        );
      END IF;
      
      RETURN QUERY SELECT v_agents_updated, v_total_patterns;
    END;
    $$ LANGUAGE plpgsql;
    """)

    # ============================================================================
    # 4. LEARNING SYNC TO CENTRALCLOUD PROCEDURE
    # ============================================================================
    execute("""
    CREATE OR REPLACE FUNCTION sync_learning_to_centralcloud()
    RETURNS TABLE(batch_id TEXT, pattern_count INT) AS $$
    DECLARE
      v_batch_id TEXT;
      v_pattern_count INT := 0;
      v_msg_id BIGINT;
    BEGIN
      -- Generate batch ID
      v_batch_id := gen_ulid()::text;
      
      -- Get count of pending patterns
      SELECT COUNT(*)::INT INTO v_pattern_count
      FROM pgmq.q('centralcloud-new-patterns')
      LIMIT 1;
      
      -- Log the sync batch
      INSERT INTO learning_sync_log (
        batch_id,
        pattern_count,
        synced_at,
        status
      ) VALUES (
        v_batch_id,
        v_pattern_count,
        NOW(),
        'queued'
      )
      ON CONFLICT DO NOTHING;
      
      RETURN QUERY SELECT v_batch_id, v_pattern_count;
    END;
    $$ LANGUAGE plpgsql;
    """)

    # ============================================================================
    # 5. AGENT TASK AUTO-ASSIGNMENT PROCEDURE
    # ============================================================================
    execute("""
    CREATE OR REPLACE FUNCTION assign_pending_tasks()
    RETURNS TABLE(tasks_assigned INT, agents_assigned INT) AS $$
    DECLARE
      v_tasks_assigned INT := 0;
      v_agents_assigned INT := 0;
      v_agent_record RECORD;
    BEGIN
      -- For each agent, assign pending tasks
      FOR v_agent_record IN
        SELECT 
          a.id,
          a.agent_id,
          COUNT(pt.id)::INT as pending_count
        FROM agents a
        LEFT JOIN pending_tasks pt ON pt.agent_id = a.id
          AND pt.assigned_at IS NULL
        WHERE a.active = TRUE
        GROUP BY a.id, a.agent_id
        HAVING COUNT(pt.id) > 0
        LIMIT 50
      LOOP
        UPDATE pending_tasks
        SET 
          assigned_at = NOW(),
          assigned_agent_id = v_agent_record.id
        WHERE agent_id = v_agent_record.agent_id
          AND assigned_at IS NULL
          AND assigned_agent_id IS NULL
        LIMIT 10;
        
        GET DIAGNOSTICS v_tasks_assigned = ROW_COUNT;
        v_agents_assigned := v_agents_assigned + 1;
      END LOOP;
      
      RETURN QUERY SELECT v_tasks_assigned, v_agents_assigned;
    END;
    $$ LANGUAGE plpgsql;
    """)

    # ============================================================================
    # 6. METRICS AUTO-AGGREGATION (TimescaleDB)
    # ============================================================================
    execute("""
    DO $$
    BEGIN
      -- Create continuous aggregate for 5-minute metrics
      IF NOT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'agent_performance_5min'
      ) THEN
        CREATE MATERIALIZED VIEW agent_performance_5min AS
        SELECT
          time_bucket('5 minutes', timestamp) as bucket,
          agent_id,
          COUNT(*)::INT as task_count,
          AVG(COALESCE(duration_ms, 0))::NUMERIC as avg_duration_ms,
          MAX(COALESCE(duration_ms, 0))::NUMERIC as max_duration_ms,
          MIN(COALESCE(duration_ms, 0))::NUMERIC as min_duration_ms,
          percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms) as p95_duration_ms
        FROM agent_tasks
        GROUP BY bucket, agent_id;
      END IF;
    END $$;
    """)

    # ============================================================================
    # 7. CDC - WAL2JSON LOGICAL DECODING SETUP
    # ============================================================================
    execute("""
    DO $$
    BEGIN
      -- Create logical decoding slot for CentralCloud CDC
      IF NOT EXISTS (
        SELECT 1 FROM pg_replication_slots 
        WHERE slot_name = 'singularity_centralcloud_cdc'
      ) THEN
        SELECT pg_create_logical_replication_slot(
          'singularity_centralcloud_cdc',
          'wal2json'
        );
      END IF;
    END $$;
    """)

    # Log table for tracking syncs
    create_if_not_exists table(:learning_sync_log, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_ulid()::uuid")
      add :batch_id, :string
      add :pattern_count, :integer
      add :synced_at, :utc_datetime
      add :status, :string, default: "queued"
      timestamps(type: :utc_datetime)
    end

    execute("""
      CREATE INDEX IF NOT EXISTS learning_sync_log_batch_id_index
      ON learning_sync_log (batch_id)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS learning_sync_log_status_index
      ON learning_sync_log (status)
    """, "")
    execute("""
      CREATE INDEX IF NOT EXISTS learning_sync_log_synced_at_index
      ON learning_sync_log (synced_at)
    """, "")
  end

  def down do
    # Drop triggers
    execute("DROP TRIGGER IF EXISTS agent_session_persist ON agent_sessions")
    
    # Drop functions
    execute("DROP FUNCTION IF EXISTS learn_patterns_from_analysis()")
    execute("DROP FUNCTION IF EXISTS persist_agent_session()")
    execute("DROP FUNCTION IF EXISTS update_agent_knowledge()")
    execute("DROP FUNCTION IF EXISTS sync_learning_to_centralcloud()")
    execute("DROP FUNCTION IF EXISTS assign_pending_tasks()")
    
    # Drop views
    execute("DROP MATERIALIZED VIEW IF EXISTS agent_performance_5min")
    
    # Drop CDC slot
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM pg_replication_slots 
        WHERE slot_name = 'singularity_centralcloud_cdc'
      ) THEN
        SELECT pg_drop_replication_slot('singularity_centralcloud_cdc');
      END IF;
    END $$;
    """)
    
    # Drop tables
    drop table(:learning_sync_log)
  end
end
