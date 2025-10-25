defmodule Singularity.Jobs.DeadCodeWeeklySummary do
  @moduledoc """
  Oban job for weekly dead code summary reports.

  Runs every Monday at 9am, generates trend analysis and summary.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    # Only one job per week
    unique: [period: 604_800]

  require Logger

  alias Singularity.Agents.DeadCodeMonitor

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Oban: Running weekly dead code summary")

    case DeadCodeMonitor.execute_task(%{task: "weekly_summary"}) do
      {:ok, result} ->
        Logger.info("Weekly dead code summary completed")
        :ok

      {:error, reason} ->
        Logger.error("Weekly dead code summary failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
