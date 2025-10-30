defmodule Singularity.Jobs.TemplateSyncWorker do
  @moduledoc """
  Sync templates from /templates_data to PostgreSQL (Oban scheduled job)

  Scheduled: Daily at 2:00 AM UTC
  Fires real-time notifications via QuantumFlow on completion.

  Previously manual: `mix templates.sync --force`
  """

  use Singularity.JobQueue.Worker, queue: :maintenance

  require Logger

  @impl true
  def perform(_job) do
    Logger.info("Syncing templates from /templates_data...")

    case Singularity.TemplateStore.sync(force: true, dry_run: false) do
      {:ok, count} ->
        Logger.info("✅ Synced #{count} templates")

        # Notify observers that template sync completed
        notify_sync_complete(:templates, count)

        :ok

      {:error, reason} ->
        Logger.error("❌ Template sync failed: #{reason}")
        notify_sync_failed(:templates, reason)
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during template sync: #{inspect(e)}")
      notify_sync_failed(:templates, e)
      {:error, "Exception: #{inspect(e)}"}
  end

  defp notify_sync_complete(sync_type, count) do
    case Singularity.Infrastructure.QuantumFlow.Queue.send_with_notify(
           "sync_notifications",
           %{
             type: "sync_completed",
             sync_type: sync_type,
             count: count,
             timestamp: DateTime.utc_now(),
             status: "success"
           }
         ) do
      {:ok, :sent} ->
        Logger.debug("📢 Template sync notification sent", count: count)

      {:error, reason} ->
        Logger.warning("Failed to send template sync notification", error: inspect(reason))
    end
  end

  defp notify_sync_failed(sync_type, error) do
    case Singularity.Infrastructure.QuantumFlow.Queue.send_with_notify(
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
        Logger.debug("📢 Template sync failure notification sent")

      {:error, reason} ->
        Logger.warning("Failed to send template sync failure notification",
          error: inspect(reason)
        )
    end
  end
end
