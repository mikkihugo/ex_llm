defmodule Singularity.Jobs.CacheRefreshWorker do
  @moduledoc """
  Oban Worker for refreshing hot packages materialized view (every 1 hour).

  Replaces Quantum scheduler with Oban's persistent job queue.
  """

  use Oban.Worker, queue: :default, max_attempts: 2

  require Logger
  alias Singularity.Storage.Cache.PostgresCache

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("🔄 Refreshing hot packages materialized view...")

    try do
      case PostgresCache.refresh_hot_packages() do
        :ok ->
          Logger.info("✅ Hot packages materialized view refreshed")
          :ok

        {:error, reason} ->
          Logger.error("❌ Materialized view refresh failed", reason: inspect(reason))
          {:error, reason}
      end
    rescue
      e in Exception ->
        Logger.error("❌ Cache refresh exception", error: inspect(e))
        {:error, e}
    end
  end
end
