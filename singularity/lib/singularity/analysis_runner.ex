defmodule Singularity.AnalysisRunner do
  @moduledoc """
  Runs comprehensive codebase analysis and returns structured results.
  """

  alias Singularity.CodeStore

  @doc """
  Run full codebase analysis and return results.
  """
  @spec run() :: {:ok, map(), [map()], map()} | {:error, term()}
  def run do
    try do
      # Get current codebase
      codebase_id = Application.get_env(:singularity, :codebase_id, "singularity")

      # Run analysis
      case CodeStore.analyze_codebase(codebase_id) do
        {:ok, analysis_data} ->
          # Extract components
          metadata = extract_metadata(analysis_data)
          file_reports = extract_file_reports(analysis_data)
          summary = extract_summary(analysis_data)

          {:ok, metadata, file_reports, summary}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, "Analysis failed: #{inspect(error)}"}
    end
  end

  defp extract_metadata(analysis_data) do
    %{
      codebase_id: analysis_data["codebase_id"] || "unknown",
      analysis_timestamp: DateTime.utc_now(),
      total_files: length(analysis_data["files"] || []),
      languages: analysis_data["languages"] || [],
      frameworks: analysis_data["frameworks"] || []
    }
  end

  defp extract_file_reports(analysis_data) do
    files = analysis_data["files"] || []

    Enum.map(files, fn file ->
      %{
        path: file["path"] || "",
        language: file["language"] || "unknown",
        size: file["size"] || 0,
        complexity: file["complexity"] || 0,
        issues: file["issues"] || []
      }
    end)
  end

  defp extract_summary(analysis_data) do
    %{
      total_files: length(analysis_data["files"] || []),
      total_lines: analysis_data["total_lines"] || 0,
      languages: analysis_data["language_breakdown"] || %{},
      frameworks: analysis_data["frameworks"] || [],
      issues_count: analysis_data["total_issues"] || 0,
      quality_score: analysis_data["quality_score"] || 0.0
    }
  end
end
