defmodule Singularity.MemoryCache do
  @moduledoc """
  In-memory cache database for ultra-fast access.

  Uses ETS (Erlang Term Storage) for:
  - Template cache
  - Embedding cache
  - RAG results cache
  - LLM response cache

  All in-memory = microsecond access times!
  """

  use GenServer
  require Logger

  @tables %{
    templates: :cache_templates,
    embeddings: :cache_embeddings,
    rag_results: :cache_rag_results,
    llm_responses: :cache_llm_responses,
    performance: :cache_performance
  }

  # Cache TTL (time to live)
  @default_ttl :timer.hours(24)
  # 7 days for embeddings
  @embedding_ttl :timer.hours(168)

  # Client API

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, _opts, name: __MODULE__)
  end

  @doc """
  Get from cache - FAST path
  """
  def get(table, key) do
    case :ets.lookup(@tables[table], key) do
      [{^key, value, expiry}] ->
        if DateTime.compare(DateTime.utc_now(), expiry) == :lt do
          {:ok, value}
        else
          # Expired, delete it
          :ets.delete(@tables[table], key)
          :miss
        end

      [] ->
        :miss
    end
  rescue
    _ -> :miss
  end

  @doc """
  Put into cache with TTL
  """
  def put(table, key, value, ttl \\ @default_ttl) do
    expiry = DateTime.add(DateTime.utc_now(), ttl, :millisecond)
    :ets.insert(@tables[table], {key, value, expiry})
    :ok
  end

  @doc """
  Get or compute - best pattern for caching
  """
  def fetch(table, key, compute_fn, ttl \\ @default_ttl) do
    case get(table, key) do
      {:ok, value} ->
        Logger.debug("Cache HIT: #{table}/#{inspect(key)}")
        {:ok, value, :cached}

      :miss ->
        Logger.debug("Cache MISS: #{table}/#{inspect(key)}")

        case compute_fn.() do
          {:ok, value} ->
            put(table, key, value, ttl)
            {:ok, value, :computed}

          error ->
            error
        end
    end
  end

  @doc """
  Batch get - retrieve multiple keys at once
  """
  def batch_get(table, keys) do
    keys
    |> Enum.map(fn key ->
      {key, get(table, key)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Clear specific table
  """
  def clear(table) do
    :ets.delete_all_objects(@tables[table])
    :ok
  end

  @doc """
  Get cache stats
  """
  def stats do
    @tables
    |> Enum.map(fn {name, table} ->
      size = :ets.info(table, :size)
      memory = :ets.info(table, :memory) * :erlang.system_info(:wordsize)

      {name,
       %{
         entries: size,
         memory_bytes: memory,
         memory_mb: Float.round(memory / 1_048_576, 2)
       }}
    end)
    |> Enum.into(%{})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS tables
    tables =
      for {name, table_name} <- @tables do
        # Create table with read concurrency for speed
        :ets.new(table_name, [
          :set,
          :named_table,
          :public,
          read_concurrency: true,
          write_concurrency: true
        ])

        {name, table_name}
      end
      |> Enum.into(%{})

    # Schedule cleanup
    schedule_cleanup()

    Logger.info("MemoryCache initialized with #{map_size(tables)} tables")
    {:ok, %{tables: tables}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Remove expired entries
    now = DateTime.utc_now()

    for {_name, table} <- @tables do
      :ets.select_delete(table, [
        {
          {:"$1", :"$2", :"$3"},
          [{:<, :"$3", now}],
          [true]
        }
      ])
    end

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(30))
  end

  # Specialized cache functions

  @doc """
  Cache embeddings with smart key
  """
  def cache_embedding(text, embedding) do
    key = :crypto.hash(:md5, text)
    put(:embeddings, key, embedding, @embedding_ttl)
  end

  @doc """
  Get cached embedding
  """
  def get_embedding(text) do
    key = :crypto.hash(:md5, text)
    get(:embeddings, key)
  end

  @doc """
  Cache RAG search results
  """
  def cache_rag_results(query, language, results) do
    key = {query, language}
    put(:rag_results, key, results, :timer.hours(6))
  end

  @doc """
  Cache LLM response with semantic key
  """
  def cache_llm_response(prompt_hash, response, metadata \\ %{}) do
    key = prompt_hash

    value = %{
      response: response,
      metadata: metadata,
      cached_at: DateTime.utc_now()
    }

    put(:llm_responses, key, value, :timer.hours(12))
  end

  @doc """
  Warm up cache from PostgreSQL
  """
  def warmup_from_db do
    Task.async(fn ->
      # Load frequently used templates
      warmup_templates()

      # Load recent embeddings
      warmup_embeddings()

      # Load popular RAG queries
      warmup_rag_queries()

      Logger.info("Cache warmup complete: #{inspect(stats())}")
    end)
  end

  defp warmup_templates do
    # Load from TemplateOptimizer's top performers
    case Singularity.Quality.TemplateTracker.analyze_performance() do
      {:ok, %{top_performers: performers}} ->
        Enum.each(performers, fn %{template: template_id} ->
          # Cache the template
          put(:templates, template_id, template_id, :timer.hours(48))
        end)

      _ ->
        :ok
    end
  end

  defp warmup_embeddings do
    # Load recent embeddings from DB
    query = """
    SELECT path, embedding
    FROM embeddings
    WHERE created_at > NOW() - INTERVAL '1 day'
    LIMIT 1000
    """

    case Singularity.Repo.query(query) do
      {:ok, %{rows: rows}} ->
        Enum.each(rows, fn [path, embedding] ->
          cache_embedding(path, embedding)
        end)

      _ ->
        :ok
    end
  end

  defp warmup_rag_queries do
    # Could track popular queries and pre-cache them
    :ok
  end
end
