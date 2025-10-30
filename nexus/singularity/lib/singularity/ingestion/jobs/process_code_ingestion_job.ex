defmodule Singularity.Ingestion.Jobs.ProcessCodeIngestionJob do
  @moduledoc """
  Ingest codebase into PostgreSQL for semantic code search (one-time setup)

  Parses entire codebase with language detection:
  - 30+ languages supported
  - Generates embeddings for semantic search
  - Stores in code_chunks table with pgvector

  Runs on application startup. Can be run again to re-ingest changes.

  Previously manual: `mix code.ingest`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Ingesting codebase into semantic search...")

    codebase_id = Application.get_env(:singularity, :codebase_id, "singularity")

    case Singularity.CodeStore.ingest_codebase(codebase_id) do
      {:ok, count} ->
        Logger.info("✅ Ingested #{count} code chunks")
        Logger.info("  - Embeddings generated")
        Logger.info("  - Semantic search enabled")
        :ok

      {:error, reason} ->
        Logger.error("❌ Code ingest failed: #{reason}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during code ingest: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
