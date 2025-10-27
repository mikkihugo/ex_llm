defmodule Mix.Tasks.Registry.Sync do
  use Mix.Task

  @shortdoc "Run analyzers and persist results to the codebase registry"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    codebase_id = Application.get_env(:singularity, :codebase_id, "singularity")
    snapshot_id = DateTime.utc_now() |> DateTime.to_unix(:millisecond)

    Mix.shell().info("Running analysis for #{codebase_id} (snapshot #{snapshot_id})")

    {:ok, metadata, file_reports, summary} = Singularity.CodeAnalysis.Runner.run()

    Singularity.CodebaseRegistry.upsert_snapshot(
      Map.merge(metadata, %{codebase_id: codebase_id, snapshot_id: snapshot_id})
    )

    Singularity.CodebaseRegistry.insert_file_reports(codebase_id, snapshot_id, file_reports)
    Singularity.CodebaseRegistry.upsert_summary(codebase_id, snapshot_id, summary)

    Mix.shell().info("Registry snapshot saved.")
  end
end
