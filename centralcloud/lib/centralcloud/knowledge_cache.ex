defmodule CentralCloud.KnowledgeCache do
  @moduledoc """
  Knowledge Cache - In-memory caching for templates, patterns, and knowledge assets

  Replaces the Rust knowledge_cache NIF with pure Elixir + ETS.

  Uses ETS (Erlang Term Storage) for high-performance in-memory caching.

  ## Features

  - Fast in-memory caching (ETS provides ~1 microsecond lookups)
  - Asset types: patterns, templates, intelligence, prompts
  - Cache statistics and monitoring

  ## Architecture

  - Internal to CentralCloud (no NATS/pgmq broadcasting)
  - Loads initial data from database on startup
  - Caches in ETS for fast access
  - Used by IntelligenceHub and FrameworkLearningAgent
  """

  use GenServer
  require Logger

  @cache_table :central_knowledge_cache

  # ===========================
  # Public API
  # ===========================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Load asset from cache by ID
  """
  def load_asset(id) do
    case :ets.lookup(@cache_table, id) do
      [{^id, asset}] -> {:ok, asset}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Save asset to cache (internal only, no broadcasting)
  """
  def save_asset(asset) when is_map(asset) do
    asset_with_id = ensure_id(asset)
    :ets.insert(@cache_table, {asset_with_id.id, asset_with_id})
    Logger.debug("Cached asset: #{asset_with_id.id}")
    {:ok, asset_with_id.id}
  end

  @doc """
  Search assets by type and optional filters
  """
  def search_assets(asset_type, filters \\ %{}) do
    pattern = {{:_, %{asset_type: asset_type}}, [], [:"$_"]}

    results =
      :ets.select(@cache_table, [pattern])
      |> Enum.map(fn {_id, asset} -> asset end)
      |> apply_filters(filters)

    {:ok, results}
  end

  @doc """
  Get cache statistics
  """
  def get_stats do
    %{
      total_entries: :ets.info(@cache_table, :size),
      patterns: count_by_type("pattern"),
      templates: count_by_type("template"),
      intelligence: count_by_type("intelligence"),
      prompts: count_by_type("prompt"),
      memory_bytes: :ets.info(@cache_table, :memory) * :erlang.system_info(:wordsize)
    }
  end

  @doc """
  Clear all cache entries
  """
  def clear_cache do
    :ets.delete_all_objects(@cache_table)
    Logger.info("Knowledge cache cleared")
    :ok
  end

  # ===========================
  # GenServer Callbacks
  # ===========================

  @impl true
  def init(_opts) do
    Logger.info("KnowledgeCache starting with ETS")

    # Create ETS table with optimizations
    :ets.new(@cache_table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    # Load initial data from database if needed
    # TODO: Implement database load for persistence across restarts

    Logger.info("KnowledgeCache ready - using ETS table :#{@cache_table}")
    {:ok, %{entries: 0}}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp ensure_id(asset) do
    if Map.has_key?(asset, :id) or Map.has_key?(asset, "id") do
      asset
    else
      Map.put(asset, :id, generate_id())
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end


  defp count_by_type(type) do
    # Build pattern dynamically to match asset_type
    :ets.select_count(@cache_table, [{{:_, %{asset_type: :"$1"}}, [{:==, :"$1", type}], [true]}])
  rescue
    _ -> 0
  end

  defp apply_filters(assets, filters) when map_size(filters) == 0, do: assets

  defp apply_filters(assets, filters) do
    Enum.filter(assets, fn asset ->
      Enum.all?(filters, fn {key, value} ->
        asset_value = Map.get(asset, key) || Map.get(asset, to_string(key))
        asset_value == value
      end)
    end)
  end
end
