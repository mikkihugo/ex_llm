defmodule Singularity.StartupWarmup do
  @moduledoc """
  Auto-warmup on startup - preloads caches and optimizes performance.
  Runs after all services are started.
  """

  use Task
  require Logger

  def start_link(opts) do
    Task.start_link(__MODULE__, :warmup, [])
  end

  def warmup do
    # Wait for services to be ready
    Process.sleep(2000)

    Logger.info("🚀 Starting auto-warmup sequence...")

    # 1. Warm up memory cache from DB
    warmup_memory_cache()

    # 2. Load top templates
    warmup_templates()

    # 3. Precompute common embeddings
    warmup_embeddings()

    # 4. Initialize TaskGraph with historical data
    warmup_task_graph()

    Logger.info("✅ Auto-warmup complete! System ready for blazing fast performance!")
  end

  defp warmup_memory_cache do
    Logger.info("Warming up memory cache...")

    try do
      Singularity.MemoryCache.warmup_from_db()
      stats = Singularity.MemoryCache.stats()
      Logger.info("Memory cache loaded: #{inspect(stats)}")
    rescue
      e ->
        Logger.warning("Memory cache warmup failed: #{inspect(e)}")
    end
  end

  defp warmup_templates do
    Logger.info("Loading top-performing templates...")

    try do
      case Singularity.Quality.TemplateTracker.analyze_performance() do
        {:ok, %{top_performers: performers}} ->
          Enum.each(Enum.take(performers, 10), fn perf ->
            # Cache the template
            Singularity.MemoryCache.put(:templates, perf.template, perf, :timer.hours(48))
          end)

          Logger.info("Cached #{min(10, length(performers))} top templates")

        _ ->
          Logger.debug("No template history to warmup")
      end
    rescue
      e ->
        Logger.warning("Template warmup failed: #{inspect(e)}")
    end
  end

  defp warmup_embeddings do
    Logger.info("Precomputing embeddings for common queries...")

    common_queries = [
      "create GenServer",
      "pgmq consumer",
      "API endpoint",
      "test suite",
      "error handling",
      "database query",
      "authentication",
      "websocket connection"
    ]

    # Pre-compute embeddings using EmbeddingService (Jina/Google)
    try do
      Enum.each(common_queries, fn query ->
        case Singularity.CodeGeneration.Implementations.EmbeddingGenerator.embed(query) do
          {:ok, embedding} ->
            Singularity.MemoryCache.cache_embedding(query, embedding)

          _ ->
            :ok
        end
      end)

      Logger.info("Pre-computed #{length(common_queries)} embeddings via Jina/Google")
    rescue
      e ->
        Logger.warning("Embedding warmup failed: #{inspect(e)}")
    end
  end

  defp warmup_task_graph do
    Logger.info("Loading TaskGraph historical performance data...")

    try do
      # Load recent successful task decompositions
      query = """
      SELECT DISTINCT task_type, template_id
      FROM template_performance
      WHERE success_rate > 0.8
      ORDER BY updated_at DESC
      LIMIT 20
      """

      case Singularity.Repo.query(query) do
        {:ok, %{rows: rows}} ->
          Enum.each(rows, fn [task_type, template_id] ->
            # Cache the task->template mapping
            Singularity.MemoryCache.put(
              :template_mappings,
              task_type,
              template_id,
              :timer.hours(24)
            )
          end)

          Logger.info("Loaded #{length(rows)} task-template mappings")

        _ ->
          Logger.debug("No TaskGraph history to warmup")
      end
    rescue
      e ->
        Logger.warning("TaskGraph warmup failed: #{inspect(e)}")
    end
  end
end
