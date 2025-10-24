defmodule Singularity.CodeAnalysis.Scanners.QualityScanner do
  @moduledoc """
  Quality Scanner - Detects code quality issues.

  Wraps and consolidates AstQualityAnalyzer and related quality checks
  into the unified ScannerType behavior.
  """

  @behaviour Singularity.CodeAnalysis.ScannerType
  require Logger
  alias Singularity.CodeQuality.AstQualityAnalyzer

  @impl true
  def scanner_type, do: :quality

  @impl true
  def description, do: "Detect code quality issues and violations"

  @impl true
  def capabilities do
    ["duplication", "complexity", "quality_violation", "style_issue"]
  end

  @impl true
  def scan(path, _opts \\ []) when is_binary(path) do
    try do
      case AstQualityAnalyzer.analyze(path) do
        {:ok, results} when is_list(results) ->
          results
          |> Enum.map(&format_quality_issue/1)
          |> Enum.reject(&is_nil/1)

        {:error, _reason} ->
          []
      end
    rescue
      e ->
        Logger.error("Quality scanning failed for #{path}", error: inspect(e))
        []
    end
  end

  @impl true
  def learn_from_scan(result) do
    case result do
      %{success: true} ->
        Logger.info("Quality scan was accurate")
        :ok

      %{success: false} ->
        Logger.info("Quality scan needs refinement")
        :ok

      _ ->
        :ok
    end
  end

  # Private helpers

  defp format_quality_issue(issue) when is_map(issue) do
    %{
      type: issue[:type] || "unknown",
      severity: issue[:severity] || "medium",
      message: issue[:message] || inspect(issue),
      file: issue[:file],
      line: issue[:line]
    }
  end

  defp format_quality_issue(_), do: nil
end
