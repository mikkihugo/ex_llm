defmodule Singularity.Database.AutonomousWorker do
  @moduledoc """
  PostgreSQL-Based Autonomous Worker System.

  Delegates persistent, critical operations to PostgreSQL stored procedures,
  allowing Singularity to focus on real-time orchestration while PostgreSQL
  handles durability, scheduling, and CentralCloud synchronization.

  ## Architecture

  ```
  Elixir (Real-time)              PostgreSQL (Persistent)
  ├─ Agent execution              ├─ learn_patterns_from_analysis()
  ├─ LLM calls                    ├─ persist_agent_session()
  ├─ Insert analysis results  →   ├─ update_agent_knowledge()
  └─ Send NATS messages           ├─ sync_learning_to_centralcloud()
                                  ├─ assign_pending_tasks()
                                  └─ Triggers: Auto-persistence
  ```

  ## Autonomous Tasks (pg_cron)

  - Every 5 min: Learn patterns from analysis
  - Every 10 min: Sync learning to CentralCloud
  - Every 1 hour: Update agent knowledge
  - Every 2 min: Assign pending tasks
  - Every 30 min: Refresh performance metrics

  ## Use Cases

  ### Pattern Learning (Automatic)
  1. Elixir inserts analysis_result with `learned = FALSE`
  2. PostgreSQL learns automatically every 5 minutes
  3. Patterns queued for CentralCloud
  4. CentralCloud polls pgmq for patterns

  ### Session Persistence (Trigger-Based)
  1. Elixir updates agent_sessions table
  2. Trigger fires automatically
  3. Session encrypted and queued to pgmq
  4. CentralCloud reads via pgmq or wal2json CDC

  ### Knowledge Updates (Scheduled)
  1. PostgreSQL aggregates learned patterns hourly
  2. Updates agent knowledge summaries
  3. Queues to CentralCloud
  4. Agent has access to latest knowledge

  ### Task Assignment (Scheduled)
  1. PostgreSQL looks for pending tasks
  2. Assigns to available agents
  3. Runs every 2 minutes
  4. No Elixir intervention needed
  """

  require Logger
  alias Singularity.Repo

  # ============================================================================
  # PATTERN LEARNING
  # ============================================================================

  @doc """
  Trigger pattern learning from analysis results.

  Normally runs automatically every 5 minutes via pg_cron.
  Call manually to force immediate learning.

  Returns: {patterns_learned, patterns_queued}
  """
  def learn_patterns_now do
    case Repo.query("SELECT * FROM learn_patterns_from_analysis()") do
      {:ok, %{rows: [[patterns_learned, patterns_queued]]}} ->
        Logger.info("Pattern learning triggered",
          patterns_learned: patterns_learned,
          patterns_queued: patterns_queued
        )

        {:ok, %{patterns_learned: patterns_learned, patterns_queued: patterns_queued}}

      error ->
        Logger.error("Pattern learning failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # ============================================================================
  # KNOWLEDGE UPDATES
  # ============================================================================

  @doc """
  Trigger agent knowledge updates from learned patterns.

  Normally runs automatically every hour via pg_cron.
  Call manually to force immediate update.

  Returns: {agents_updated, total_patterns}
  """
  def update_knowledge_now do
    case Repo.query("SELECT * FROM update_agent_knowledge()") do
      {:ok, %{rows: [[agents_updated, total_patterns]]}} ->
        Logger.info("Agent knowledge updated",
          agents_updated: agents_updated,
          total_patterns: total_patterns
        )

        {:ok, %{agents_updated: agents_updated, total_patterns: total_patterns}}

      error ->
        Logger.error("Knowledge update failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # ============================================================================
  # LEARNING SYNC TO CENTRALCLOUD
  # ============================================================================

  @doc """
  Trigger sync of learning patterns to CentralCloud.

  Normally runs automatically every 10 minutes via pg_cron.
  Call manually to force immediate sync.

  Returns: {batch_id, pattern_count}
  """
  def sync_learning_now do
    case Repo.query("SELECT * FROM sync_learning_to_centralcloud()") do
      {:ok, %{rows: [[batch_id, pattern_count]]}} ->
        Logger.info("Learning sync triggered",
          batch_id: batch_id,
          pattern_count: pattern_count
        )

        {:ok, %{batch_id: batch_id, pattern_count: pattern_count}}

      error ->
        Logger.error("Learning sync failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # ============================================================================
  # TASK ASSIGNMENT
  # ============================================================================

  @doc """
  Trigger automatic task assignment to agents.

  Normally runs automatically every 2 minutes via pg_cron.
  Call manually to force immediate assignment.

  Returns: {tasks_assigned, agents_assigned}
  """
  def assign_tasks_now do
    case Repo.query("SELECT * FROM assign_pending_tasks()") do
      {:ok, %{rows: [[tasks_assigned, agents_assigned]]}} ->
        Logger.info("Task assignment triggered",
          tasks_assigned: tasks_assigned,
          agents_assigned: agents_assigned
        )

        {:ok, %{tasks_assigned: tasks_assigned, agents_assigned: agents_assigned}}

      error ->
        Logger.error("Task assignment failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # ============================================================================
  # CDC - CHANGE DATA CAPTURE FOR CENTRALCLOUD
  # ============================================================================

  @doc """
  Get changes from logical decoding slot for CentralCloud CDC.

  Returns WAL changes as JSON since last call.
  CentralCloud uses this to stay in sync with Singularity's database.

  This is the real-time alternative to polling pgmq - it gets ALL changes,
  not just explicitly queued messages.
  """
  def get_cdc_changes do
    case Repo.query("""
         SELECT lsn, data FROM pg_logical_slot_get_changes(
           'singularity_centralcloud_cdc',
           NULL,
           NULL
         );
         """) do
      {:ok, %{rows: rows}} ->
        changes =
          Enum.map(rows, fn [lsn, data] ->
            %{lsn: lsn, data: Jason.decode!(data)}
          end)

        {:ok, changes}

      error ->
        Logger.error("CDC fetch failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Get CDC changes that affect learned patterns only.

  Useful for CentralCloud to sync only pattern changes without other noise.
  """
  def get_pattern_changes do
    case get_cdc_changes() do
      {:ok, all_changes} ->
        pattern_changes =
          Enum.filter(all_changes, fn %{data: data} ->
            data["table"] == "learned_patterns"
          end)

        {:ok, pattern_changes}

      error ->
        error
    end
  end

  @doc """
  Get CDC changes that affect agent sessions.

  Useful for CentralCloud to sync agent state changes.
  """
  def get_session_changes do
    case get_cdc_changes() do
      {:ok, all_changes} ->
        session_changes =
          Enum.filter(all_changes, fn %{data: data} ->
            data["table"] == "agent_sessions"
          end)

        {:ok, session_changes}

      error ->
        error
    end
  end

  # ============================================================================
  # PGMQ - DURABLE MESSAGE QUEUE MONITORING
  # ============================================================================

  @doc """
  Get status of all autonomous worker message queues.

  Shows how many messages are pending sync to CentralCloud.
  """
  def queue_status do
    case Repo.query("""
         SELECT queue_name, messages, messages_in_flight
         FROM pgmq.queue_stats()
         WHERE queue_name LIKE 'centralcloud-%' OR queue_name LIKE 'agent-%'
         ORDER BY queue_name;
         """) do
      {:ok, %{rows: rows}} ->
        queues =
          Enum.map(rows, fn [name, total, in_flight] ->
            %{
              queue: name,
              total_messages: total,
              in_flight: in_flight,
              available: total - in_flight
            }
          end)

        {:ok, queues}

      error ->
        Logger.error("Queue status check failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Check if CentralCloud learning requests queue is building up.

  Returns true if more than threshold messages are pending.
  """
  def learning_queue_backed_up?(threshold \\ 100) do
    case Repo.query("""
         SELECT messages FROM pgmq.queue_stats()
         WHERE queue_name = 'centralcloud-new-patterns';
         """) do
      {:ok, %{rows: [[count]]}} ->
        count > threshold

      _ ->
        false
    end
  end

  # ============================================================================
  # SCHEDULED JOB MONITORING
  # ============================================================================

  @doc """
  Get status of all pg_cron autonomous jobs.

  Shows when each job last ran and if there were errors.
  """
  def scheduled_jobs_status do
    case Repo.query("""
         SELECT 
           jobid,
           jobname,
           schedule,
           last_successful_run,
           last_run_status,
           last_run_duration
         FROM cron.job
         WHERE jobname LIKE '%-every-%' OR jobname LIKE '%-hourly%' OR jobname LIKE '%-daily%'
         ORDER BY last_successful_run DESC;
         """) do
      {:ok, %{rows: rows}} ->
        jobs =
          Enum.map(rows, fn
            [job_id, name, schedule, last_run, status, duration] ->
              %{
                job_id: job_id,
                name: name,
                schedule: schedule,
                last_run: last_run,
                status: status,
                duration_ms: duration
              }

            _ ->
              nil
          end)
          |> Enum.filter(& &1)

        {:ok, jobs}

      error ->
        Logger.error("Job status check failed: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Check if a scheduled job failed recently.

  Useful for alerting if critical autonomous tasks are failing.
  """
  def check_job_health(job_name) do
    case Repo.query(
           """
           SELECT last_run_status, last_successful_run
           FROM cron.job
           WHERE jobname = $1;
           """,
           [job_name]
         ) do
      {:ok, %{rows: [[status, last_run]]}} ->
        {:ok, %{status: status, last_run: last_run}}

      {:ok, %{rows: []}} ->
        {:error, "Job not found: #{job_name}"}

      error ->
        Logger.error("Job health check failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # ============================================================================
  # MANUAL OVERRIDES
  # ============================================================================

  @doc """
  Manually process a single analysis result that didn't learn.

  Useful for debugging or forcing learning of specific analysis.
  """
  def manually_learn_analysis(analysis_id) do
    case Repo.query(
           """
           INSERT INTO learned_patterns (agent_id, pattern, confidence, learned_from_analysis_id, created_at)
           SELECT agent_id, result, confidence, id, created_at
           FROM analysis_results
           WHERE id = $1 AND learned = FALSE
           RETURNING id;
           """,
           [analysis_id]
         ) do
      {:ok, %{rows: [[pattern_id]]}} ->
        Logger.info("Manually learned pattern", pattern_id: pattern_id)
        {:ok, pattern_id}

      error ->
        Logger.error("Manual learning failed: #{inspect(error)}")
        {:error, error}
    end
  end
end
