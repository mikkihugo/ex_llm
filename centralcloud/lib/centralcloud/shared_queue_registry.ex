defmodule CentralCloud.SharedQueueRegistry do
  require Logger

  @moduledoc """
  Central registry of all message queues in the shared_queue database.

  This module defines the single source of truth for all pgmq queues used by:
  - Singularity instances
  - CentralCloud
  - Genesis
  - Nexus
  - Other services

  The registry is written to the `queue_registry` table in shared_queue DB on startup,
  making it accessible to all services (they only need shared_queue DB access).

  ## Queue Definition Format

  Each queue is defined with:
  - `name` - Queue name (used in pgmq)
  - `purpose` - What the queue is for
  - `direction` - "send", "receive", or "bidirectional"
  - `source` - Who sends messages (e.g., "singularity", "centralcloud")
  - `consumer` - Who reads messages
  - `message_schema` - JSON schema of messages
  - `retention_days` - How long to keep archived messages
  - `enabled` - Whether queue is active

  ## Usage

  ```elixir
  # List all queues
  CentralCloud.SharedQueueRegistry.all_queues()

  # Get specific queue
  CentralCloud.SharedQueueRegistry.get_queue("pattern_messages")

  # Get queues for a service
  CentralCloud.SharedQueueRegistry.for_service("singularity")

  # Write registry to database
  CentralCloud.SharedQueueRegistry.populate_database()
  ```
  """

  @queues [
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # EXISTING QUEUES (from llm-server integration)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    %{
      name: "llm_requests",
      purpose: "LLM routing requests from Singularity to Nexus",
      direction: "send",
      source: "singularity",
      consumer: "nexus",
      message_schema: %{
        type: "llm_request",
        request_id: "uuid",
        messages: "array",
        model: "string",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "llm_results",
      purpose: "LLM responses from Nexus back to Singularity",
      direction: "receive",
      source: "nexus",
      consumer: "singularity",
      message_schema: %{
        type: "llm_result",
        request_id: "uuid",
        response: "string",
        model: "string",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "approval_requests",
      purpose: "Code approval requests from Singularity to HITL",
      direction: "send",
      source: "singularity",
      consumer: "hitl",
      message_schema: %{
        type: "approval_request",
        request_id: "uuid",
        code: "string",
        description: "string",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "approval_responses",
      purpose: "Approval decisions from HITL back to Singularity",
      direction: "receive",
      source: "hitl",
      consumer: "singularity",
      message_schema: %{
        type: "approval_response",
        request_id: "uuid",
        approved: "boolean",
        comment: "string",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "question_requests",
      purpose: "Questions from Singularity to humans",
      direction: "send",
      source: "singularity",
      consumer: "hitl",
      message_schema: %{
        type: "question_request",
        request_id: "uuid",
        question: "string",
        context: "string",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "question_responses",
      purpose: "Human responses back to Singularity",
      direction: "receive",
      source: "hitl",
      consumer: "singularity",
      message_schema: %{
        type: "question_response",
        request_id: "uuid",
        answer: "string",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    # NEW QUEUES (for pattern learning + knowledge export)
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    %{
      name: "code_execution_requests",
      purpose: "Code execution requests from Singularity to Genesis",
      direction: "send",
      source: "singularity",
      consumer: "genesis",
      message_schema: %{
        type: "code_execution_request",
        request_id: "uuid",
        code: "string",
        language: "string",
        timeout: "integer",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "code_execution_results",
      purpose: "Code execution results from Genesis to Singularity",
      direction: "receive",
      source: "genesis",
      consumer: "singularity",
      message_schema: %{
        type: "code_execution_result",
        request_id: "uuid",
        status: "string",
        output: "string",
        error: "string",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "pattern_discoveries_published",
      purpose: "Pattern discoveries from Singularity instances to CentralCloud for aggregation",
      direction: "send",
      source: "singularity",
      consumer: "centralcloud",
      message_schema: %{
        type: "pattern_discovery",
        instance_id: "string",
        patterns: "array",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "patterns_aggregated_broadcast",
      purpose: "Aggregated patterns from CentralCloud broadcast to all Singularity instances",
      direction: "receive",
      source: "centralcloud",
      consumer: "singularity",
      message_schema: %{
        type: "patterns_aggregated",
        patterns: "array",
        stats: "object",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "patterns_learned_published",
      purpose: "Learned/high-quality patterns from Singularity instances to CentralCloud",
      direction: "send",
      source: "singularity",
      consumer: "centralcloud",
      message_schema: %{
        type: "patterns_learned",
        instance_id: "string",
        artifacts: "array",
        usage_count: "integer",
        success_rate: "float",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "patterns_exported_to_repository",
      purpose: "Notification that aggregated patterns were exported to Git repository",
      direction: "receive",
      source: "centralcloud",
      consumer: "singularity",
      message_schema: %{
        type: "patterns_exported",
        pr_url: "string",
        artifacts_count: "integer",
        branch: "string",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "templates_updated_broadcast",
      purpose: "Template updates from CentralCloud broadcast to all Singularity instances",
      direction: "receive",
      source: "centralcloud",
      consumer: "singularity",
      message_schema: %{
        type: "templates_updated",
        git_url: "string",
        updated_files: "array",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "instance_health_check",
      purpose: "Health status from Singularity instances to CentralCloud (optional monitoring)",
      direction: "send",
      source: "singularity",
      consumer: "centralcloud",
      message_schema: %{
        type: "instance_health",
        instance_id: "string",
        status: "string",
        uptime_ms: "integer",
        timestamp: "datetime"
      },
      retention_days: 30,
      enabled: false,
      created_at: nil
    },
    %{
      name: "execution_statistics_per_job",
      purpose: "Per-job code execution statistics from Genesis to CentralCloud for monitoring",
      direction: "send",
      source: "genesis",
      consumer: "centralcloud",
      message_schema: %{
        type: "execution_statistics",
        job_id: "uuid",
        language: "string",
        status: "string",
        execution_time_ms: "integer",
        memory_used_mb: "integer",
        lines_analyzed: "integer",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    },
    %{
      name: "execution_metrics_aggregated",
      purpose: "Aggregated code execution metrics from Genesis to CentralCloud for analytics",
      direction: "send",
      source: "genesis",
      consumer: "centralcloud",
      message_schema: %{
        type: "execution_metrics",
        jobs_completed: "integer",
        jobs_failed: "integer",
        success_rate: "float",
        avg_execution_time_ms: "integer",
        total_memory_used_mb: "integer",
        timestamp: "datetime"
      },
      retention_days: 90,
      enabled: true,
      created_at: nil
    }
  ]

  @doc """
  Get all queue definitions.
  """
  def all_queues, do: @queues

  @doc """
  Get a specific queue by name.
  """
  def get_queue(name) when is_binary(name) do
    Enum.find(@queues, fn q -> q.name == name end)
  end

  @doc """
  Get all queues for a specific service (as source or consumer).
  """
  def for_service(service) when is_binary(service) do
    Enum.filter(@queues, fn q ->
      q.source == service or q.consumer == service
    end)
  end

  @doc """
  Get enabled queues only.
  """
  def enabled_queues do
    Enum.filter(@queues, fn q -> q.enabled end)
  end

  @doc """
  Get queue names list (for compatibility with SharedQueueManager).
  """
  def queue_names do
    enabled_queues() |> Enum.map(fn q -> q.name end)
  end

  @doc """
  Populate the queue_registry table in shared_queue database.

  Called by SharedQueueManager.initialize() on startup.
  """
  def populate_database(repo \\ CentralCloud.SharedQueueRepo) do
    require Logger

    Logger.info("[SharedQueueRegistry] Populating queue_registry table...")

    # Delete existing entries
    Ecto.Adapters.SQL.query!(repo, "DELETE FROM queue_registry", [])

    # Insert all queue definitions
    Enum.each(enabled_queues(), fn queue ->
      Ecto.Adapters.SQL.query!(
        repo,
        """
        INSERT INTO queue_registry (
          queue_name,
          purpose,
          direction,
          source,
          consumer,
          message_schema,
          retention_days,
          enabled,
          created_at,
          updated_at
        ) VALUES (
          $1, $2, $3, $4, $5, $6::jsonb, $7, $8, NOW(), NOW()
        )
        """,
        [
          queue.name,
          queue.purpose,
          queue.direction,
          queue.source,
          queue.consumer,
          Jason.encode!(queue.message_schema),
          queue.retention_days,
          queue.enabled
        ]
      )

      Logger.debug("[SharedQueueRegistry] Created queue: #{queue.name}")
    end)

    Logger.info("[SharedQueueRegistry] Successfully populated queue_registry")
    :ok
  rescue
    e ->
      Logger.error("[SharedQueueRegistry] Failed to populate queue_registry", %{
        error: inspect(e)
      })

      {:error, e}
  end

  @doc """
  Query the queue registry from shared_queue database (for all services).

  All services can call this to discover available queues without code changes.
  """
  def list_from_database(repo \\ CentralCloud.SharedQueueRepo) do
    case Ecto.Adapters.SQL.query(repo, "SELECT queue_name, purpose, direction, source, consumer, message_schema, retention_days FROM queue_registry WHERE enabled = true ORDER BY queue_name") do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [name, purpose, direction, source, consumer, schema, retention] ->
          %{
            name: name,
            purpose: purpose,
            direction: direction,
            source: source,
            consumer: consumer,
            message_schema: Jason.decode!(schema),
            retention_days: retention
          }
        end)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
