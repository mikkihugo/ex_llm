defmodule Mix.Tasks.Registry.Report do
  use Mix.Task

  @shortdoc "Dump latest registry summary as JSON in docs/architecture/"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    codebase_id = Application.get_env(:singularity, :codebase_id, "singularity_app")
    dest = Path.expand("docs/architecture", File.cwd!())
    File.mkdir_p!(dest)

    case Singularity.CodebaseRegistry.latest_summary(codebase_id) do
      nil -> Mix.raise("No registry summary stored for #{codebase_id}")
      summary ->
        file = Path.join(dest, "#{codebase_id}-latest.json")
        File.write!(file, Jason.encode!(summary, pretty: true))
        Mix.shell().info("Wrote #{file}")
    end
  end
end
