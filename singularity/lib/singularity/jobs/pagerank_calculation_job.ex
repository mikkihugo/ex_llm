defmodule Singularity.Jobs.PageRankCalculationJob do
  @moduledoc """
  Background job for calculating and storing PageRank scores in the code graph.

  ## Purpose

  Identifies the most important/central nodes in the call graph based on
  PageRank algorithm. Answers questions like:
  - "Which modules are most frequently called?"
  - "What's the most central component in our architecture?"
  - "Which modules have the highest impact if they fail?"

  ## Algorithm

  Uses iterative PageRank algorithm with:
  - **iterations**: 20 (default) - Number of times to refine scores
  - **damping_factor**: 0.85 (default) - Probability of following links vs. random jump

  Formula: PR(A) = (1-d)/N + d × Σ(PR(T)/C(T))
  Where:
  - d = damping factor (0.85)
  - N = total number of nodes
  - T = nodes pointing to A
  - C(T) = number of outgoing edges from T

  ## Execution

  Can be enqueued in two ways:

  ### 1. Via JobOrchestrator (recommended)
  ```elixir
  {:ok, job} = Singularity.Jobs.JobOrchestrator.enqueue(:pagerank_calculation, %{
    codebase_id: "singularity",
    iterations: 20,
    damping_factor: 0.85
  })
  ```

  ### 2. Direct Oban job (for testing)
  ```elixir
  %{"codebase_id" => "singularity"}
  |> Singularity.Jobs.PageRankCalculationJob.new()
  |> Oban.insert()
  ```

  ## Performance

  For 1000 nodes:
  - Calculation: ~5-10 seconds (20 iterations)
  - Storage: ~2-3 seconds
  - Total: ~10-15 seconds

  For 10,000 nodes:
  - Calculation: ~1-2 minutes
  - Storage: ~10-15 seconds
  - Total: ~2-3 minutes

  ## Results

  Stores PageRank scores in `graph_nodes.pagerank_score` column.

  Query examples:
  ```sql
  -- Top 10 most central modules
  SELECT name, file_path, pagerank_score
  FROM graph_nodes
  WHERE pagerank_score > 0
  ORDER BY pagerank_score DESC
  LIMIT 10;

  -- Module importance distribution
  SELECT
    CASE
      WHEN pagerank_score > 5.0 THEN 'CRITICAL'
      WHEN pagerank_score > 2.0 THEN 'IMPORTANT'
      WHEN pagerank_score > 0.5 THEN 'MODERATE'
      ELSE 'LOW'
    END as importance_level,
    COUNT(*) as module_count,
    ROUND(AVG(pagerank_score)::numeric, 2) as avg_score
  FROM graph_nodes
  WHERE pagerank_score > 0
  GROUP BY importance_level
  ORDER BY avg_score DESC;

  -- Find critical modules that haven't been updated
  SELECT name, file_path, pagerank_score, created_at
  FROM graph_nodes
  WHERE pagerank_score > 5.0
  AND created_at < NOW() - INTERVAL '1 year'
  ORDER BY pagerank_score DESC;
  ```

  ## Module Identity

  ```json
  {
    "module": "Singularity.Jobs.PageRankCalculationJob",
    "purpose": "Calculate and store PageRank scores for code graph modules",
    "type": "background_job",
    "queue": "default",
    "provider": "Oban",
    "scheduling": "manual or via JobOrchestrator",
    "output": "PageRank scores in graph_nodes.pagerank_score"
  }
  ```

  ## Call Graph

  ```yaml
  PageRankCalculationJob:
    input:
      - codebase_id: string (optional, default: "singularity")
      - iterations: integer (optional, default: 20)
      - damping_factor: float (optional, default: 0.85)
    performs:
      1. CodeSearch.Ecto.calculate_pagerank(iterations, damping_factor)
         - Returns: [%{node_id, pagerank_score}, ...]
         - Performance: O(n × iterations) where n = number of nodes
      2. Store scores in graph_nodes table via bulk UPDATE
      3. Log results: top 10 nodes, statistics
    output:
      - Updated graph_nodes.pagerank_score for all nodes
      - Log: "PageRank calculation complete: X nodes updated"
    errors:
      - :calculation_failed - PageRank calculation error
      - :storage_failed - Failed to store scores in database
      - :no_nodes_found - Graph has no nodes
  ```

  ## Anti-Patterns

  ❌ **DO NOT**:
  - Run manually during business hours (CPU intensive)
  - Use damping_factor < 0.5 or > 1.0 (invalid algorithm)
  - Schedule more frequently than daily (scores don't change that much)
  - Use iterations < 10 (insufficient convergence)

  ✅ **DO**:
  - Schedule as background job (via Oban)
  - Run after major code changes
  - Run before analyzing module dependencies
  - Monitor execution time for regressions

  ## Future Enhancements

  1. **Weighted PageRank** - Weight edges by call frequency
  2. **Time-decayed PageRank** - Recent calls count more
  3. **Topic-sensitive PageRank** - Importance within specific modules
  4. **Personalized PageRank** - Starting from specific nodes
  5. **Cache results** - Avoid recalculating unchanged graph

  ## Search Keywords

  pagerank, graph-importance, module-centrality, call-graph-analysis,
  code-significance, architecture-health, dependency-importance
  """

  require Logger
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Singularity.Repo
  alias Singularity.Schemas.GraphNode
  alias Singularity.CodeSearch.Ecto, as: CodeSearchEcto

  import Ecto.Query

  @doc """
  Perform PageRank calculation and storage.

  Args:
    job - Oban job with args:
      - codebase_id (optional, default: "singularity")
      - iterations (optional, default: 20)
      - damping_factor (optional, default: 0.85)
  """
  def perform(job) do
    codebase_id = job.args["codebase_id"] || "singularity"
    iterations = job.args["iterations"] || 20
    damping_factor = job.args["damping_factor"] || 0.85

    Logger.info("🔄 Starting PageRank calculation", %{
      codebase_id: codebase_id,
      iterations: iterations,
      damping_factor: damping_factor
    })

    start_time = System.monotonic_time(:millisecond)

    # Check if we have nodes to process
    node_count = Repo.aggregate(
      from(n in GraphNode, where: n.codebase_id == ^codebase_id),
      :count
    )

    if node_count == 0 do
      Logger.warning("⚠️  No graph nodes found for codebase: #{codebase_id}")
      return {:error, :no_nodes_found}
    end

    # Calculate PageRank scores
    case calculate_and_store_pagerank(codebase_id, iterations, damping_factor) do
      {:ok, stats} ->
        elapsed = System.monotonic_time(:millisecond) - start_time

        Logger.info("✅ PageRank calculation complete", %{
          codebase_id: codebase_id,
          nodes_updated: stats.nodes_updated,
          avg_score: stats.avg_score,
          max_score: stats.max_score,
          min_score: stats.min_score,
          elapsed_ms: elapsed
        })

        log_top_nodes(codebase_id, 10)
        {:ok, stats}

      {:error, reason} ->
        Logger.error("❌ PageRank calculation failed", %{
          codebase_id: codebase_id,
          error: inspect(reason)
        })

        {:error, reason}
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  @doc false
  defp calculate_and_store_pagerank(codebase_id, iterations, damping_factor) do
    try do
      # Step 1: Calculate PageRank scores
      Logger.debug("Calculating PageRank scores...", %{iterations: iterations})

      scores = CodeSearchEcto.calculate_pagerank(iterations, damping_factor)

      if Enum.empty?(scores) do
        Logger.warning("No PageRank scores calculated")
        {:error, :no_scores_calculated}
      else
        # Step 2: Store scores in database
        Logger.debug("Storing #{length(scores)} PageRank scores in database...")
        updated_count = store_pagerank_scores(codebase_id, scores)

        # Step 3: Calculate statistics
        stats = get_pagerank_statistics(codebase_id)

        {:ok, Map.put(stats, :nodes_updated, updated_count)}
      end
    rescue
      e in Exception ->
        Logger.error("Exception during PageRank calculation", error: inspect(e))
        {:error, {:exception, e}}
    end
  end

  @doc false
  defp store_pagerank_scores(codebase_id, scores) do
    # Convert node_id strings to UUIDs and store scores
    Enum.reduce(scores, 0, fn %{node_id: node_id, pagerank_score: score}, acc ->
      case update_node_pagerank(node_id, score) do
        {:ok, 1} -> acc + 1
        {:ok, _} -> acc
        {:error, reason} ->
          Logger.warning("Failed to update node #{node_id}: #{inspect(reason)}")
          acc
      end
    end)
  end

  @doc false
  defp update_node_pagerank(node_id, pagerank_score) do
    try do
      result =
        Repo.update_all(
          from(n in GraphNode, where: n.node_id == ^node_id),
          set: [pagerank_score: pagerank_score]
        )

      {:ok, result}
    rescue
      e -> {:error, e}
    end
  end

  @doc false
  defp get_pagerank_statistics(codebase_id) do
    query =
      from(n in GraphNode,
        where: n.codebase_id == ^codebase_id and n.pagerank_score > 0.0,
        select: {
          count(n.id),
          avg(n.pagerank_score),
          max(n.pagerank_score),
          min(n.pagerank_score)
        }
      )

    case Repo.one(query) do
      {count, avg_score, max_score, min_score} ->
        %{
          nodes_with_score: count || 0,
          avg_score: avg_score || 0.0,
          max_score: max_score || 0.0,
          min_score: min_score || 0.0
        }

      nil ->
        %{
          nodes_with_score: 0,
          avg_score: 0.0,
          max_score: 0.0,
          min_score: 0.0
        }
    end
  end

  @doc false
  defp log_top_nodes(codebase_id, limit) do
    top_nodes =
      Repo.all(
        from(n in GraphNode,
          where: n.codebase_id == ^codebase_id,
          order_by: [desc: n.pagerank_score],
          limit: ^limit,
          select: {n.name, n.file_path, n.pagerank_score}
        )
      )

    Logger.info("📊 Top #{limit} modules by PageRank:")

    Enum.each(top_nodes, fn {name, file_path, score} ->
      Logger.info(
        "  #{String.pad_leading(Float.to_string(score, decimals: 2), 6)} | #{name} (#{file_path})"
      )
    end)
  end
end
