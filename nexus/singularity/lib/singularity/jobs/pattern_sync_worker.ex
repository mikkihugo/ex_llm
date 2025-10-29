defmodule Singularity.Jobs.PatternSyncWorker do
  @moduledoc """
  Oban Worker for syncing framework patterns (every 5 minutes).

  Syncs framework patterns through:
  - PostgreSQL (source of truth, self-learning)
  - ETS Cache (hot patterns, <5ms reads)
  - pgmq (distribute to SPARC fact system)
  - JSON Export (for Rust detector to read)

  Uses Oban's persistent job queue for reliable scheduling.
  """

  use Oban.Worker, queue: :default, max_attempts: 2

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("🔄 Syncing framework patterns...")

    try do
      :ok = Singularity.ArchitectureEngine.FrameworkPatternSync.refresh_cache()
      Logger.info("✅ Framework patterns synced to ETS/pgmq/JSON")
      :ok
    rescue
      e ->
        Logger.error("❌ Pattern sync exception", error: inspect(e))
        {:error, e}
    end
  end
end
