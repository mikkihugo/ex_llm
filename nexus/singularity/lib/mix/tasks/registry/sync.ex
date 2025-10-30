defmodule Mix.Tasks.Registry.Sync do
  use Mix.Task

  alias Pgflow.Executor
  alias Singularity.Workflows.CodebaseRegistrySyncWorkflow

  @shortdoc "Run analyzers and persist results to the codebase registry"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    codebase_id = Application.get_env(:singularity, :codebase_id, "singularity")

    Mix.shell().info("Running registry sync for #{codebase_id} via PGFlow")

    case Executor.execute(
           CodebaseRegistrySyncWorkflow,
           %{codebase_id: codebase_id},
           Singularity.Repo
         ) do
      {:ok, output} ->
        info = step_payload(output, :persist_snapshot)
        snapshot_codebase = info[:codebase_id] || info["codebase_id"] || codebase_id
        snapshot_id = info[:snapshot_id] || info["snapshot_id"] || "?"

        Mix.shell().info("Registry snapshot saved (#{snapshot_codebase}/#{snapshot_id})")

      {:error, reason} ->
        Mix.raise("PGFlow registry sync failed: #{inspect(reason)}")
    end
  end

  defp step_payload(output, key) do
    output[to_string(key)] || output[key] || %{}
  end
end
