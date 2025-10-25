defmodule Singularity.Jobs.CacheClearWorker do
  @moduledoc """
  Clear CodeAnalysis.Analyzer cache (Oban scheduled job)

  Scheduled: Daily at 3:00 AM UTC

  Clears stale cache entries after codebase analysis.
  Run periodically to prevent stale data.

  Previously manual: `mix analyze.cache clear`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Clearing CodeAnalysis.Analyzer cache...")

    case Process.whereis(Singularity.CodeAnalysis.Analyzer.Cache) do
      nil ->
        Logger.warning("Cache not running - skipping clear")
        :ok

      _pid ->
        :ok = Singularity.CodeAnalysis.Analyzer.Cache.clear()
        Logger.info("✅ Cache cleared successfully")
        :ok
    end
  rescue
    e ->
      Logger.error("Exception during cache clear: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
