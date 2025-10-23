defmodule Singularity.Jobs.DeadCodeDailyCheck do
  @moduledoc """
  Oban job for daily dead code monitoring.

  Runs every day at 9am, stores results in database, alerts on significant changes.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    unique: [period: 21_600]  # Only one job per 6 hours

  require Logger

  alias Singularity.Agents.DeadCodeMonitor

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Oban: Running daily dead code check")

    case DeadCodeMonitor.execute_task(%{task: "daily_check"}) do
      {:ok, result} ->
        Logger.info("Daily dead code check completed: #{inspect(result)}")
        :ok

      {:error, reason} ->
        Logger.error("Daily dead code check failed: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
