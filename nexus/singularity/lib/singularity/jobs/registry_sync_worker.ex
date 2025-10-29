defmodule Singularity.Jobs.RegistrySyncWorker do
  @moduledoc """
  Run analyzers and persist results to codebase registry (Oban scheduled job)

  Scheduled: Daily at 4:00 AM UTC.
  Previously manual: `mix registry.sync`.
  """

  use Oban.Worker, queue: :maintenance

  require Logger

  alias Pgflow.Executor
  alias Singularity.Workflows.CodebaseRegistrySyncWorkflow

  @impl Oban.Worker
  def perform(_job) do
    codebase_id = Application.get_env(:singularity, :codebase_id, "singularity")

    Logger.info("Running registry sync for #{codebase_id} via PGFlow")

    case Executor.execute(CodebaseRegistrySyncWorkflow, %{codebase_id: codebase_id}, Singularity.Repo) do
      {:ok, output} ->
        info = step_payload(output, :persist_snapshot)
        snapshot_codebase = info[:codebase_id] || info["codebase_id"] || codebase_id
        snapshot_id = info[:snapshot_id] || info["snapshot_id"]

        Logger.info("✅ Registry snapshot saved",
          codebase_id: snapshot_codebase,
          snapshot_id: snapshot_id
        )

        :ok

      {:error, reason} ->
        Logger.error("❌ Registry sync failed", codebase_id: codebase_id, error: inspect(reason))
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception during registry sync", error: inspect(e))
      {:error, "Exception: #{inspect(e)}"}
  end

  defp step_payload(output, key) do
    output[to_string(key)] || output[key] || %{}
  end
end
