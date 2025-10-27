# Example usage of FileAnalysisSwarmCoordinator
#
# This demonstrates how to use the swarm pattern for distributed file analysis
# similar to how TodoSwarmCoordinator handles distributed task execution.

defmodule Example.FileAnalysisDemo do
  @moduledoc """
  Demonstration of FileAnalysisSwarmCoordinator usage.

  Shows how to analyze entire codebases using the swarm pattern for parallel processing.
  """

  alias Singularity.Execution.FileAnalysisSwarmCoordinator

  @doc """
  Analyze the current project directory using the swarm pattern.
  """
  def analyze_current_project do
    # Get the project root (assuming we're in the singularity directory)
    project_root = Path.join(File.cwd!(), "../..") |> Path.expand()

    IO.puts("🔍 Analyzing project: #{project_root}")

    # Start the swarm coordinator if not already started
    {:ok, _pid} = FileAnalysisSwarmCoordinator.start_link(max_workers: 4)

    # Analyze the entire project
    case FileAnalysisSwarmCoordinator.analyze_directory(project_root,
           max_workers: 4,
           file_extensions: [".ex", ".exs", ".erl", ".gleam"],
           exclude_patterns: ["_build", "deps", ".git", "node_modules"]
         ) do
      {:ok, file_count} ->
        IO.puts("📋 Queued #{file_count} files for analysis")

        # Monitor progress
        monitor_progress()

      {:error, reason} ->
        IO.puts("❌ Failed to start analysis: #{reason}")
    end
  end

  @doc """
  Analyze specific files only.
  """
  def analyze_specific_files do
    files_to_analyze = [
      "lib/singularity/engines/beam_analysis_engine.ex",
      "lib/singularity/execution/todo_swarm_coordinator.ex",
      "lib/singularity/agents/coordination/capability_registry.ex"
    ]

    IO.puts("🎯 Analyzing specific files: #{Enum.join(files_to_analyze, ", ")}")

    {:ok, _pid} = FileAnalysisSwarmCoordinator.start_link(max_workers: 2)

    case FileAnalysisSwarmCoordinator.analyze_files(files_to_analyze, force_reanalysis: true) do
      {:ok, count} ->
        IO.puts("📋 Analyzing #{count} specific files")

        # Monitor progress
        monitor_progress()

      {:error, reason} ->
        IO.puts("❌ Failed to start analysis: #{reason}")
    end
  end

  @doc """
  Monitor analysis progress until completion.
  """
  def monitor_progress do
    IO.puts("📊 Monitoring analysis progress...")

    monitor_loop()
  end

  defp monitor_loop do
    # Get current status
    status = FileAnalysisSwarmCoordinator.get_status()

    IO.puts(
      "📈 Status: #{status.active_workers} workers, #{status.queued_files} queued, #{status.completed_analyses} completed, #{status.failed_analyses} failed"
    )

    # Continue monitoring if work in progress
    if status.active_workers > 0 or status.queued_files > 0 do
      # Check every 2 seconds
      Process.sleep(2000)
      monitor_loop()
    else
      IO.puts("✅ Analysis complete!")

      IO.puts(
        "📊 Final results: #{status.completed_analyses} successful, #{status.failed_analyses} failed"
      )
    end
  end

  @doc """
  Compare sequential vs parallel analysis performance.
  """
  def benchmark_analysis do
    project_root = Path.join(File.cwd!(), "../..") |> Path.expand()

    # Find some test files
    test_files = Path.wildcard("#{project_root}/lib/**/*.ex") |> Enum.take(5)

    if Enum.empty?(test_files) do
      IO.puts("❌ No .ex files found for benchmarking")
    else
      IO.puts("🏁 Benchmarking analysis of #{length(test_files)} files...")

      # Sequential analysis
      {sequential_time, _} =
        :timer.tc(fn ->
          Enum.each(test_files, fn file ->
            Singularity.Execution.FileAnalysisWorker.analyze_file(file)
          end)
        end)

      # Parallel analysis
      {parallel_time, _} =
        :timer.tc(fn ->
          {:ok, _pid} = FileAnalysisSwarmCoordinator.start_link(max_workers: 4)
          FileAnalysisSwarmCoordinator.analyze_files(test_files)

          # Wait for completion
          wait_for_completion()
        end)

      speedup = sequential_time / parallel_time

      IO.puts("📊 Benchmark Results:")
      IO.puts("  Sequential: #{sequential_time / 1000}ms")
      IO.puts("  Parallel: #{parallel_time / 1000}ms")
      IO.puts("  Speedup: #{Float.round(speedup, 2)}x")
    end
  end

  defp wait_for_completion do
    case FileAnalysisSwarmCoordinator.get_status() do
      %{active_workers: 0, queued_files: 0} ->
        :ok

      _ ->
        Process.sleep(500)
        wait_for_completion()
    end
  end
end
