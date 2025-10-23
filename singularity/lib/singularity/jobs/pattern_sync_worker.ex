defmodule Singularity.Jobs.PatternSyncWorker do
  @moduledoc """
  Oban Worker for syncing framework patterns (every 5 minutes).

  Syncs framework patterns through:
  - PostgreSQL (source of truth, self-learning)
  - ETS Cache (hot patterns, <5ms reads)
  - NATS (distribute to SPARC fact system)
  - JSON Export (for Rust detector to read)

  Replaces Quantum scheduler with Oban's persistent job queue.
  """

  use Oban.Worker, queue: :default, max_attempts: 2

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("🔄 Syncing framework patterns...")

    try do
      case Singularity.ArchitectureEngine.FrameworkPatternSync.refresh_cache() do
        :ok ->
          Logger.info("✅ Framework patterns synced to ETS/NATS/JSON")
          :ok

        {:error, reason} ->
          Logger.error("❌ Pattern sync failed", reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e in Exception ->
        Logger.error("❌ Pattern sync exception", error: inspect(e))
        {:error, e}
    end
  end
end
