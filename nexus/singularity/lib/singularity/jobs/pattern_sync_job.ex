defmodule Singularity.Jobs.PatternSyncJob do
  @moduledoc """
  Oban background job for syncing framework patterns across the system.

  Syncs framework patterns through:
  - PostgreSQL (source of truth, self-learning)
  - ETS Cache (hot patterns, <5ms reads)
  - pgmq (distribute to SPARC fact system)
  - JSON Export (for Rust detector to read)

  Fires real-time notifications via Pgflow on completion.

  ## Scheduling

  Configured via Oban cron in config.exs:
  ```elixir
  crontab: [
    # Pattern sync: every 5 minutes
    {"*/5 * * * *", Singularity.Jobs.PatternSyncWorker}
  ]
  ```

  ## Manual Triggering

  ```elixir
  Oban.Job.new(%{})
  |> Oban.insert!()
  ```
  """

  use Oban.Worker, queue: :default, max_attempts: 2

  require Logger
  alias Singularity.ArchitectureEngine.FrameworkPatternSync

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("🔄 Syncing framework patterns...")

    try do
      case FrameworkPatternSync.refresh_cache() do
        :ok ->
          Logger.info("✅ Framework patterns synced to ETS/pgmq/JSON")
          notify_sync_complete(:patterns)
          :ok

        {:error, reason} ->
          Logger.error("❌ Pattern sync failed", reason: inspect(reason))
          notify_sync_failed(:patterns, reason)
          # Don't fail - patterns will sync on next cycle
          :ok
      end
    rescue
      e in Exception ->
        Logger.error("❌ Pattern sync exception", error: inspect(e))
        notify_sync_failed(:patterns, e)
        # Log but don't crash the job
        {:error, e}
    end
  end

  @doc """
  Manually trigger pattern synchronization (for testing).
  """
  def trigger_now do
    __MODULE__
    |> Oban.Job.new(%{})
    |> Oban.insert()
  end

  defp notify_sync_complete(sync_type) do
    case Singularity.Infrastructure.PgFlow.Queue.send_with_notify(
           "sync_notifications",
           %{
             type: "sync_completed",
             sync_type: sync_type,
             timestamp: DateTime.utc_now(),
             status: "success"
           }
         ) do
      {:ok, :sent} ->
        Logger.debug("📢 Sync notification sent", sync_type: sync_type)

      {:error, reason} ->
        Logger.warning("Failed to send sync notification",
          sync_type: sync_type,
          error: inspect(reason)
        )
    end
  end

  defp notify_sync_failed(sync_type, error) do
    case Singularity.Infrastructure.PgFlow.Queue.send_with_notify(
           "sync_notifications",
           %{
             type: "sync_failed",
             sync_type: sync_type,
             timestamp: DateTime.utc_now(),
             status: "failed",
             error: inspect(error)
           }
         ) do
      {:ok, :sent} ->
        Logger.debug("📢 Sync failure notification sent", sync_type: sync_type)

      {:error, reason} ->
        Logger.warning("Failed to send sync failure notification",
          sync_type: sync_type,
          error: inspect(reason)
        )
    end
  end
end
