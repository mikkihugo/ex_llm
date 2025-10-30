defmodule Singularity.Jobs.PatternSyncWorker do
  @moduledoc """
  Oban Worker for syncing framework patterns (every 5 minutes).

  Syncs framework patterns through:
  - PostgreSQL (source of truth, self-learning)
  - ETS Cache (hot patterns, <5ms reads)
  - pgmq (distribute to SPARC fact system)
  - JSON Export (for Rust detector to read)

  Fires real-time notifications via QuantumFlow on completion.

  Uses Oban's persistent job queue for reliable scheduling.
  """

  use Oban.Worker, queue: :default, max_attempts: 2

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("🔄 Syncing framework patterns...")

    try do
      :ok = Singularity.ArchitectureEngine.FrameworkPatternSync.refresh_cache()

      # Notify observers that pattern sync completed
      notify_sync_complete(:patterns)

      Logger.info("✅ Framework patterns synced to ETS/pgmq/JSON")
      :ok
    rescue
      e ->
        Logger.error("❌ Pattern sync exception", error: inspect(e))
        notify_sync_failed(:patterns, e)
        {:error, e}
    end
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
