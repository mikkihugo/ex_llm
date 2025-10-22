defmodule Centralcloud.KnowledgeCache do
  @moduledoc """
  Knowledge Cache - In-memory caching for templates, patterns, and knowledge assets

  Replaces the Rust knowledge_cache NIF with pure Elixir + ETS.

  Uses ETS (Erlang Term Storage) for high-performance in-memory caching.

  ## Features

  - Fast in-memory caching (ETS provides ~1 microsecond lookups)
  - Distributed cache updates via NATS
  - Asset types: patterns, templates, intelligence, prompts
  - Cache statistics and monitoring

  ## NATS Subjects

  - `knowledge.cache.update.*` - Cache updates from this instance
  - `knowledge.cache.sync.*` - Cache sync requests from other instances
  """

  use GenServer
  require Logger

  alias Centralcloud.NatsClient

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
  Save asset to cache and broadcast update
  """
  def save_asset(asset) when is_map(asset) do
    asset_with_id = ensure_id(asset)
    :ets.insert(@cache_table, {asset_with_id.id, asset_with_id})

    # Broadcast update to other instances
    broadcast_update(asset_with_id)

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

    # Subscribe to cache updates from other instances
    :ok = subscribe_to_updates()

    # Load initial data from templates_data if needed
    # TODO: Implement initial load

    Logger.info("KnowledgeCache ready - using ETS table :#{@cache_table}")
    {:ok, %{updates_received: 0, updates_sent: 0}}
  end

  @impl true
  def handle_info({:nats_msg, msg}, state) do
    handle_cache_update(msg)
    {:noreply, Map.update!(state, :updates_received, &(&1 + 1))}
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

  defp subscribe_to_updates do
    # Subscribe to cache updates from other instances
    NatsClient.subscribe("knowledge.cache.update.>", fn msg ->
      send(self(), {:nats_msg, msg})
    end)

    # Subscribe to cache sync requests
    NatsClient.subscribe("knowledge.cache.sync.request", fn msg ->
      handle_sync_request(msg)
    end)

    :ok
  end

  defp handle_cache_update(msg) do
    case Jason.decode(msg.payload) do
      {:ok, asset} when is_map(asset) ->
        asset_id = asset["id"] || asset[:id]

        if asset_id do
          :ets.insert(@cache_table, {asset_id, asset})
          Logger.debug("Updated cache with asset: #{asset_id}")
        else
          Logger.warn("Received asset without ID, skipping")
        end

      {:error, reason} ->
        Logger.error("Failed to decode cache update: #{inspect(reason)}")
    end
  end

  defp handle_sync_request(msg) do
    # Send all cache entries to requester
    all_assets =
      :ets.tab2list(@cache_table)
      |> Enum.map(fn {_id, asset} -> asset end)

    response = %{
      assets: all_assets,
      count: length(all_assets),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    if msg.reply_to do
      NatsClient.publish(msg.reply_to, Jason.encode!(response))
      Logger.info("Sent cache sync with #{length(all_assets)} assets")
    end
  end

  defp broadcast_update(asset) do
    payload = Jason.encode!(asset)
    subject = "knowledge.cache.update.#{asset.id}"
    NatsClient.publish(subject, payload)
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
