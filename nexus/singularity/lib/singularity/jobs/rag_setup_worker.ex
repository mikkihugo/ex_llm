defmodule Singularity.Jobs.RagSetupWorker do
  @moduledoc """
  Full RAG system initialization (one-time setup)

  Orchestrates the complete RAG setup:
  1. Sync templates
  2. Parse codebase
  3. Generate embeddings
  4. Test RAG quality

  Runs on application startup. Idempotent and resumable.

  Previously manual: `mix rag.setup`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Initializing RAG system...")

    case Singularity.RAG.Setup.run() do
      {:ok, results} ->
        Logger.info("✅ RAG system initialized")
        Logger.info("  - Templates synced: #{results.templates_count || "unknown"}")
        Logger.info("  - Codebase parsed: #{results.codebase_files || "unknown"} files")
        Logger.info("  - Embeddings generated: #{results.embeddings_count || "unknown"}")
        Logger.info("  - Quality tested: #{results.quality_score || "unknown"}")
        :ok

      {:error, reason} ->
        SASL.critical_failure(:rag_setup_failure,
          "RAG system setup failed catastrophically",
          reason: reason
        )
        {:error, reason}
    end
  rescue
    e ->
      SASL.critical_failure(:rag_setup_exception,
        "RAG system setup failed with exception",
        error: e
      )
      {:error, "Exception: #{inspect(e)}"}
  end
end
