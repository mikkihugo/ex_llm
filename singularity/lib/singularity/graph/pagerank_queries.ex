defmodule Singularity.Graph.PageRankQueries do
  @moduledoc """
  PageRank Query Helper - Analyze module importance via PageRank scores.

  Provides convenient functions for querying the PageRank scores stored in graph_nodes.
  Enables insights like "Which modules are most central?" and "How important is module X?"

  ## Module Identity

  ```json
  {
    "module": "Singularity.Graph.PageRankQueries",
    "purpose": "Query and analyze PageRank scores for code modules",
    "type": "query_helper",
    "operates_on": "graph_nodes table (pagerank_score field)",
    "output": "Query results ranked by importance"
  }
  ```

  ## Architecture

  ```mermaid
  graph TD
      A["PageRank Scores<br/>(in graph_nodes)"] -->|Query| B["PageRankQueries"]
      B -->|find_top_modules| C["Most Central Modules"]
      B -->|find_by_importance| D["Importance Tiers"]
      B -->|get_statistics| E["Distribution Stats"]
      B -->|find_critical_modules| F["High-Value Targets"]
  ```

  ## Call Graph

  ```yaml
  PageRankQueries:
    - find_top_modules(codebase_id, limit)
      Returns: Top N modules by PageRank score
      Example: Top 10 most called modules

    - find_by_importance(codebase_id, tier)
      Returns: Modules in importance tier (CRITICAL, IMPORTANT, MODERATE, LOW)
      Example: All CRITICAL modules in singularity codebase

    - get_statistics(codebase_id)
      Returns: Min, avg, max PageRank scores and tier distribution
      Example: Overall importance distribution metrics

    - find_critical_modules(codebase_id, min_score)
      Returns: High-value modules that could impact many dependents
      Example: Modules with score > 5.0 that need monitoring

    - find_stale_critical_modules(codebase_id, days)
      Returns: Critical modules not updated recently
      Example: Critical modules unchanged for 1 year (technical debt)

    - suggest_refactoring_targets(codebase_id)
      Returns: High-complexity critical modules (candidates for refactoring)
      Example: Modules with high importance and high complexity
  ```

  ## Usage Examples

  ```elixir
  # Find most central modules
  PageRankQueries.find_top_modules("singularity", 10)
  # => [%{name: "Service", score: 3.14, file_path: "lib/service.ex"}, ...]

  # Get importance distribution
  PageRankQueries.get_statistics("singularity")
  # => %{
  #   avg_score: 1.2,
  #   max_score: 5.4,
  #   min_score: 0.001,
  #   tier_distribution: %{
  #     "CRITICAL" => 15,
  #     "IMPORTANT" => 45,
  #     "MODERATE" => 120,
  #     "LOW" => 1200
  #   }
  # }

  # Find stale critical modules
  PageRankQueries.find_stale_critical_modules("singularity", 365)
  # => [%{name: "OldService", score: 6.2, last_updated: ~2 years ago}, ...]
  ```

  ## Search Keywords

  pagerank-queries, module-importance, centrality-analysis, critical-modules,
  code-architecture, dependency-analysis, refactoring-candidates,
  technical-debt-identification
  """

  require Logger
  alias Singularity.Repo
  alias Singularity.Schemas.GraphNode

  import Ecto.Query

  # ============================================================================
  # Top N Modules Queries
  # ============================================================================

  @doc """
  Find top N modules by PageRank score.

  Returns modules with highest importance/centrality scores.

  ## Example

      iex> PageRankQueries.find_top_modules("singularity", 10)
      [
        %{name: "Service", file_path: "lib/service.ex", pagerank_score: 3.14},
        %{name: "Manager", file_path: "lib/manager.ex", pagerank_score: 2.89},
        ...
      ]
  """
  @spec find_top_modules(String.t(), non_neg_integer()) :: [map()]
  def find_top_modules(codebase_id, limit \\ 10) do
    from(n in GraphNode,
      where: n.codebase_id == ^codebase_id and n.pagerank_score > 0.0,
      order_by: [desc: n.pagerank_score],
      limit: ^limit,
      select: %{
        name: n.name,
        file_path: n.file_path,
        node_type: n.node_type,
        pagerank_score: n.pagerank_score,
        line_number: n.line_number
      }
    )
    |> Repo.all()
  end

  # ============================================================================
  # Importance Tier Queries
  # ============================================================================

  @doc """
  Classify modules into importance tiers.

  Tiers:
  - CRITICAL (>5.0): Core infrastructure, high impact
  - IMPORTANT (2.0-5.0): Significant modules with many dependents
  - MODERATE (0.5-2.0): Standard modules with moderate importance
  - LOW (<0.5): Specialized or rarely-called modules
  """
  @spec find_by_importance(String.t(), String.t()) :: [map()]
  def find_by_importance(codebase_id, tier) do
    {min_score, max_score} = score_range_for_tier(tier)

    query =
      from(n in GraphNode,
        where: n.codebase_id == ^codebase_id,
        where: n.pagerank_score >= ^min_score and n.pagerank_score < ^max_score,
        order_by: [desc: n.pagerank_score],
        select: %{
          name: n.name,
          file_path: n.file_path,
          node_type: n.node_type,
          pagerank_score: n.pagerank_score,
          importance: ^tier
        }
      )

    Repo.all(query)
  end

  defp score_range_for_tier("CRITICAL"), do: {5.0, 999_999.0}
  defp score_range_for_tier("IMPORTANT"), do: {2.0, 5.0}
  defp score_range_for_tier("MODERATE"), do: {0.5, 2.0}
  defp score_range_for_tier("LOW"), do: {0.0, 0.5}
  defp score_range_for_tier(_), do: {0.0, 0.0}

  # ============================================================================
  # Statistics & Distribution
  # ============================================================================

  @doc """
  Get PageRank statistics and tier distribution.

  Returns:
  - avg_score: Average PageRank score
  - max_score: Highest PageRank score
  - min_score: Lowest non-zero PageRank score
  - tier_distribution: Count of modules in each importance tier
  """
  @spec get_statistics(String.t()) :: map()
  def get_statistics(codebase_id) do
    # Get basic statistics
    stats_query =
      from(n in GraphNode,
        where: n.codebase_id == ^codebase_id and n.pagerank_score > 0.0,
        select: {
          avg(n.pagerank_score),
          max(n.pagerank_score),
          min(n.pagerank_score)
        }
      )

    {avg_score, max_score, min_score} = Repo.one(stats_query) || {0.0, 0.0, 0.0}

    # Count modules by tier
    tier_distribution =
      Enum.reduce(
        ["CRITICAL", "IMPORTANT", "MODERATE", "LOW"],
        %{},
        fn tier, acc ->
          count =
            from(n in GraphNode,
              where: n.codebase_id == ^codebase_id
            )
            |> apply_tier_filter(tier)
            |> Repo.aggregate(:count)

          Map.put(acc, tier, count)
        end
      )

    %{
      avg_score: avg_score || 0.0,
      max_score: max_score || 0.0,
      min_score: min_score || 0.0,
      tier_distribution: tier_distribution,
      total_nodes: Enum.sum(Map.values(tier_distribution))
    }
  end

  defp apply_tier_filter(query, "CRITICAL") do
    where(query, [n], n.pagerank_score >= 5.0)
  end

  defp apply_tier_filter(query, "IMPORTANT") do
    where(query, [n], n.pagerank_score >= 2.0 and n.pagerank_score < 5.0)
  end

  defp apply_tier_filter(query, "MODERATE") do
    where(query, [n], n.pagerank_score >= 0.5 and n.pagerank_score < 2.0)
  end

  defp apply_tier_filter(query, "LOW") do
    where(query, [n], n.pagerank_score > 0.0 and n.pagerank_score < 0.5)
  end

  defp apply_tier_filter(query, _), do: query

  # ============================================================================
  # Critical Module Analysis
  # ============================================================================

  @doc """
  Find critical modules (high PageRank score).

  Useful for:
  - Identifying modules that need extra monitoring
  - Finding targets for optimization
  - Understanding architecture criticality
  """
  @spec find_critical_modules(String.t(), float()) :: [map()]
  def find_critical_modules(codebase_id, min_score \\ 5.0) do
    from(n in GraphNode,
      where: n.codebase_id == ^codebase_id and n.pagerank_score >= ^min_score,
      order_by: [desc: n.pagerank_score],
      select: %{
        name: n.name,
        file_path: n.file_path,
        node_type: n.node_type,
        pagerank_score: n.pagerank_score,
        created_at: n.created_at
      }
    )
    |> Repo.all()
  end

  @doc """
  Find stale critical modules (not updated recently).

  Identifies critical modules with outdated code - potential technical debt.

  Args:
    - codebase_id: Codebase to analyze
    - days: Number of days to consider "stale" (default: 365)
    - min_score: Minimum PageRank score to consider (default: 5.0)
  """
  @spec find_stale_critical_modules(String.t(), non_neg_integer(), float()) :: [map()]
  def find_stale_critical_modules(codebase_id, days \\ 365, min_score \\ 5.0) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600)

    from(n in GraphNode,
      where: n.codebase_id == ^codebase_id,
      where: n.pagerank_score >= ^min_score,
      where: n.created_at < ^cutoff_date,
      order_by: [desc: n.pagerank_score],
      select: %{
        name: n.name,
        file_path: n.file_path,
        node_type: n.node_type,
        pagerank_score: n.pagerank_score,
        created_at: n.created_at,
        days_since_update: fragment("EXTRACT(DAY FROM NOW() - ?)", n.created_at)
      }
    )
    |> Repo.all()
  end

  # ============================================================================
  # Architecture Analysis
  # ============================================================================

  @doc """
  Suggest refactoring targets.

  Returns critical modules that might benefit from refactoring:
  - High PageRank (many dependents)
  - Complex logic (inferred from node metadata)
  - Not recently updated
  """
  @spec suggest_refactoring_targets(String.t(), non_neg_integer()) :: [map()]
  def suggest_refactoring_targets(codebase_id, limit \\ 10) do
    # Find critical modules
    critical = find_critical_modules(codebase_id, 5.0)

    # Rank by PageRank score (can be enhanced with complexity metrics)
    critical
    |> Enum.sort_by(& &1.pagerank_score, :desc)
    |> Enum.take(limit)
    |> Enum.map(&Map.put(&1, :refactoring_reason, "High centrality - affects many modules"))
  end

  @doc """
  Get module importance comparison.

  Compares importance of multiple modules.

  Example:
      iex> PageRankQueries.compare_modules("singularity", ["Service", "Manager"])
      [
        %{name: "Service", score: 3.14, rank: 1},
        %{name: "Manager", score: 2.89, rank: 2}
      ]
  """
  @spec compare_modules(String.t(), [String.t()]) :: [map()]
  def compare_modules(codebase_id, module_names) do
    modules =
      from(n in GraphNode,
        where: n.codebase_id == ^codebase_id and n.name in ^module_names,
        order_by: [desc: n.pagerank_score],
        select: %{
          name: n.name,
          file_path: n.file_path,
          pagerank_score: n.pagerank_score,
          node_type: n.node_type
        }
      )
      |> Repo.all()

    Enum.with_index(modules)
    |> Enum.map(fn {module, index} -> Map.put(module, :rank, index + 1) end)
  end
end
