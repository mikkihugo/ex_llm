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
    Logger.info("Migrating knowledge artifacts from JSON...")

    case Singularity.Knowledge.ArtifactStore.migrate() do
      {:ok, count} ->
        Logger.info("✅ Migrated #{count} knowledge artifacts")
        :ok

      {:error, reason} ->
        Logger.error("❌ Knowledge migration failed: #{reason}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during knowledge migration: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
