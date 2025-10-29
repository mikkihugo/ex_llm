defmodule Singularity.CodeAnalysis.Runner do
  @moduledoc """
  Runs comprehensive codebase analysis and returns structured results.
  """

  alias Singularity.CodeStore

  @doc """
  Run full codebase analysis for the configured codebase.
  """
  @spec run() :: {:ok, map()} | {:error, term()}
  def run do
    default_codebase_id = Application.get_env(:singularity, :codebase_id, "singularity")
    run(default_codebase_id)
  end

  @doc """
  Run full codebase analysis for the given `codebase_id`.
  """
  @spec run(String.t()) :: {:ok, map()} | {:error, term()}
  def run(codebase_id) when is_binary(codebase_id) do
    try do
      case CodeStore.analyze_codebase(codebase_id) do
        {:ok, analysis_data} ->
          metadata = extract_metadata(analysis_data)
          file_reports = extract_file_reports(analysis_data)
          summary = extract_summary(analysis_data)

          {:ok,
           %{
             codebase_id: codebase_id,
             metadata: metadata,
             file_reports: file_reports,
             summary: summary,
             detected_technologies: Map.get(metadata, "detected_technologies", []),
             analysis_timestamp: Map.get(metadata, "analysis_timestamp")
           }}

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
      "codebase_id" => analysis_data["codebase_id"] || "unknown",
      "detected_technologies" => analysis_data["technologies"] || [],
      "analysis_timestamp" => DateTime.utc_now(),
      "total_files" => length(analysis_data["files"] || []),
      "languages" => analysis_data["languages"] || [],
      "frameworks" => analysis_data["frameworks"] || [],
      "file_structure" => analysis_data["file_structure"] || %{}
    }
  end

  defp extract_file_reports(analysis_data) do
    files = analysis_data["files"] || []

    Enum.map(files, fn file ->
      %{
        "path" => file["path"] || "",
        "language" => file["language"] || "unknown",
        "size" => file["size"] || 0,
        "complexity" => file["complexity"] || 0,
        "issues" => file["issues"] || []
      }
    end)
  end

  defp extract_summary(analysis_data) do
    %{
      "total_files" => length(analysis_data["files"] || []),
      "total_lines" => analysis_data["total_lines"] || 0,
      "languages" => analysis_data["language_breakdown"] || %{},
      "frameworks" => analysis_data["frameworks"] || [],
      "issues_count" => analysis_data["total_issues"] || 0,
      "quality_score" => analysis_data["quality_score"] || 0.0
    }
  end
end
