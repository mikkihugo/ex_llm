defmodule Singularity.Jobs.RegistrySyncWorker do
  @moduledoc """
  Run analyzers and persist results to codebase registry (Oban scheduled job)

  Scheduled: Daily at 4:00 AM UTC

  Runs all code analyzers and stores snapshot in registry for:
  - Architecture analysis
  - Quality metrics
  - Dependency tracking
  - Performance trends

  Previously manual: `mix registry.sync`
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    codebase_id = Application.get_env(:singularity, :codebase_id, "singularity")
    snapshot_id = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    Logger.info("Running analysis for #{codebase_id} (snapshot #{snapshot_id})")

    case Singularity.CodeAnalysis.Runner.run() do
      {:ok, metadata, file_reports, summary} ->
        Logger.info("Analysis complete, persisting to registry...")

        Singularity.CodebaseRegistry.upsert_snapshot(
          Map.merge(metadata, %{codebase_id: codebase_id, snapshot_id: snapshot_id})
        )

        Singularity.CodebaseRegistry.insert_file_reports(codebase_id, snapshot_id, file_reports)
        Singularity.CodebaseRegistry.upsert_summary(codebase_id, snapshot_id, summary)

        Logger.info("✅ Registry snapshot saved (#{codebase_id}/#{snapshot_id})")
        :ok

      {:error, reason} ->
        Logger.error("❌ Registry sync failed: #{reason}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during registry sync: #{inspect(e)}")
      {:error, "Exception: #{inspect(e)}"}
  end
end
