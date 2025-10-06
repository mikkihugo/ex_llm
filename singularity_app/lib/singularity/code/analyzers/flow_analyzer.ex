defmodule Singularity.FlowAnalyzer do
  @moduledoc """
  Control Flow Analysis - Extends existing code analysis with CFG

  Uses existing Rust analysis_suite (control_flow module) to detect:
  - Dead ends (code that never returns)
  - Unreachable code
  - Flow completeness

  Leverages existing infrastructure:
  - Rust: analysis_suite/src/analysis/control_flow.rs
  - Database: code_function_control_flow_graphs table (migration ready!)
  - Graphs: Existing CodeDependencyGraph from Rust
  """

  require Logger
  alias Singularity.Repo

  @doc """
  Analyze file for control flow issues

  Uses existing Rust analyzer via NIF (extends current analysis)
  """
  def analyze_file(file_path) do
    Logger.info("FlowAnalyzer: Analyzing #{file_path}")

    # Call existing Rust analyzer (extends it with CFG)
    case call_source_code_analyzer(file_path) do
      {:ok, result} ->
        # Store using existing graph tables!
        store_analysis_result(file_path, result)

        {:ok, %{
          dead_ends: result["dead_ends"] || [],
          unreachable_code: result["unreachable_code"] || [],
          completeness: result["completeness"] || %{},
          has_issues: result["has_issues"] || false
        }}

      {:error, reason} ->
        Logger.error("FlowAnalyzer: Failed to analyze #{file_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get flow analysis summary for codebase
  """
  def get_summary(codebase_name) do
    query = """
    SELECT
      COUNT(*) FILTER (WHERE has_dead_ends = true) as files_with_dead_ends,
      COUNT(*) FILTER (WHERE has_unreachable_code = true) as files_with_unreachable,
      AVG((cfg_nodes::jsonb->'completeness'->>'completeness_score')::float) as avg_completeness
    FROM code_function_control_flow_graphs
    WHERE codebase_name = $1
    """

    case Repo.query(query, [codebase_name]) do
      {:ok, %{rows: [[dead_ends, unreachable, avg_completeness]]}} ->
        {:ok, %{
          files_with_dead_ends: dead_ends || 0,
          files_with_unreachable_code: unreachable || 0,
          avg_completeness: avg_completeness || 0.0
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private Functions

  defp call_source_code_analyzer(file_path) do
    # Call Rust NIF - pure computation, NO I/O!
    case Singularity.SourceCodeAnalyzer.analyze_control_flow(file_path) do
      {:ok, result} ->
        # Convert Rust struct to map
        {:ok, %{
          "dead_ends" => Enum.map(result.dead_ends, &Map.from_struct/1),
          "unreachable_code" => Enum.map(result.unreachable_code, &Map.from_struct/1),
          "completeness" => %{
            "completeness_score" => result.completeness_score,
            "total_paths" => result.total_paths,
            "complete_paths" => result.complete_paths
          },
          "has_issues" => result.has_issues
        }}

      {:error, :nif_not_loaded} ->
        # Fallback if NIF not available
        Logger.warn("Rust NIF not loaded, using fallback")
        case File.read(file_path) do
          {:ok, source_code} -> basic_analysis(source_code)
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_via_nats(file_path, source_code) do
    # Alternative: Use NATS to call TypeScript analyzer (fallback)
    # This bridges to existing infrastructure

    request = %{
      file_path: file_path,
      source_code: source_code,
      analysis_type: "control_flow"
    }

    case Singularity.NatsOrchestrator.request("flow.analyze", request, timeout: 30_000) do
      {:ok, response} -> {:ok, response}
      {:error, _reason} ->
        # Fallback: Basic analysis using existing Elixir code
        basic_analysis(source_code)
    end
  end

  defp basic_analysis(source_code) do
    # Simple pattern-based analysis (fallback)
    lines = String.split(source_code, "\n")

    dead_ends = find_simple_dead_ends(lines)

    {:ok, %{
      "dead_ends" => dead_ends,
      "unreachable_code" => [],
      "completeness" => %{"completeness_score" => if(Enum.empty?(dead_ends), do: 1.0, else: 0.5)},
      "has_issues" => !Enum.empty?(dead_ends)
    }}
  end

  defp find_simple_dead_ends(lines) do
    # Look for common patterns that might be dead ends
    lines
    |> Enum.with_index(1)
    |> Enum.filter(fn {line, _idx} ->
      # Functions that might raise without handling
      String.contains?(line, "!") and
      not String.contains?(line, "rescue") and
      not String.contains?(line, "try")
    end)
    |> Enum.map(fn {line, idx} ->
      %{
        "node_id" => "line_#{idx}",
        "line_number" => idx,
        "reason" => "MayRaiseWithoutHandler",
        "code_snippet" => String.trim(line)
      }
    end)
  end

  defp store_analysis_result(file_path, result) do
    # Store in existing code_function_control_flow_graphs table
    # (Migration already created!)

    query = """
    INSERT INTO code_function_control_flow_graphs (
      codebase_name, file_path, function_name,
      cfg_nodes, cfg_edges,
      has_dead_ends, has_unreachable_code,
      total_paths, complete_paths,
      analyzed_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
    ON CONFLICT (file_path, function_name)
    DO UPDATE SET
      cfg_nodes = EXCLUDED.cfg_nodes,
      cfg_edges = EXCLUDED.cfg_edges,
      has_dead_ends = EXCLUDED.has_dead_ends,
      has_unreachable_code = EXCLUDED.has_unreachable_code,
      analyzed_at = NOW()
    """

    completeness = result["completeness"] || %{}

    params = [
      "singularity",
      file_path,
      extract_function_name(file_path),
      Jason.encode!(result["nodes"] || []),
      Jason.encode!(result["edges"] || []),
      !Enum.empty?(result["dead_ends"] || []),
      !Enum.empty?(result["unreachable_code"] || []),
      completeness["total_paths"] || 0,
      completeness["complete_paths"] || 0
    ]

    case Repo.query(query, params) do
      {:ok, _} -> :ok
      {:error, reason} ->
        Logger.error("FlowAnalyzer: Failed to store result: #{inspect(reason)}")
        :ok
    end
  end

  defp extract_function_name(file_path) do
    file_path
    |> Path.basename()
    |> Path.rootname()
  end
end
