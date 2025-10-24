defmodule Singularity.Architecture.Analyzers.QualityAnalyzer do
  @moduledoc """
  Quality Analyzer - Analyzes code quality issues and violations.

  Detects code quality problems including duplication, complexity violations,
  style issues, and other quality metrics.

  Implements `@behaviour AnalyzerType` for config-driven orchestration.

  ## Quality Checks

  - **Duplication**: Detects code duplication patterns
  - **Complexity**: Identifies overly complex functions
  - **Style**: Checks code style violations
  - **Documentation**: Validates code documentation
  """

  @behaviour Singularity.Architecture.AnalyzerType
  require Logger
  alias Singularity.CodeQuality.AstQualityAnalyzer

  @impl true
  def analyzer_type, do: :quality

  @impl true
  def description, do: "Analyze code quality issues and violations"

  @impl true
  def supported_types do
    ["duplication", "complexity", "style", "documentation", "test_coverage"]
  end

  @impl true
  def analyze(codebase_path, _opts \\ []) when is_binary(codebase_path) do
    try do
      case AstQualityAnalyzer.analyze(codebase_path) do
        {:ok, results} when is_list(results) ->
          results
          |> Enum.map(&format_quality_result/1)
          |> Enum.reject(&is_nil/1)

        {:error, _reason} ->
          []
      end
    rescue
      e ->
        Logger.error("Quality analysis failed for #{codebase_path}", error: inspect(e))
        []
    end
  end

  @impl true
  def learn_pattern(result) do
    # Update quality patterns based on successful fixes
    case result do
      %{type: type, success: true} ->
        Logger.info("Quality issue #{type} was successfully fixed")
        :ok

      %{type: type, success: false} ->
        Logger.info("Quality issue #{type} was not fixed")
        :ok

      _ ->
        :ok
    end
  end

  # Private helpers

  defp format_quality_result(result) when is_map(result) do
    # Convert quality analysis results to standard format
    %{
      type: result[:type] || "unknown",
      severity: result[:severity] || "medium",
      message: result[:message] || inspect(result),
      file: result[:file],
      line: result[:line],
      context: result[:context]
    }
  end

  defp format_quality_result(_), do: nil
end
