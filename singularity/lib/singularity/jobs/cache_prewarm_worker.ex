defmodule Singularity.Jobs.CachePrewarmWorker do
  @moduledoc """
  Oban Worker for prewarming cache with hot data (every 6 hours).

  Replaces Quantum scheduler with Oban's persistent job queue.
  """

  use Oban.Worker, queue: :default, max_attempts: 2

  require Logger
  alias Singularity.Storage.Cache.PostgresCache

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("🔥 Prewarming cache with hot data...")

    try do
      case PostgresCache.prewarm_cache() do
        {:ok, count} ->
          Logger.info("🔥 Prewarmed #{count} cache entries")
          :ok

        {:error, reason} ->
          Logger.error("❌ Cache prewarm failed", reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e in Exception ->
        Logger.error("❌ Cache prewarm exception", error: inspect(e))
        {:error, e}
    end
  end
end
