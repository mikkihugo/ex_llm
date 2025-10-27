defmodule Singularity.Jobs.PlanningSeedWorker do
  @moduledoc """
  Seed work plan database with Singularity roadmap (one-time setup)

  Seeds strategic themes, epics, and capabilities into planning system.
  Runs on application startup. Idempotent - skips if already seeded.

  Previously manual: `mix planning.seed`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Seeding work plan database...")

    case Singularity.Planning.Seed.run() do
      {:ok, count} ->
        Logger.info("✅ Seeded #{count} work plan items")
        :ok

      {:error, reason} ->
        Logger.error("❌ Planning seed failed: #{reason}")
        {:error, reason}

      :already_seeded ->
        Logger.info("ℹ️  Work plan already seeded")
        :ok
    end
  rescue
    e ->
      Logger.error("Exception during planning seed: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
