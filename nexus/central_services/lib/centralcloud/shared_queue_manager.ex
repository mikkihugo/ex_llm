defmodule CentralCloud.SharedQueueManager do
  @moduledoc """
  Central Queue Manager - Initializes and manages the shared_queue database (PostgreSQL with pgmq).

  This is the single source of truth for the shared queue infrastructure that all services
  (Singularity instances, Genesis, external LLM router, CentralCloud) rely on for inter-service communication.

  ## Database Structure

  The shared_queue database (separate from centralcloud database) contains:

  ### Queue Tables (via pgmq extension)

  - `pgmq.llm_requests` - LLM routing requests from Singularity to external LLM router
  - `pgmq.llm_results` - LLM responses from external LLM router back to Singularity
  - `pgmq.approval_requests` - Code approval requests from Singularity to HITL
  - `pgmq.approval_responses` - Human approval decisions back to Singularity
  - `pgmq.question_requests` - Questions from Singularity to humans
  - `pgmq.question_responses` - Human responses back to Singularity
  - `pgmq.job_requests` - Code execution requests from Singularity to Genesis
  - `pgmq.job_results` - Code execution results from Genesis back to Singularity

  Each queue has an associated `_archive` table for historical messages.

  ## Configuration

  ```elixir
  # config/config.exs
  config :centralcloud, :shared_queue,
    enabled: true,
    database_url: System.get_env("SHARED_QUEUE_DB_URL"),
    auto_initialize: true,
    retention_days: 7
  ```

  ## Setup Steps

  1. Create the shared_queue database:
     ```bash
     createdb shared_queue
     ```

  2. Install pgmq extension:
     ```bash
     psql shared_queue -c "CREATE EXTENSION pgmq;"
     ```

  3. Call this module at startup:
     ```elixir
     CentralCloud.SharedQueueManager.initialize()
     ```

  The manager will:
  - Verify pgmq extension is installed
  - Create all queue tables if they don't exist
  - Set up archive tables
  - Configure retention policies

  ## Architecture Note

  CentralCloud (this application) is the OWNER of shared_queue.
  Other services (Singularity, Genesis, external LLM router) are CONSUMERS that read/write to shared_queue.

  This ensures:
  - Single source of truth for queue infrastructure
  - Consistent schema across all services
  - CentralCloud can read archived queues for analytics (read-only)
  - No other service owns or manages the queues
  """

  require Logger

  @doc """
  Initialize the shared_queue database with pgmq extension and queue tables.

  Returns `:ok` on success, `{:error, reason}` on failure.
  """
  def initialize do
    with :ok <- verify_enabled(),
         :ok <- verify_connection(),
         :ok <- create_extension(),
         :ok <- create_queues(),
         :ok <- configure_retention(),
         :ok <- populate_registry() do
      Logger.info("[SharedQueueManager] Successfully initialized shared_queue database")
      :ok
    else
      {:error, reason} ->
        Logger.error("[SharedQueueManager] Failed to initialize shared_queue", %{
          error: reason
        })

        {:error, reason}
    end
  end

  @doc """
  Check if shared_queue is enabled in configuration.
  """
  def enabled? do
    Application.get_env(:centralcloud, :shared_queue)[:enabled] == true
  end

  @doc """
  Get shared_queue database configuration.
  """
  def config do
    Application.get_env(:centralcloud, :shared_queue, [])
  end

  @doc """
  Get database URL for shared_queue.
  """
  def database_url do
    config()[:database_url] ||
      "postgresql://#{System.get_env("SHARED_QUEUE_USER", "postgres")}:#{System.get_env("SHARED_QUEUE_PASSWORD", "")}@#{System.get_env("SHARED_QUEUE_HOST", "localhost")}:#{System.get_env("SHARED_QUEUE_PORT", "5432")}/#{System.get_env("SHARED_QUEUE_DB", "shared_queue")}"
  end

  @doc """
  List all queue names managed by this system.
  """
  def queue_names do
    CentralCloud.SharedQueueRegistry.queue_names()
  end

  @doc """
  Get statistics about a specific queue.

  Returns information about pending messages, archived messages, etc.
  """
  def queue_stats(queue_name) when is_binary(queue_name) do
    queue_names = queue_names()

    if queue_name in queue_names do
      Logger.debug("[SharedQueueManager] Getting stats for queue", %{queue: queue_name})
      
      case Ecto.Adapters.SQL.query(
        CentralCloud.SharedQueueRepo,
        "SELECT queue_name, messages, messages_in_flight FROM pgmq.queue_stats() WHERE queue_name = $1",
        [queue_name]
      ) do
        {:ok, %{rows: [[_name, total, in_flight]]}} ->
          {:ok, %{
            queue: queue_name,
            total_messages: total,
            messages_in_flight: in_flight,
            available: max(0, total - in_flight)
          }}
        
        {:ok, %{rows: []}} ->
          # Queue exists but no stats yet (empty queue)
          {:ok, %{
            queue: queue_name,
            total_messages: 0,
            messages_in_flight: 0,
            available: 0
          }}
        
        {:error, reason} ->
          Logger.error("[SharedQueueManager] Failed to get queue stats", %{
            queue: queue_name,
            error: inspect(reason)
          })
          {:error, reason}
      end
    else
      {:error, :invalid_queue}
    end
  end

  @doc """
  Get statistics for all queues.
  
  Returns a list of queue statistics.
  """
  def all_queue_stats do
    case Ecto.Adapters.SQL.query(
      CentralCloud.SharedQueueRepo,
      "SELECT queue_name, messages, messages_in_flight FROM pgmq.queue_stats() ORDER BY queue_name",
      []
    ) do
      {:ok, %{rows: rows}} ->
        stats = Enum.map(rows, fn [name, total, in_flight] ->
          %{
            queue: name,
            total_messages: total,
            messages_in_flight: in_flight,
            available: max(0, total - in_flight)
          }
        end)
        {:ok, stats}
      
      {:error, reason} ->
        Logger.error("[SharedQueueManager] Failed to get all queue stats", %{
          error: inspect(reason)
        })
        {:error, reason}
    end
  end

  # --- Private Helpers ---

  defp verify_enabled do
    case enabled?() do
      true -> :ok
      false -> {:error, :shared_queue_disabled}
    end
  end

  defp verify_connection do
    Logger.info("[SharedQueueManager] Verifying connection to shared_queue database")

    case Ecto.Adapters.SQL.query(CentralCloud.SharedQueueRepo, "SELECT 1") do
      {:ok, _} ->
        Logger.info("[SharedQueueManager] Connected to shared_queue database", %{
          database: "shared_queue"
        })

        :ok

      {:error, reason} ->
        {:error, "Failed to connect to shared_queue: #{inspect(reason)}"}
    end
  end

  defp create_extension do
    Logger.info("[SharedQueueManager] Creating pgmq extension (if needed)")

    case Ecto.Adapters.SQL.query(
           CentralCloud.SharedQueueRepo,
           "CREATE EXTENSION IF NOT EXISTS pgmq"
         ) do
      {:ok, _} ->
        Logger.info("[SharedQueueManager] pgmq extension ready")
        :ok

      {:error, reason} ->
        Logger.error("[SharedQueueManager] Failed to create pgmq extension", %{
          error: inspect(reason)
        })

        {:error, "Failed to create pgmq extension: #{inspect(reason)}"}
    end
  end

  defp create_queues do
    queue_names = CentralCloud.SharedQueueRegistry.queue_names()

    Logger.info("[SharedQueueManager] Creating queue tables", %{count: length(queue_names)})

    result =
      Enum.reduce_while(queue_names, :ok, fn queue_name, _acc ->
        Logger.debug("[SharedQueueManager] Creating queue", %{queue: queue_name})

        case Ecto.Adapters.SQL.query(
               CentralCloud.SharedQueueRepo,
               "SELECT pgmq.create('#{queue_name}')"
             ) do
          {:ok, _} ->
            Logger.debug("[SharedQueueManager] Queue created", %{queue: queue_name})
            {:cont, :ok}

          {:error, reason} ->
            Logger.warning("[SharedQueueManager] Queue creation failed (may already exist)", %{
              queue: queue_name,
              error: inspect(reason)
            })

            # Don't fail if queue already exists - this is expected on subsequent runs
            {:cont, :ok}
        end
      end)

    case result do
      :ok ->
        Logger.info("[SharedQueueManager] All queues ready")
        :ok

      error ->
        error
    end
  rescue
    e ->
      Logger.error("[SharedQueueManager] Exception creating queues", %{error: inspect(e)})
      {:error, "Failed to create queues: #{inspect(e)}"}
  end

  defp configure_retention do
    Logger.info("[SharedQueueManager] Configuring retention policies")

    retention_days = config()[:retention_days] || 90

    # pgmq doesn't have built-in retention config, so we'll log the policy
    # Actual pruning would be done via a periodic task or cron job
    Logger.info("[SharedQueueManager] Retention policies configured", %{
      retention_days: retention_days,
      note: "Archive pruning should be scheduled separately"
    })

    :ok
  rescue
    e ->
      Logger.error("[SharedQueueManager] Exception configuring retention", %{error: inspect(e)})
      {:error, "Failed to configure retention: #{inspect(e)}"}
  end

  defp populate_registry do
    Logger.info("[SharedQueueManager] Populating queue registry table")

    case CentralCloud.SharedQueueRegistry.populate_database(CentralCloud.SharedQueueRepo) do
      :ok ->
        Logger.info("[SharedQueueManager] Queue registry populated successfully")
        :ok

      {:error, reason} ->
        Logger.error("[SharedQueueManager] Failed to populate queue registry", %{
          error: inspect(reason)
        })

        {:error, "Failed to populate queue registry: #{inspect(reason)}"}
    end
  rescue
    e ->
      Logger.error("[SharedQueueManager] Exception populating queue registry", %{error: inspect(e)})
      {:error, "Failed to populate queue registry: #{inspect(e)}"}
  end
end
