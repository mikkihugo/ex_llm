defmodule Genesis.Cleanup do
  @moduledoc """
  Genesis Cleanup Worker - Oban job for experiment sandbox cleanup

  Runs every 6 hours to clean up old completed experiments and their sandboxes.
  """

  use Oban.Worker, queue: :cleanup, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Genesis.Cleanup: Starting sandbox cleanup job")

    case Genesis.Scheduler.cleanup_old_sandboxes() do
      :ok ->
        Logger.info("Genesis.Cleanup: Cleanup completed successfully")
        :ok

      {:error, reason} ->
        Logger.error("Genesis.Cleanup: Cleanup failed - #{inspect(reason)}")
        {:error, reason}
    end
  end
end
