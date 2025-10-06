defmodule Mix.Tasks.Analyze.Rust do
  @moduledoc """
  Run comprehensive Rust tooling analysis to extend the codebase analysis database.

  This task runs various cargo tools (cargo-modules, cargo-audit, cargo-bloat, etc.)
  and stores their structured output in the embeddings database for enhanced
  code understanding and AI analysis.

  ## Examples

      # Run full analysis
      mix analyze.rust

  The analysis includes:
  - Module structure (cargo-modules)
  - Security vulnerabilities (cargo-audit)
  - Binary size analysis (cargo-bloat)
  - License information (cargo-license)
  - Outdated dependencies (cargo-outdated)
  - Unused dependencies (cargo-machete)
  """

  use Mix.Task
  alias Singularity.CodeAnalysis.RustToolingAnalyzer

  @impl Mix.Task
  def run(_args) do
    # Start the application to ensure database connection
    Mix.Task.run("app.start", [])

    IO.puts("🔍 Starting comprehensive Rust tooling analysis...")
    IO.puts("This may take a few minutes depending on project size...")

    case RustToolingAnalyzer.analyze_codebase() do
      :ok ->
        IO.puts("✅ Codebase analysis database extended successfully!")
        IO.puts("")
        IO.puts("📊 Query the analysis database:")
        IO.puts("   mix analyze.query")

      {:error, reason} ->
        IO.puts("❌ Analysis failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
