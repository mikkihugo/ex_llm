defmodule Singularity.RefactoringAgent do
  @moduledoc """
  Detects when refactoring is NEEDED based on code analysis.
  Triggers autonomous refactoring tasks based on metrics, not schedules.
  """

  require Logger

  alias Singularity.Analysis

  @doc "Analyze refactoring needs based on codebase metrics"
  def analyze_refactoring_need do
    # Get latest codebase analysis
    case Analysis.Summary.fetch_latest() do
      nil ->
        Logger.warninging("No codebase analysis available")
        []

      analysis ->
        [
          detect_code_duplication(analysis),
          detect_technical_debt(analysis),
          detect_performance_bottlenecks(analysis),
          detect_schema_migrations_needed(analysis)
        ]
        |> Enum.reject(&is_nil/1)
        |> Enum.filter(fn trigger -> trigger.severity in [:high, :critical] end)
    end
  end

  ## Detection Functions

  defp detect_code_duplication(analysis) do
    high_duplication_files =
      analysis.files
      |> Enum.filter(fn file ->
        file.metadata.duplication_percentage > 15.0
      end)

    if length(high_duplication_files) > 10 do
      avg_dup =
        Enum.map(high_duplication_files, & &1.metadata.duplication_percentage)
        |> Enum.sum()
        |> Kernel./(length(high_duplication_files))

      %{
        type: :code_duplication,
        severity: :high,
        affected_files: high_duplication_files,
        suggested_goal: """
        Extract #{length(high_duplication_files)} duplicated patterns into
        shared modules. Duplication average: #{Float.round(avg_dup, 1)}%
        """,
        business_impact: "Reduces maintenance burden, improves consistency",
        estimated_hours: length(high_duplication_files) * 0.5
      }
    else
      nil
    end
  end

  defp detect_technical_debt(analysis) do
    high_complexity_files =
      analysis.files
      |> Enum.filter(fn file ->
        file.metadata.cyclomatic_complexity > 10.0 or
          file.metadata.cognitive_complexity > 15.0 or
          file.metadata.halstead_difficulty > 30.0
      end)

    if length(high_complexity_files) > 5 do
      avg_complexity =
        Enum.map(high_complexity_files, & &1.metadata.cyclomatic_complexity)
        |> Enum.sum()
        |> Kernel./(length(high_complexity_files))

      %{
        type: :technical_debt,
        severity: :high,
        affected_files: high_complexity_files,
        suggested_goal: """
        Refactor #{length(high_complexity_files)} high-complexity modules.
        Average cyclomatic complexity: #{Float.round(avg_complexity, 1)}
        """,
        business_impact: "Reduces bug risk, improves velocity",
        estimated_hours: length(high_complexity_files) * 2
      }
    else
      nil
    end
  end

  defp detect_performance_bottlenecks(_analysis) do
    # TODO: Integrate with telemetry to detect slow endpoints
    # For now, placeholder
    nil
  end

  defp detect_schema_migrations_needed(_analysis) do
    # TODO: Analyze database access patterns
    # Detect N+1 queries via code analysis
    nil
  end
end
