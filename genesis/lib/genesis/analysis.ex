defmodule Genesis.Analysis do
  @moduledoc """
  Genesis Analysis Worker - Oban job for experiment trend analysis

  Runs daily (midnight) to analyze experiment trends and patterns,
  providing insights for future improvement suggestions.
  """

  use Oban.Worker, queue: :analysis, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Genesis.Analysis: Starting trend analysis job")

    case Genesis.Scheduler.analyze_trends() do
      {:ok, message} ->
        Logger.info("Genesis.Analysis: Analysis completed - #{message}")
        :ok

      {:error, reason} ->
        Logger.error("Genesis.Analysis: Analysis failed - #{inspect(reason)}")
        {:error, reason}
    end
  end
end
