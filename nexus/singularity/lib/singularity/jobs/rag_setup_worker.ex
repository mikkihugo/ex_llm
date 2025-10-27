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
        Logger.info("  - Templates synced")
        Logger.info("  - Codebase parsed")
        Logger.info("  - Embeddings generated")
        Logger.info("  - Quality tested")
        :ok

      {:error, reason} ->
        Logger.error("❌ RAG setup failed: #{reason}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during RAG setup: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
