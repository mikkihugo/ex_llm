defmodule Singularity.Jobs.KnowledgeMigrateWorker do
  @moduledoc """
  Migrate JSON templates to knowledge_artifacts table (one-time setup)

  Runs on application startup to ensure knowledge base is loaded.
  Idempotent - safe to run multiple times (skips already-migrated items).

  Previously manual: `mix knowledge.migrate`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Syncing knowledge artifacts from Git...")

    {:ok, %{success: success_count, errors: error_count}} =
      Singularity.Knowledge.ArtifactStore.sync_from_git()

    if error_count > 0 do
      Logger.warning("⚠️  Synced #{success_count} artifacts (#{error_count} errors)")
    else
      Logger.info("✅ Synced #{success_count} knowledge artifacts")
    end

    :ok
  rescue
    e ->
      Logger.error("Exception during knowledge sync: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
