defmodule Genesis.Reporting do
  @moduledoc """
  Genesis Reporting Worker - Oban job for metrics reporting to Centralcloud

  Runs daily (1 AM) to aggregate and report experiment metrics to the
  Centralcloud service for cross-instance analysis and learning.
  """

  use Oban.Worker, queue: :analysis, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Genesis.Reporting: Starting metrics reporting job")

    case Genesis.Scheduler.report_metrics() do
      {:ok, message} ->
        Logger.info("Genesis.Reporting: Reporting completed - #{message}")
        :ok

      {:error, reason} ->
        Logger.error("Genesis.Reporting: Reporting failed - #{inspect(reason)}")
        {:error, reason}
    end
  end
end
