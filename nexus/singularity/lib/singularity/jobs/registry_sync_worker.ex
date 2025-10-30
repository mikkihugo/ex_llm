defmodule Singularity.Jobs.RegistrySyncWorker do
  @moduledoc """
  Run analyzers and persist results to codebase registry (Oban scheduled job)

  Scheduled: Daily at 4:00 AM UTC.
  Fires real-time notifications via Pgflow on completion.
  Previously manual: `mix registry.sync`.
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  alias Pgflow.Executor
  alias Singularity.Workflows.CodebaseRegistrySyncWorkflow
  alias Singularity.PgFlow

  @impl Oban.Worker
  def perform(_job) do
    codebase_id = Application.get_env(:singularity, :codebase_id, "singularity")

    Logger.info("Running registry sync for #{codebase_id} via PGFlow")

    case Executor.execute(
           CodebaseRegistrySyncWorkflow,
           %{codebase_id: codebase_id},
           Singularity.Repo
         ) do
      {:ok, output} ->
        info = step_payload(output, :persist_snapshot)
        snapshot_codebase = info[:codebase_id] || info["codebase_id"] || codebase_id
        snapshot_id = info[:snapshot_id] || info["snapshot_id"]

        Logger.info("✅ Registry snapshot saved",
          codebase_id: snapshot_codebase,
          snapshot_id: snapshot_id
        )

        # Notify observers that registry sync completed
        notify_sync_complete(:registry, snapshot_codebase, snapshot_id)

        :ok

      {:error, reason} ->
        Logger.error("❌ Registry sync failed", codebase_id: codebase_id, error: inspect(reason))
        notify_sync_failed(:registry, codebase_id, reason)
        {:error, reason}
    end
  rescue
    e ->
      codebase_id = Application.get_env(:singularity, :codebase_id, "singularity")
      Logger.error("Exception during registry sync", error: inspect(e))
      notify_sync_failed(:registry, codebase_id, e)
      {:error, "Exception: #{inspect(e)}"}
  end

  defp step_payload(output, key) do
    output[to_string(key)] || output[key] || %{}
  end

  defp notify_sync_complete(sync_type, codebase_id, snapshot_id) do
    case PgFlow.send_with_notify(
           "sync_notifications",
           %{
             type: "sync_completed",
             sync_type: sync_type,
             codebase_id: codebase_id,
             snapshot_id: snapshot_id,
             timestamp: DateTime.utc_now(),
             status: "success"
           }
         ) do
      {:ok, :sent} ->
        Logger.debug("📢 Registry sync notification sent", codebase_id: codebase_id)

      {:error, reason} ->
        Logger.warning("Failed to send registry sync notification", error: inspect(reason))
    end
  end

  defp notify_sync_failed(sync_type, codebase_id, error) do
    case PgFlow.send_with_notify(
           "sync_notifications",
           %{
             type: "sync_failed",
             sync_type: sync_type,
             codebase_id: codebase_id,
             timestamp: DateTime.utc_now(),
             status: "failed",
             error: inspect(error)
           }
         ) do
      {:ok, :sent} ->
        Logger.debug("📢 Registry sync failure notification sent", codebase_id: codebase_id)

      {:error, reason} ->
        Logger.warning("Failed to send registry sync failure notification",
          error: inspect(reason)
        )
    end
  end
end
