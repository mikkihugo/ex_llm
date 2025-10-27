defmodule Singularity.Execution.FileAnalysisWorker do
  @moduledoc """
  FileAnalysisWorker - Individual worker for analyzing files in the swarm.

  This module represents an individual worker process that analyzes a single file
  using the BeamAnalysisEngine. Workers are spawned by FileAnalysisSwarmCoordinator
  and report results back to the coordinator.

  ## Worker Lifecycle

  1. **Spawned** by coordinator with file path and options
  2. **Reads** file content from disk
  3. **Analyzes** using BeamAnalysisEngine
  4. **Reports** results back to coordinator
  5. **Terminates** (supervised by Task supervisor)
  """

  require Logger
  alias Singularity.BeamAnalysisEngine

  @doc """
  Analyze a single file and return results.

  This function is called by the swarm coordinator to process individual files.
  """
  def analyze_file(file_path, opts \\ []) do
    Logger.debug("[FileAnalysisWorker] Starting analysis of #{file_path}")

    start_time = System.monotonic_time(:millisecond)

    try do
      result = perform_analysis(file_path, opts)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      Logger.debug("[FileAnalysisWorker] Completed analysis of #{file_path} in #{duration}ms")

      result
    rescue
      error ->
        SASL.analysis_failure(:file_analysis_failure,
          "File analysis worker failed to analyze file",
          file_path: file_path,
          error: error
        )
        {:error, Exception.message(error)}
    end
  end

  # Private Functions

  defp perform_analysis(file_path, opts) do
    # Read file content
    case File.read(file_path) do
      {:ok, content} ->
        # Detect language from file extension
        language = detect_language(file_path)

        # Skip if language not supported
        if language == "unknown" do
          {:error, "Unsupported file type: #{Path.extname(file_path)}"}
        else
          # Perform analysis
          analyze_with_engine(language, content, file_path, opts)
        end

      {:error, reason} ->
        {:error, "Failed to read file #{file_path}: #{reason}"}
    end
  end

  defp detect_language(file_path) do
    case Path.extname(file_path) do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".erl" -> "erlang"
      ".hrl" -> "erlang"
      ".gleam" -> "gleam"
      _ -> "unknown"
    end
  end

  defp analyze_with_engine(language, content, file_path, opts) do
    case BeamAnalysisEngine.analyze_beam_code(language, content, file_path) do
      {:ok, analysis} ->
        # Add worker metadata
        enhanced_analysis = Map.put(analysis, :worker_metadata, %{
          analyzed_by: "FileAnalysisWorker",
          analysis_time: DateTime.utc_now(),
          file_size: byte_size(content),
          worker_opts: opts
        })

        {:ok, enhanced_analysis}

      {:error, reason} ->
        Logger.warn("[FileAnalysisWorker] BeamAnalysisEngine failed for #{file_path}: #{reason}")
        {:error, reason}
    end
  end
end