defmodule Singularity.Jobs.CacheCleanupWorker do
  @moduledoc """
  Oban Worker for PostgreSQL cache cleanup (every 15 minutes).

  Uses Oban's persistent job queue for reliable scheduling.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger
  alias Singularity.Storage.Cache.PostgresCache

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("🧹 Running cache cleanup...")

    try do
      case PostgresCache.cleanup_expired() do
        {:ok, count} ->
          if count > 0 do
            Logger.info("🧹 Cleaned up #{count} expired cache entries")
          else
            Logger.debug("🧹 No expired cache entries found")
          end

          :ok

        {:error, reason} ->
          Logger.error("❌ Cache cleanup failed", reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e in Exception ->
        Logger.error("❌ Cache cleanup exception", error: inspect(e))
        {:error, e}
    end
  end
end
