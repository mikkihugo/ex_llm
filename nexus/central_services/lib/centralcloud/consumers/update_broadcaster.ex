defmodule CentralCloud.Consumers.UpdateBroadcaster do
  @moduledoc """
  Syncs approved patterns DOWN to Singularity instance databases.

  This is the "downlink" from CentralCloud to Singularity instances.

  ## Architecture

  ```
  CentralCloud.Repo (central_services DB)
  - Aggregates patterns from all instances
  - Approves high-confidence patterns
         ↓
  UpdateBroadcaster.sync_approved_patterns/0
  - Queries approved patterns from CentralCloud
         ↓
  Singularity.Repo (singularity DB)
  - Syncs approved patterns as read-only tables
  - Each instance reads from local tables (no queue polling)
  ```

  ## Tables

  **CentralCloud (central_services):**
  - approved_patterns: Aggregated patterns approved for distribution
  - approved_templates: Templates approved for use across instances

  **Singularity (singularity):**
  - approved_patterns (synced read-only copy): Patterns from CentralCloud
  - approved_templates (synced read-only copy): Templates from CentralCloud
  """

  require Logger
  alias CentralCloud.Repo
  alias CentralCloud.SharedQueueRepo
  alias QuantumFlow.Messaging

  @doc """
  Sync a single pattern in real-time (event-driven).

  Called immediately when a pattern reaches high confidence.
  """
  def sync_single_pattern(pattern_name, ecosystem, pattern_type) do
    Logger.info("[UpdateBroadcaster] 🔄 Real-time sync for pattern",
      pattern: pattern_name,
      ecosystem: ecosystem,
      type: pattern_type
    )

    case fetch_single_pattern(pattern_name, ecosystem) do
      {:ok, pattern} when is_map(pattern) ->
        # Sync to Singularity instances
        case sync_to_singularity_databases([pattern]) do
          :ok ->
            Logger.info("[UpdateBroadcaster] ✓ Synced pattern #{pattern_name} to instances")
            log_sync_completion(:pattern_sync, pattern_name, :success)
            :ok

          {:error, reason} ->
            Logger.error("[UpdateBroadcaster] ✗ Failed to sync pattern: #{inspect(reason)}")
            log_sync_completion(:pattern_sync, pattern_name, :failed, reason)
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("[UpdateBroadcaster] Failed to fetch pattern: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sync approved patterns from CentralCloud to all Singularity instances.

  Called periodically or on-demand to replicate approved patterns down to instances.
  Each instance maintains read-only local copy for fast access.
  """
  def sync_approved_patterns do
    Logger.info("[UpdateBroadcaster] Starting full pattern sync to instances")

    case fetch_approved_patterns() do
      {:ok, patterns} when is_list(patterns) ->
        Logger.info("[UpdateBroadcaster] Syncing #{length(patterns)} approved patterns",
          pattern_count: length(patterns)
        )

        case sync_to_singularity_databases(patterns) do
          :ok ->
            Logger.info("[UpdateBroadcaster] ✓ Completed full sync to instances")
            log_sync_completion(:pattern_sync, "full", :success)
            {:ok, patterns}

          {:error, reason} ->
            Logger.error("[UpdateBroadcaster] ✗ Full sync failed: #{inspect(reason)}")
            log_sync_completion(:pattern_sync, "full", :failed, reason)
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("[UpdateBroadcaster] Failed to fetch approved patterns: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sync approved templates from CentralCloud to all Singularity instances.
  
  Templates are synced as READ-ONLY copies to Singularity databases.
  """
  def sync_approved_templates do
    Logger.info("[UpdateBroadcaster] Starting template sync to instances")

    case fetch_approved_templates() do
      {:ok, templates} when is_list(templates) ->
        Logger.info("[UpdateBroadcaster] Syncing #{length(templates)} approved templates",
          template_count: length(templates)
        )

        case sync_templates_to_singularity_databases(templates) do
          :ok ->
            Logger.info("[UpdateBroadcaster] ✓ Completed template sync to instances")
            log_sync_completion(:template_sync, "full", :success)
            {:ok, templates}

          {:error, reason} ->
            Logger.error("[UpdateBroadcaster] ✗ Template sync failed: #{inspect(reason)}")
            log_sync_completion(:template_sync, "full", :failed, reason)
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("[UpdateBroadcaster] Failed to fetch approved templates: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp sync_templates_to_singularity_databases(templates) do
    try do
      # Templates are synced via:
      # 1. Logical replication (read-only copies in Singularity DB)
      # 2. QuantumFlow notifications for real-time updates
      
      # Broadcast via QuantumFlow for immediate updates
      Enum.each(templates, fn template ->
        subject = "template.sync.#{template["category"]}.#{template["id"]}"
        Messaging.publish(CentralCloud.Repo, subject, template, expect_reply: false)
      end)

      Logger.info("[UpdateBroadcaster] ✓ Templates queued for replication",
        template_count: length(templates),
        replication_method: "Logical replication + QuantumFlow notifications"
      )

      :ok
    rescue
      e ->
        Logger.error("Error in sync_templates_to_singularity_databases: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Publish sync notification to pgmq (optional, for audit trail).

  Each instance can optionally subscribe to these notifications to know
  when to refresh their local synced copies.
  """
  def publish_sync_notification(sync_type, summary) do
    msg = %{
      "type" => "sync_notification",
      "sync_type" => sync_type,
      "summary" => summary,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    try do
      json_msg = Jason.encode!(msg)

      case SharedQueueRepo.query(
        "SELECT pgmq.send($1, $2::jsonb)",
        ["sync_notifications", json_msg]
      ) do
        {:ok, _result} ->
          Logger.debug("[UpdateBroadcaster] Published sync notification",
            type: sync_type
          )
          :ok

        {:error, reason} ->
          Logger.error("[UpdateBroadcaster] Failed to publish sync notification: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("[UpdateBroadcaster] Exception publishing sync notification: #{inspect(e)}")
        {:error, e}
    end
  end

  # ===========================
  # Private Functions
  # ===========================

  defp fetch_single_pattern(pattern_name, ecosystem) do
    try do
      query = """
      SELECT
        id, name, ecosystem, frequency, confidence, description, examples,
        approved_at, last_synced_at, instances_count
      FROM approved_patterns
      WHERE name = $1 AND ecosystem = $2
      LIMIT 1
      """

      case Repo.query(query, [pattern_name, ecosystem]) do
        {:ok, %{rows: [row]}} ->
          pattern = format_pattern_row(row)
          {:ok, pattern}

        {:ok, %{rows: []}} ->
          {:error, :not_found}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error fetching single pattern: #{inspect(e)}")
        {:error, e}
    end
  end

  defp fetch_approved_patterns do
    try do
      query = """
      SELECT
        id, name, ecosystem, frequency, confidence, description, examples,
        approved_at, last_synced_at, instances_count
      FROM approved_patterns
      WHERE confidence >= 0.85
      ORDER BY updated_at DESC
      """

      case Repo.query(query, []) do
        {:ok, %{rows: rows}} ->
          patterns = Enum.map(rows, &format_pattern_row/1)
          {:ok, patterns}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error fetching approved patterns: #{inspect(e)}")
        {:error, e}
    end
  end

  defp fetch_approved_templates do
    try do
      query = """
      SELECT
        id, category, metadata, content, version, extends, compose,
        quality_standard, usage_stats, quality_score, embedding,
        deprecated, created_at, updated_at
      FROM templates
      WHERE deprecated = false
      ORDER BY updated_at DESC
      """

      case Repo.query(query, []) do
        {:ok, %{rows: rows}} ->
          templates = Enum.map(rows, &format_template_row/1)
          {:ok, templates}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error fetching approved templates: #{inspect(e)}")
        {:error, e}
    end
  end

  defp format_template_row(row) do
    [
      id, category, metadata, content, version, extends, compose,
      quality_standard, usage_stats, quality_score, embedding,
      deprecated, created_at, updated_at
    ] = row

    %{
      "id" => id,
      "category" => category,
      "metadata" => metadata || %{},
      "content" => content || %{},
      "version" => version,
      "extends" => extends,
      "compose" => compose || [],
      "quality_standard" => quality_standard,
      "usage_stats" => usage_stats || %{},
      "quality_score" => quality_score,
      "embedding" => embedding,
      "deprecated" => deprecated,
      "created_at" => created_at,
      "updated_at" => updated_at
    }
  end

  defp format_pattern_row(row) do
    [id, name, ecosystem, frequency, confidence, description, examples, approved_at, last_synced_at, instances_count] = row

    %{
      "id" => id,
      "name" => name,
      "ecosystem" => ecosystem,
      "frequency" => frequency,
      "confidence" => confidence,
      "description" => description,
      "examples" => examples || %{},
      "approved_at" => approved_at,
      "last_synced_at" => last_synced_at,
      "instances_count" => instances_count
    }
  end

  defp sync_to_singularity_databases(patterns) do
    try do
      # Production-level replication via pg_net HTTP push
      #
      # Architecture:
      # 1. Triggers on approved_patterns fire automatically
      # 2. pg_cron worker (every 5s) sends to all active instances
      # 3. Singularity endpoints receive and upsert locally
      # 4. Audit trail in replication_queue table
      #
      # This function is called by UpdateBroadcaster after immediate storage.
      # The actual HTTP push happens asynchronously via pg_cron/pg_net.
      # No need to retry here - pg_net handles retries with backoff.

      Logger.info("[UpdateBroadcaster] ✓ Patterns queued for replication",
        pattern_count: length(patterns),
        replication_method: "pg_net HTTP push via pg_cron"
      )

      # Patterns are already in database, triggers already fired
      # pg_cron will handle async push to instances
      :ok
    rescue
      e ->
        Logger.error("Error in sync_to_singularity_databases: #{inspect(e)}")
        {:error, e}
    end
  end

  defp log_sync_completion(sync_type, _identifier, status) do
    try do
      Repo.query("""
      INSERT INTO sync_log (
        id, sync_type, status, items_synced, sync_triggered_by, synced_at,
        inserted_at, updated_at
      ) VALUES (
        uuid_generate_v7(), $1, $2, 1, 'realtime', NOW(), NOW(), NOW()
      )
      """, [Atom.to_string(sync_type), Atom.to_string(status)])
    rescue
      e ->
        Logger.error("Error logging sync completion: #{inspect(e)}")
    end
  end

  defp log_sync_completion(sync_type, _identifier, status, error) do
    try do
      Repo.query("""
      INSERT INTO sync_log (
        id, sync_type, status, error_message, sync_triggered_by, synced_at,
        inserted_at, updated_at
      ) VALUES (
        uuid_generate_v7(), $1, $2, $3, 'realtime', NOW(), NOW(), NOW()
      )
      """, [Atom.to_string(sync_type), Atom.to_string(status), inspect(error)])
    rescue
      e ->
        Logger.error("Error logging sync completion: #{inspect(e)}")
    end
  end
end
