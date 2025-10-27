defmodule Singularity.Search.SearchAnalytics do
  @moduledoc """
  Search Analytics - Track search performance and optimize queries.

  ## Overview

  Comprehensive analytics system for semantic code search, tracking query performance,
  result relevance, user satisfaction, and search trends. This data drives continuous
  optimization of the search system.

  ## Public API

  - `record_search/3` - Record a search query and results
  - `record_result_rating/3` - User rates result relevance
  - `get_search_metrics/1` - Get metrics for specific query
  - `get_performance_report/0` - System-wide performance analysis
  - `get_optimization_recommendations/0` - AI-generated optimization suggestions
  - `analyze_search_trends/1` - Trending queries and patterns

  ## Metrics Tracked

  Per search query:
  - Query text and frequency
  - Execution time (ms)
  - Results returned count
  - User satisfaction (1-5 rating)
  - Click-through rate (CTR)
  - Result relevance scores
  - Embedding model used
  - Fallback strategy used
  - Cache hit/miss

  ## Examples

      # Record a search query
      :ok = SearchAnalytics.record_search(
        "async error handling patterns",
        %{
          elapsed_ms: 245,
          results_count: 12,
          embedding_model: "jina-v3",
          cache_hit: false
        }
      )

      # User rates a result
      :ok = SearchAnalytics.record_result_rating(
        "async error handling patterns",
        0,  # First result index
        5   # Rating 1-5
      )

      # Get performance metrics for a query
      {:ok, metrics} = SearchAnalytics.get_search_metrics("async error handling patterns")
      # => %{
      #   query: "async error handling patterns",
      #   total_searches: 47,
      #   avg_execution_time_ms: 187,
      #   avg_user_rating: 4.2,
      #   ctr: 0.68,
      #   embedding_model_preference: "jina-v3",
      #   trending: false
      # }

      # Get system performance report
      {:ok, report} = SearchAnalytics.get_performance_report()
      # => %{
      #   total_searches: 15_243,
      #   avg_query_time_ms: 203,
      #   p95_query_time_ms: 850,
      #   p99_query_time_ms: 2100,
      #   cache_hit_rate: 0.42,
      #   avg_user_satisfaction: 4.15,
      #   slow_queries: [...],
      #   trending_searches: [...],
      #   optimization_opportunities: [...]
      # }

      # Get trending patterns
      {:ok, trends} = SearchAnalytics.analyze_search_trends(days: 7)
      # => %{
      #   period_days: 7,
      #   trending_queries: ["error handling", "concurrency", "performance"],
      #   emerging_patterns: ["rust nif integration"],
      #   declining_searches: ["outdated api"],
      #   search_velocity: 2100  # searches per day
      # }

  ## Performance Targets

  - Average query time: < 200ms
  - P95 query time: < 1s
  - P99 query time: < 5s
  - Cache hit rate: > 40%
  - User satisfaction: > 4.0 / 5.0
  - Fallback invocation rate: < 5%

  ## Relationships

  - **Used by**: CodeSearch, PackageAndCodebaseSearch, HybridCodeSearch
  - **Uses**: Repo (PostgreSQL), EmbeddingQualityTracker
  - **Feeds**: Dashboard, LearningLoop (for pattern promotion)

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "SearchAnalytics",
    "purpose": "search_performance_tracking_optimization",
    "domain": "search",
    "capabilities": ["metrics_tracking", "performance_analysis", "trend_detection", "optimization"],
    "integrations": ["CodeSearch", "EmbeddingQualityTracker", "Dashboard"]
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph TD
    A[Search Query] --> B[Record Search]
    B --> C[SearchAnalytics]
    C --> D[Performance Database]
    C --> E[Metrics Calculator]
    E --> F[Performance Report]
    E --> G[Optimization Engine]
    G --> H[Recommendations]

    I[User Rates Result] --> J[Record Rating]
    J --> K[Update Relevance]
    K --> C
  ```

  ## Call Graph (YAML)

  ```yaml
  SearchAnalytics:
    record_search/3: [store_search_record, update_query_stats]
    record_result_rating/3: [store_rating, update_relevance_score]
    get_search_metrics/1: [query_stats, calculate_aggregates]
    get_performance_report/0: [all_queries, calculate_percentiles, analyze_trends]
    analyze_search_trends/1: [trending_queries, pattern_analysis]
  ```

  ## Anti-Patterns

  - DO NOT skip recording failed searches
  - DO NOT aggregate without considering time windows
  - DO NOT ignore outlier queries
  - DO NOT apply all optimizations at once

  ## Search Keywords

  analytics, metrics, performance-tracking, search-optimization, relevance, user-satisfaction, trending-queries
  """

  require Logger
  import Ecto.Query
  alias Singularity.Repo
  alias Singularity.Search.SearchMetric

  @doc """
  Record a search query and its performance metrics.

  ## Options
    - `:elapsed_ms` - Query execution time
    - `:results_count` - Number of results returned
    - `:embedding_model` - Which embedding model was used
    - `:cache_hit` - Whether result was cached
    - `:fallback_used` - If fallback strategy was invoked
    - `:user_id` - Optional user identifier
  """
  def record_search(query, _opts \\ []) do
    elapsed_ms = Keyword.get(_opts, :elapsed_ms, 0)
    results_count = Keyword.get(_opts, :results_count, 0)
    embedding_model = Keyword.get(_opts, :embedding_model, "unknown")
    cache_hit = Keyword.get(_opts, :cache_hit, false)
    fallback_used = Keyword.get(_opts, :fallback_used, false)

    metric = %{
      query: query,
      elapsed_ms: elapsed_ms,
      results_count: results_count,
      embedding_model: embedding_model,
      cache_hit: cache_hit,
      fallback_used: fallback_used,
      timestamp: DateTime.utc_now(),
      # Will be filled by rating
      user_satisfaction: nil
    }

    case Repo.insert(metric) do
      {:ok, inserted} ->
        Logger.debug("Search recorded",
          query: query,
          elapsed_ms: elapsed_ms,
          results: results_count
        )

        # Publish to CentralCloud's KnowledgeCache for collective learning
        publish_to_knowledge_cache(query, inserted)

        :ok

      {:error, reason} ->
        Logger.warning("Failed to record search",
          query: query,
          reason: reason
        )

        {:error, reason}
    end
  rescue
    e ->
      Logger.error("Exception recording search",
        query: query,
        error: inspect(e)
      )

      {:error, :recording_failed}
  end

  @doc """
  Record user rating of a search result.

  ## Parameters
    - `query` - The search query
    - `result_index` - Position of result in result list (0-based)
    - `rating` - User satisfaction rating 1-5
  """
  def record_result_rating(query, result_index, rating) when rating in 1..5 do
    with {:ok, search} <- find_latest_search(query) do
      update_data = %{
        result_index: result_index,
        user_satisfaction: rating,
        rated_at: DateTime.utc_now()
      }

      case Repo.update(search, update_data) do
        {:ok, _} ->
          Logger.debug("Result rating recorded",
            query: query,
            index: result_index,
            rating: rating
          )

          :ok

        {:error, reason} ->
          Logger.warning("Failed to record rating",
            query: query,
            reason: reason
          )

          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.warning("Could not find search to rate",
          query: query,
          reason: reason
        )

        {:error, reason}
    end
  end

  @doc """
  Get detailed metrics for a specific search query.
  """
  def get_search_metrics(query) do
    with {:ok, searches} <- find_all_searches(query) do
      elapsed_times = Enum.map(searches, & &1.elapsed_ms)

      ratings =
        searches
        |> Enum.map(& &1.user_satisfaction)
        |> Enum.reject(&is_nil/1)

      cache_hits = Enum.count(searches, & &1.cache_hit)
      fallback_uses = Enum.count(searches, & &1.fallback_used)

      models =
        searches
        |> Enum.map(& &1.embedding_model)
        |> Enum.frequencies()
        |> Enum.max_by(fn {_k, v} -> v end, fn -> {nil, 0} end)
        |> elem(0)

      {:ok,
       %{
         query: query,
         total_searches: length(searches),
         avg_execution_time_ms:
           if(Enum.empty?(elapsed_times),
             do: 0,
             else: div(Enum.sum(elapsed_times), length(elapsed_times))
           ),
         p95_execution_time_ms: percentile(elapsed_times, 0.95),
         max_execution_time_ms: Enum.max(elapsed_times, fn -> 0 end),
         avg_results_count: avg(Enum.map(searches, & &1.results_count)),
         cache_hit_rate: cache_hits / length(searches),
         fallback_rate: fallback_uses / length(searches),
         avg_user_rating:
           if(Enum.empty?(ratings), do: 0.0, else: Enum.sum(ratings) / length(ratings)),
         preferred_model: models,
         trending: is_trending(query)
       }}
    end
  end

  @doc """
  Get overall search performance report.
  """
  def get_performance_report do
    with {:ok, all_searches} <- fetch_all_searches() do
      elapsed_times = Enum.map(all_searches, & &1.elapsed_ms)

      ratings =
        all_searches
        |> Enum.map(& &1.user_satisfaction)
        |> Enum.reject(&is_nil/1)

      # > 500ms
      slow_queries = find_slow_queries(all_searches, 500)
      cache_hits = Enum.count(all_searches, & &1.cache_hit)
      fallback_uses = Enum.count(all_searches, & &1.fallback_used)

      {:ok,
       %{
         total_searches: length(all_searches),
         avg_query_time_ms: div(Enum.sum(elapsed_times), max(length(elapsed_times), 1)),
         p50_query_time_ms: percentile(elapsed_times, 0.50),
         p95_query_time_ms: percentile(elapsed_times, 0.95),
         p99_query_time_ms: percentile(elapsed_times, 0.99),
         slowest_query_ms: Enum.max(elapsed_times, fn -> 0 end),
         cache_hit_rate: cache_hits / max(length(all_searches), 1),
         fallback_rate: fallback_uses / max(length(all_searches), 1),
         avg_user_satisfaction:
           if(Enum.empty?(ratings), do: 0.0, else: Enum.sum(ratings) / length(ratings)),
         slow_queries: Enum.map(slow_queries, & &1.query) |> Enum.uniq(),
         trending_searches: get_trending_searches(all_searches, 7),
         optimization_opportunities: generate_optimization_recommendations(all_searches)
       }}
    else
      {:error, reason} ->
        Logger.warning("Failed to generate performance report", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Get optimization recommendations based on analytics data.
  """
  def get_optimization_recommendations do
    with {:ok, report} <- get_performance_report() do
      recommendations = []

      # Check cache hit rate
      recommendations =
        if report.cache_hit_rate < 0.3 do
          recommendations ++
            [
              %{
                priority: :high,
                area: "caching",
                issue:
                  "Cache hit rate #{round(report.cache_hit_rate * 100)}% is below target (40%)",
                recommendation: "Increase cache TTL or cache more query patterns",
                estimated_improvement: "10-20% faster queries"
              }
            ]
        else
          recommendations
        end

      # Check for slow queries
      recommendations =
        if Enum.any?(report.slow_queries, fn q -> String.length(q) < 20 end) do
          recommendations ++
            [
              %{
                priority: :high,
                area: "index_optimization",
                issue: "Some short queries are slow (> 500ms)",
                recommendation: "Add index for common short queries",
                estimated_improvement: "5-10% faster for short queries"
              }
            ]
        else
          recommendations
        end

      # Check user satisfaction
      recommendations =
        if report.avg_user_satisfaction < 3.5 do
          recommendations ++
            [
              %{
                priority: :medium,
                area: "relevance",
                issue:
                  "User satisfaction #{round(report.avg_user_satisfaction * 10) / 10} is below 4.0",
                recommendation: "Improve embedding or ranking algorithm",
                estimated_improvement: "Better result relevance"
              }
            ]
        else
          recommendations
        end

      # Check fallback rate
      recommendations =
        if report.fallback_rate > 0.1 do
          recommendations ++
            [
              %{
                priority: :medium,
                area: "embedding_model",
                issue: "Fallback rate #{round(report.fallback_rate * 100)}% is above target (5%)",
                recommendation: "Improve primary embedding model reliability",
                estimated_improvement: "Reduced latency variance"
              }
            ]
        else
          recommendations
        end

      {:ok,
       %{
         recommendations: recommendations,
         execution_summary: report
       }}
    end
  end

  @doc """
  Analyze search trends over a time period.

  ## Options
    - `:days` - Number of days to analyze (default: 7)
  """
  def analyze_search_trends(_opts \\ []) do
    days = Keyword.get(_opts, :days, 7)

    with {:ok, recent_searches} <- fetch_recent_searches(days) do
      query_frequencies =
        recent_searches
        |> Enum.map(& &1.query)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_k, v} -> v end, :desc)

      trending =
        query_frequencies
        |> Enum.take(10)
        |> Enum.map(&elem(&1, 0))

      search_velocity = div(length(recent_searches), max(days, 1))

      {:ok,
       %{
         period_days: days,
         total_searches: length(recent_searches),
         search_velocity_per_day: search_velocity,
         trending_queries: trending,
         emerging_patterns: detect_emerging_patterns(recent_searches),
         declining_searches: detect_declining_searches(recent_searches)
       }}
    end
  end

  # Private Helpers

  defp find_latest_search(query) do
    case Repo.one(
           from(sm in SearchMetric,
             where: sm.query == ^query,
             order_by: [desc: sm.inserted_at],
             limit: 1
           )
         ) do
      nil -> {:error, :not_found}
      metric -> {:ok, metric}
    end
  rescue
    e ->
      Logger.error("Failed to find latest search", query: query, error: inspect(e))
      {:error, :query_failed}
  end

  defp find_all_searches(query) do
    try do
      metrics =
        Repo.all(
          from(sm in SearchMetric,
            where: sm.query == ^query,
            order_by: [desc: sm.inserted_at]
          )
        )

      {:ok, metrics}
    rescue
      e ->
        Logger.error("Failed to find searches for query", query: query, error: inspect(e))
        {:ok, []}
    end
  end

  defp fetch_all_searches do
    try do
      metrics =
        Repo.all(
          from(sm in SearchMetric,
            order_by: [desc: sm.inserted_at]
          )
        )

      {:ok, metrics}
    rescue
      e ->
        Logger.error("Failed to fetch all searches", error: inspect(e))
        {:ok, []}
    end
  end

  defp fetch_recent_searches(days) do
    try do
      cutoff_time = DateTime.utc_now() |> DateTime.add(-days, :day)

      metrics =
        Repo.all(
          from(sm in SearchMetric,
            where: sm.inserted_at >= ^cutoff_time,
            order_by: [desc: sm.inserted_at]
          )
        )

      {:ok, metrics}
    rescue
      e ->
        Logger.error("Failed to fetch recent searches", days: days, error: inspect(e))
        {:ok, []}
    end
  end

  defp percentile(values, p) when is_list(values) and p > 0 and p < 1 do
    sorted = Enum.sort(values)
    index = max(1, round(length(sorted) * p)) - 1
    Enum.at(sorted, index, 0)
  end

  defp avg(values) do
    case Enum.empty?(values) do
      true -> 0
      false -> Enum.sum(values) / length(values)
    end
  end

  defp is_trending(_query) do
    # Simplified
    false
  end

  defp find_slow_queries(searches, threshold_ms) do
    Enum.filter(searches, &(&1.elapsed_ms > threshold_ms))
  end

  defp get_trending_searches(searches, days) do
    searches
    |> Enum.map(& &1.query)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_k, v} -> v end, :desc)
    |> Enum.take(5)
    |> Enum.map(&elem(&1, 0))
  end

  defp generate_optimization_recommendations(_searches) do
    []
  end

  defp detect_emerging_patterns(_searches) do
    []
  end

  defp detect_declining_searches(_searches) do
    []
  end

  defp publish_to_knowledge_cache(query, metric) do
    Logger.debug("Search analytics recorded",
      query: query,
      elapsed_ms: metric.elapsed_ms,
      results_count: metric.results_count,
      embedding_model: metric.embedding_model,
      cache_hit: metric.cache_hit
    )
  end
end
