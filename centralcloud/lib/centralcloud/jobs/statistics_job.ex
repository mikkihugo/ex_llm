defmodule CentralCloud.Jobs.StatisticsJob do
  @moduledoc """
  Oban job for global statistics generation.

  Generates global insights and statistics from all Singularity instances:
  - Which patterns are most common?
  - Which packages are most used?
  - Which frameworks are trending?
  - What's the global learning efficiency?
  - How many instances are connected?

  Runs every 1 hour via Oban Cron.

  ## Metrics Generated

  - Instance health (count, last seen, status)
  - Pattern popularity (most used patterns across all instances)
  - Package trends (trending packages in each ecosystem)
  - Framework adoption (which frameworks instances use)
  - Learning efficiency (model accuracy, training time)
  - Knowledge growth (new patterns discovered per hour)
  """

  use Oban.Worker,
    queue: :aggregation,
    max_attempts: 3,
    unique: [period: 3600]  # Only one job per hour

  require Logger
  import Ecto.Query
  alias CentralCloud.{Repo, NatsClient}
  alias CentralCloud.Schemas.Package

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Oban: Running statistics generation")

    case generate_statistics() do
      :ok ->
        :ok
      {:error, reason} ->
        Logger.error("Statistics generation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Generate global statistics from all instances.

  Called every 1 hour via Oban Cron.
  """
  def generate_statistics do
    Logger.debug("📈 Generating global statistics...")

    try do
      # Step 1: Count active instances
      active_instances = count_active_instances()

      # Step 2: Aggregate pattern frequencies across all instances
      pattern_stats = aggregate_pattern_frequencies()

      # Step 3: Identify trending packages per ecosystem
      trending_packages = identify_trending_packages()

      # Step 4: Calculate learning efficiency metrics
      learning_efficiency = calculate_learning_efficiency()

      # Step 5: Compute knowledge growth metrics
      knowledge_growth = compute_knowledge_growth()

      # Step 6: Store statistics in database (pg_cache)
      statistics = %{
        timestamp: DateTime.utc_now(),
        active_instances: active_instances,
        pattern_stats: pattern_stats,
        trending_packages: trending_packages,
        learning_efficiency: learning_efficiency,
        knowledge_growth: knowledge_growth
      }

      store_statistics(statistics)

      # Step 7: Publish summary via NATS
      publish_statistics_summary(statistics)

      Logger.info("📈 Global statistics generated",
        instances: active_instances,
        patterns: map_size(pattern_stats),
        trending: Enum.count(trending_packages),
        efficiency: learning_efficiency.overall_score
      )

      :ok
    rescue
      e in Exception ->
        Logger.error("❌ Statistics generation failed", error: inspect(e), stacktrace: __STACKTRACE__)
        :ok  # Don't crash - will retry next hour
    end
  end

  # ===========================
  # Private Statistics Functions
  # ===========================

  defp count_active_instances do
    # Count distinct instances from usage_analytics in last hour
    # For MVP, use session_id as instance identifier

    one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second)

    query = """
    SELECT COUNT(DISTINCT session_id) as instance_count
    FROM usage_analytics
    WHERE created_at > $1
    """

    case Repo.query(query, [one_hour_ago]) do
      {:ok, %{rows: [[count]]}} when is_integer(count) -> count
      {:ok, %{rows: []}} -> 0
      _ -> 0
    end
  rescue
    _ -> 0  # Return 0 if table doesn't exist yet
  end

  defp aggregate_pattern_frequencies do
    # Query patterns from cached aggregation data
    cache_key = "aggregated_patterns:#{DateTime.utc_now() |> DateTime.to_date()}"

    case get_cached_value(cache_key) do
      {:ok, cached_data} ->
        # Extract pattern frequencies from cached aggregation
        patterns = cached_data["patterns"] || []

        patterns
        |> Enum.reduce(%{}, fn pattern, acc ->
          type = pattern["pattern_type"] || "unknown"
          count = Map.get(acc, type, 0)
          Map.put(acc, type, count + 1)
        end)

      _ ->
        # Fallback: count patterns from packages
        %{
          code: count_patterns_by_type("code"),
          architecture: count_patterns_by_type("architecture"),
          framework: count_patterns_by_type("framework")
        }
    end
  end

  defp count_patterns_by_type(pattern_type) do
    # Count packages that have this pattern type in their metadata
    case pattern_type do
      "code" ->
        query = from p in Package,
          where: not is_nil(p.usage_stats),
          where: fragment("?->>'pattern_type' IS NOT NULL", p.usage_stats),
          select: count(p.id)

        Repo.one(query) || 0

      "architecture" ->
        query = from p in Package,
          where: not is_nil(p.detected_framework),
          select: count(p.id)

        Repo.one(query) || 0

      "framework" ->
        query = from p in Package,
          where: not is_nil(p.detected_framework),
          where: fragment("?->>'framework' IS NOT NULL", p.detected_framework),
          select: count(p.id)

        Repo.one(query) || 0

      _ ->
        0
    end
  rescue
    _ -> 0
  end

  defp identify_trending_packages do
    # Identify trending packages per ecosystem based on recent usage

    ecosystems = ["npm", "cargo", "hex", "pypi"]

    Enum.flat_map(ecosystems, fn ecosystem ->
      get_trending_for_ecosystem(ecosystem)
    end)
  end

  defp get_trending_for_ecosystem(ecosystem) do
    # Query packages with high recent activity
    # For MVP, use packages updated in last 30 days with high quality scores

    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 86400, :second)

    query = from p in Package,
      where: p.ecosystem == ^ecosystem,
      where: p.last_updated > ^thirty_days_ago,
      where: not is_nil(p.security_score),
      order_by: [desc: p.security_score, desc: p.last_updated],
      limit: 10,
      select: %{
        ecosystem: p.ecosystem,
        name: p.name,
        version: p.version,
        quality_score: p.security_score,
        last_updated: p.last_updated
      }

    Repo.all(query)
  rescue
    _ -> []
  end

  defp calculate_learning_efficiency do
    # Calculate learning efficiency metrics
    # Based on: patterns learned, packages analyzed, quality improvements

    total_packages = count_total_packages()
    packages_with_quality = count_packages_with_quality()
    avg_quality_score = calculate_average_quality_score()

    efficiency_rate = if total_packages > 0 do
      (packages_with_quality / total_packages * 100) |> Float.round(2)
    else
      0.0
    end

    %{
      total_packages: total_packages,
      packages_analyzed: packages_with_quality,
      efficiency_rate: efficiency_rate,
      avg_quality_score: avg_quality_score,
      overall_score: (efficiency_rate + avg_quality_score) / 2 |> Float.round(2)
    }
  end

  defp count_total_packages do
    query = from p in Package, select: count(p.id)
    Repo.one(query) || 0
  rescue
    _ -> 0
  end

  defp count_packages_with_quality do
    query = from p in Package,
      where: not is_nil(p.security_score),
      select: count(p.id)

    Repo.one(query) || 0
  rescue
    _ -> 0
  end

  defp calculate_average_quality_score do
    query = from p in Package,
      where: not is_nil(p.security_score),
      select: avg(p.security_score)

    case Repo.one(query) do
      nil -> 0.0
      score when is_number(score) -> Float.round(score, 2)
      _ -> 0.0
    end
  rescue
    _ -> 0.0
  end

  defp compute_knowledge_growth do
    # Compute knowledge growth metrics
    # Track: new patterns, new packages, quality improvements

    # Compare with 24 hours ago
    one_day_ago = DateTime.utc_now() |> DateTime.add(-86400, :second)

    packages_added_today = count_packages_since(one_day_ago)

    # Get patterns from today vs yesterday
    patterns_today = get_pattern_count_for_date(DateTime.utc_now() |> DateTime.to_date())
    patterns_yesterday = get_pattern_count_for_date(Date.add(DateTime.utc_now() |> DateTime.to_date(), -1))

    pattern_growth = patterns_today - patterns_yesterday

    %{
      packages_added_24h: packages_added_today,
      pattern_growth_24h: pattern_growth,
      growth_rate: if(packages_added_today > 0, do: "growing", else: "stable"),
      timestamp: DateTime.utc_now()
    }
  end

  defp count_packages_since(datetime) do
    query = from p in Package,
      where: p.inserted_at > ^datetime,
      select: count(p.id)

    Repo.one(query) || 0
  rescue
    _ -> 0
  end

  defp get_pattern_count_for_date(date) do
    cache_key = "aggregated_patterns:#{date}"

    case get_cached_value(cache_key) do
      {:ok, cached_data} ->
        cached_data["count"] || 0

      _ ->
        0
    end
  end

  defp store_statistics(statistics) do
    # Store statistics in pg_cache
    cache_key = "global_statistics:#{DateTime.utc_now() |> DateTime.to_iso8601()}"
    cache_value = Jason.encode!(statistics)

    # Store with 7-day TTL
    Repo.query!(
      "SELECT cache_set($1, $2, $3)",
      [cache_key, cache_value, 7 * 86400]
    )

    # Also store as "latest" for easy retrieval
    Repo.query!(
      "SELECT cache_set($1, $2, $3)",
      ["global_statistics:latest", cache_value, 7 * 86400]
    )

    Logger.debug("Stored global statistics in cache: #{cache_key}")
  end

  defp publish_statistics_summary(statistics) do
    # Publish summary to all instances via NATS
    summary = %{
      type: "global_statistics",
      timestamp: statistics.timestamp,
      active_instances: statistics.active_instances,
      patterns: %{
        code: statistics.pattern_stats[:code] || 0,
        architecture: statistics.pattern_stats[:architecture] || 0,
        framework: statistics.pattern_stats[:framework] || 0,
        total: Enum.sum(Map.values(statistics.pattern_stats))
      },
      trending_count: Enum.count(statistics.trending_packages),
      learning_efficiency: statistics.learning_efficiency.overall_score,
      knowledge_growth: statistics.knowledge_growth
    }

    NatsClient.publish("intelligence.statistics.global", summary)
    Logger.debug("Published global statistics summary to intelligence.statistics.global")
  end

  defp get_cached_value(cache_key) do
    # Retrieve value from pg_cache
    case Repo.query("SELECT cache_get($1)", [cache_key]) do
      {:ok, %{rows: [[value]]}} when is_binary(value) ->
        case Jason.decode(value) do
          {:ok, decoded} -> {:ok, decoded}
          _ -> {:error, :decode_failed}
        end

      {:ok, %{rows: [[nil]]}} ->
        {:error, :not_found}

      _ ->
        {:error, :query_failed}
    end
  rescue
    _ -> {:error, :exception}
  end
end
