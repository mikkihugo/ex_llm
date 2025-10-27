defmodule Singularity.Jobs.TemplateSyncWorker do
  @moduledoc """
  Sync templates from /templates_data to PostgreSQL (Oban scheduled job)

  Scheduled: Daily at 2:00 AM UTC

  Previously manual: `mix templates.sync --force`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Syncing templates from /templates_data...")

    case Singularity.TemplateStore.sync(force: true, dry_run: false) do
      {:ok, count} ->
        Logger.info("✅ Synced #{count} templates")
        :ok

      {:error, reason} ->
        Logger.error("❌ Template sync failed: #{reason}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during template sync: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
