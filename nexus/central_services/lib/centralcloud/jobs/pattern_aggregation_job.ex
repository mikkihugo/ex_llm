defmodule CentralCloud.Jobs.PatternAggregationJob do
  @moduledoc """
  CentralCloud.Jobs.PatternAggregationJob

  Oban worker for aggregating patterns learned across all Singularity instances.

  Consolidates local patterns into global insights, enabling cross-instance learning
  and best practice identification. Runs hourly via Oban Cron.

  ## Features

  - Aggregates code, architecture, and framework patterns
  - Clusters similar patterns using simple grouping
  - Ranks by frequency, success rate, and confidence
  - Stores results in pg_cache for fast retrieval
  - Publishes insights via NATS to all instances

  ## Architecture

  Singularity Instances → NATS → PatternAggregationJob → pg_cache → NATS Broadcast

  ## Data Flow

  1. Query patterns from IntelligenceHub and package usage
  2. Group by type (code, architecture, framework)
  3. Cluster and rank patterns
  4. Store top patterns in cache
  5. Publish aggregated insights

  ## Examples

  ```elixir
  # Scheduled via Oban Cron: every hour
  CentralCloud.Jobs.PatternAggregationJob.aggregate_patterns()
  ```

  This job enables global knowledge sharing without disrupting local operations.
  """

  use Oban.Worker,
    queue: :aggregation,
    max_attempts: 3,
    unique: [period: 3600]  # Only one job per hour

  require Logger
  import Ecto.Query
  alias CentralCloud.Repo
  alias CentralCloud.Schemas.Package

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Oban: Running pattern aggregation")

    case aggregate_patterns() do
      :ok ->
        :ok
      {:error, reason} ->
        Logger.error("Pattern aggregation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Aggregate patterns from all Singularity instances into global insights.

  Queries patterns from IntelligenceHub, packages, and code snippets.
  Clusters, ranks, stores in cache, and publishes via NATS.

  Called every 1 hour via Oban Cron.

  ## Returns

  `:ok` on success, or continues on error (retries next hour).
  """
  def aggregate_patterns do
    Logger.debug("📊 Starting pattern aggregation from all instances...")

    try do
      # Step 1: Query patterns from IntelligenceHub stored data
      # For now, we'll aggregate from package usage patterns and analysis results
      code_patterns = aggregate_code_patterns()
      architecture_patterns = aggregate_architecture_patterns()
      framework_patterns = aggregate_framework_patterns()

      # Step 2: Group and cluster similar patterns
      clustered_patterns = cluster_patterns(code_patterns ++ architecture_patterns ++ framework_patterns)

      # Step 3: Rank patterns by frequency and success rate
      ranked_patterns = rank_patterns(clustered_patterns)

      # Step 4: Store top patterns in database (via pg_cache)
      store_aggregated_patterns(ranked_patterns)

      # Step 5: Publish aggregated insights via NATS
      publish_insights(ranked_patterns)

      instance_count = count_active_instances()
      pattern_count = length(ranked_patterns)

      Logger.info("📊 Pattern aggregation complete",
        instances: instance_count,
        patterns: pattern_count,
        code: Enum.count(code_patterns),
        architecture: Enum.count(architecture_patterns),
        framework: Enum.count(framework_patterns)
      )

      :ok
    rescue
      e in Exception ->
        Logger.error("❌ Pattern aggregation failed", error: inspect(e), stacktrace: __STACKTRACE__)
        :ok  # Don't crash - will retry next hour
    end
  end

  # ===========================
  # Private Helper Functions
  # ===========================

  defp aggregate_code_patterns do
    # Query packages grouped by common usage patterns
    # First, get packages with usage stats
    query = from p in Package,
      where: not is_nil(p.usage_stats),
      where: fragment("?->>'pattern_type' IS NOT NULL", p.usage_stats),
      select: %{
        pattern_type: "code",
        ecosystem: p.ecosystem,
        pattern_name: fragment("?->>'pattern_type'", p.usage_stats),
        frequency: fragment("COALESCE((?->>'usage_count')::integer, 1)", p.usage_stats),
        success_rate: fragment("COALESCE((?->>'success_rate')::float, 1.0)", p.usage_stats),
        examples: [p.name],
        package_id: p.id
      },
      limit: 100

    # Also query code snippets for additional patterns
    code_snippet_patterns = aggregate_code_snippet_patterns()
    
    # Combine both sources
    package_patterns = Repo.all(query)
    |> Enum.filter(fn p -> p.pattern_name != nil end)
    
    package_patterns ++ code_snippet_patterns
  rescue
    e ->
      Logger.error("Failed to aggregate code patterns: #{inspect(e)}")
      []
  end

  defp aggregate_code_snippet_patterns do
    # Query code snippets for patterns
    query = from cs in "code_snippets",
      where: not is_nil(cs.analysis_metadata),
      where: fragment("?->>'pattern_type' IS NOT NULL", cs.analysis_metadata),
      select: %{
        pattern_type: "code",
        ecosystem: "mixed",
        pattern_name: fragment("?->>'pattern_type'", cs.analysis_metadata),
        frequency: 1,
        success_rate: 1.0,
        examples: [cs.title],
        package_id: cs.package_id
      },
      limit: 50

    Repo.all(query)
    |> Enum.filter(fn p -> p.pattern_name != nil end)
  rescue
    _ -> []
  end

  defp aggregate_architecture_patterns do
    # Query architectural patterns from analysis_results
    # This would come from analysis_results table (timeseries data)

    # For MVP, return patterns detected from package relationships
    query = from p in Package,
      where: not is_nil(p.detected_framework),
      select: %{
        pattern_type: "architecture",
        ecosystem: p.ecosystem,
        pattern_name: fragment("?->>'framework'", p.detected_framework),
        frequency: 1,
        success_rate: 1.0,
        examples: [p.name]
      },
      where: fragment("?->>'framework' IS NOT NULL", p.detected_framework),
      limit: 100

    Repo.all(query)
  rescue
    _ -> []
  end

  defp aggregate_framework_patterns do
    # Group packages by framework to identify popular patterns
    query = from p in Package,
      group_by: [p.ecosystem, fragment("?->>'framework'", p.detected_framework)],
      select: %{
        pattern_type: "framework",
        ecosystem: p.ecosystem,
        pattern_name: fragment("?->>'framework'", p.detected_framework),
        frequency: count(p.id),
        success_rate: 1.0,
        examples: fragment("array_agg(?)", p.name)
      },
      where: fragment("?->>'framework' IS NOT NULL", p.detected_framework),
      having: count(p.id) > 3,
      limit: 50

    Repo.all(query)
  rescue
    _ -> []
  end

  defp cluster_patterns(patterns) do
    # Group patterns by pattern_type and pattern_name
    # Merge patterns with similar names (simple clustering)
    patterns
    |> Enum.group_by(fn p -> {p.pattern_type, p.pattern_name} end)
    |> Enum.map(fn {{type, name}, pattern_group} ->
      # Merge all patterns in this cluster
      %{
        pattern_type: type,
        pattern_name: name,
        frequency: Enum.sum(Enum.map(pattern_group, & &1.frequency)),
        success_rate: average_success_rate(pattern_group),
        ecosystems: Enum.map(pattern_group, & &1.ecosystem) |> Enum.uniq(),
        examples: Enum.flat_map(pattern_group, & &1.examples) |> Enum.take(5),
        confidence: calculate_pattern_confidence(pattern_group),
        last_seen: DateTime.utc_now()
      }
    end)
    |> Enum.filter(fn p -> p.frequency > 0 end)  # Filter out empty patterns
  end

  defp calculate_pattern_confidence(pattern_group) do
    # Calculate confidence based on frequency, success rate, and ecosystem diversity
    frequency_score = min(Enum.sum(Enum.map(pattern_group, & &1.frequency)) / 10.0, 1.0)
    success_score = average_success_rate(pattern_group)
    diversity_score = min(length(Enum.uniq(Enum.map(pattern_group, & &1.ecosystem))) / 3.0, 1.0)
    
    # Weighted average: frequency (40%), success (40%), diversity (20%)
    (frequency_score * 0.4) + (success_score * 0.4) + (diversity_score * 0.2)
  end

  defp average_success_rate(patterns) do
    if Enum.empty?(patterns) do
      0.0
    else
      Enum.sum(Enum.map(patterns, & &1.success_rate)) / length(patterns)
    end
  end

  defp rank_patterns(patterns) do
    # Rank by weighted score: frequency (70%) + success_rate (30%)
    patterns
    |> Enum.map(fn p ->
      score = (p.frequency * 0.7) + (p.success_rate * 30.0)
      Map.put(p, :rank_score, score)
    end)
    |> Enum.sort_by(& &1.rank_score, :desc)
    |> Enum.take(100)  # Top 100 patterns
  end

  defp store_aggregated_patterns(patterns) do
    # Store patterns in pg_cache for fast retrieval
    cache_key = "aggregated_patterns:#{DateTime.utc_now() |> DateTime.to_date()}"
    cache_value = Jason.encode!(%{
      patterns: patterns,
      updated_at: DateTime.utc_now(),
      count: length(patterns)
    })

    # Use raw SQL to call pg_cache function
    Repo.query!(
      "SELECT cache_set($1, $2, $3)",
      [cache_key, cache_value, 86400]  # TTL: 24 hours
    )

    Logger.debug("Stored #{length(patterns)} patterns in cache: #{cache_key}")
  end

  defp publish_insights(patterns) do
    # Publish aggregated insights to all instances via NATS
    top_patterns = Enum.take(patterns, 20)

    payload = %{
      type: "pattern_aggregation",
      timestamp: DateTime.utc_now(),
      patterns: top_patterns,
      summary: %{
        total_patterns: length(patterns),
        code_patterns: Enum.count(patterns, &(&1.pattern_type == "code")),
        architecture_patterns: Enum.count(patterns, &(&1.pattern_type == "architecture")),
        framework_patterns: Enum.count(patterns, &(&1.pattern_type == "framework"))
      }
    }

    QuantumFlow.send_with_notify("intelligence.insights.aggregated", payload, CentralCloud.Repo)
    Logger.debug("Published aggregated insights to intelligence.insights.aggregated via PgFlow")
  end

  defp count_active_instances do
    # Count distinct instances from usage_analytics in last hour
    case CentralCloud.Repo.query("""
      SELECT COUNT(DISTINCT session_id) 
      FROM usage_analytics 
      WHERE created_at > NOW() - INTERVAL '1 hour'
    """) do
      {:ok, %{rows: [[count]]}} when is_integer(count) -> count
      {:ok, %{rows: [[count]]}} when is_float(count) -> trunc(count)
      _ -> 0
    end
  end
end
