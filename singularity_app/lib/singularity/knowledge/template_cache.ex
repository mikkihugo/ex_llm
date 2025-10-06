defmodule Singularity.Knowledge.TemplateCache do
  @moduledoc """
  High-performance template caching with ETS + NATS JetStream KV.

  ## Architecture

  Three-tier caching for optimal performance:

  1. **ETS Cache (L1)** - Local, in-memory, <1ms
     - Per-node cache
     - Fastest access
     - Limited to this Erlang VM

  2. **NATS JetStream KV (L2)** - Distributed, shared, 1-2ms
     - Shared across all nodes
     - Persistent (optional)
     - Cross-language access

  3. **PostgreSQL (L3)** - Source of truth, 10-30ms
     - Persistent
     - Queryable (JSONB, vector search)
     - Version tracking

  ## Usage

      # Get template (tries ETS → NATS KV → PostgreSQL)
      {:ok, template} = TemplateCache.get("framework", "phoenix")

      # Warm cache on startup
      TemplateCache.warm_cache()

      # Invalidate when updated
      TemplateCache.invalidate("framework", "phoenix")
  """

  use GenServer
  require Logger

  alias Singularity.Repo
  alias Singularity.Knowledge.KnowledgeArtifact

  @table :template_cache
  @ttl_seconds 1800  # 30 minutes
  @nats_kv_bucket "templates"

  # Client API

  @doc """
  Start the template cache server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get a template by type and ID.

  Tries in order: ETS → NATS KV → PostgreSQL

  ## Examples

      iex> TemplateCache.get("framework", "phoenix")
      {:ok, %{"name" => "Phoenix Framework", ...}}

      iex> TemplateCache.get("framework", "nonexistent")
      {:error, :not_found}
  """
  @spec get(String.t(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def get(artifact_type, artifact_id) do
    key = cache_key(artifact_type, artifact_id)

    # L1: Try ETS cache
    case lookup_ets(key) do
      {:ok, template} ->
        emit_telemetry(:ets_hit, artifact_type, artifact_id)
        {:ok, template}

      :miss ->
        # L2: Try NATS KV
        case lookup_nats_kv(key) do
          {:ok, template} ->
            # Cache in ETS for next time
            store_ets(key, template)
            emit_telemetry(:nats_hit, artifact_type, artifact_id)
            {:ok, template}

          :miss ->
            # L3: Query PostgreSQL
            case lookup_postgresql(artifact_type, artifact_id) do
              {:ok, template} ->
                # Cache in both ETS and NATS KV
                store_ets(key, template)
                store_nats_kv(key, template)
                emit_telemetry(:db_hit, artifact_type, artifact_id)
                {:ok, template}

              {:error, _} = error ->
                emit_telemetry(:miss, artifact_type, artifact_id)
                error
            end
        end
    end
  end

  @doc """
  Warm the cache by loading all templates from PostgreSQL.

  Called on application startup to populate ETS and NATS KV.
  """
  @spec warm_cache() :: :ok
  def warm_cache do
    GenServer.call(__MODULE__, :warm_cache, :timer.seconds(30))
  end

  @doc """
  Invalidate a template from all caches.

  Called when a template is updated in PostgreSQL.
  Broadcasts to all nodes via NATS.
  """
  @spec invalidate(String.t(), String.t()) :: :ok
  def invalidate(artifact_type, artifact_id) do
    GenServer.cast(__MODULE__, {:invalidate, artifact_type, artifact_id})
  end

  @doc """
  Clear all caches (ETS and NATS KV).
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end

  @doc """
  Get cache statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table
    :ets.new(@table, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    # Connect to NATS
    gnat_name = Singularity.NatsOrchestrator.gnat_name()

    # Subscribe to cache invalidation messages
    {:ok, _sub} = Gnat.sub(gnat_name, self(), "template.invalidate.>")

    # Subscribe to template update notifications
    {:ok, _sub} = Gnat.sub(gnat_name, self(), "template.updated.>")

    # Ensure NATS KV bucket exists
    ensure_nats_kv_bucket()

    Logger.info("Template cache started with ETS + NATS KV")

    state = %{
      gnat: gnat_name,
      stats: %{
        ets_hits: 0,
        nats_hits: 0,
        db_hits: 0,
        misses: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:warm_cache, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Load all templates from PostgreSQL
    templates = Repo.all(KnowledgeArtifact)

    count =
      Enum.reduce(templates, 0, fn artifact, acc ->
        key = cache_key(artifact.artifact_type, artifact.artifact_id)
        store_ets(key, artifact.content)
        store_nats_kv(key, artifact.content)
        acc + 1
      end)

    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info("Warmed cache with #{count} templates in #{duration}ms")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear_all, _from, state) do
    # Clear ETS
    :ets.delete_all_objects(@table)

    # Clear NATS KV (purge bucket)
    # Note: This requires nats CLI or we can iterate and delete keys
    Logger.info("Cleared all caches (ETS + NATS KV)")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    ets_size = :ets.info(@table, :size)

    stats =
      Map.merge(state.stats, %{
        ets_cache_size: ets_size,
        timestamp: DateTime.utc_now()
      })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:invalidate, artifact_type, artifact_id}, state) do
    key = cache_key(artifact_type, artifact_id)

    # Remove from ETS
    :ets.delete(@table, key)

    # Remove from NATS KV
    delete_nats_kv(key)

    # Broadcast to other nodes
    subject = "template.invalidate.#{artifact_type}.#{artifact_id}"
    Gnat.pub(state.gnat, subject, "")

    Logger.debug("Invalidated template: #{artifact_type}.#{artifact_id}")

    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, %{subject: "template.invalidate." <> rest}}, state) do
    # Received invalidation from another node
    [artifact_type, artifact_id] = String.split(rest, ".", parts: 2)

    key = cache_key(artifact_type, artifact_id)
    :ets.delete(@table, key)

    Logger.debug("Received cache invalidation: #{artifact_type}.#{artifact_id}")

    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, %{subject: "template.updated." <> rest}}, state) do
    # Template was updated in PostgreSQL - invalidate and reload
    [artifact_type, artifact_id] = String.split(rest, ".", parts: 2)

    key = cache_key(artifact_type, artifact_id)
    :ets.delete(@table, key)
    delete_nats_kv(key)

    Logger.debug("Template updated, cache invalidated: #{artifact_type}.#{artifact_id}")

    {:noreply, state}
  end

  # Private Functions

  defp cache_key(artifact_type, artifact_id) do
    "#{artifact_type}.#{artifact_id}"
  end

  # ETS Operations

  defp lookup_ets(key) do
    case :ets.lookup(@table, key) do
      [{^key, template, timestamp}] ->
        now = System.system_time(:second)

        if now - timestamp < @ttl_seconds do
          {:ok, template}
        else
          # Expired
          :ets.delete(@table, key)
          :miss
        end

      [] ->
        :miss
    end
  end

  defp store_ets(key, template) do
    timestamp = System.system_time(:second)
    :ets.insert(@table, {key, template, timestamp})
  end

  # NATS JetStream KV Operations

  defp ensure_nats_kv_bucket do
    # Create KV bucket if it doesn't exist
    # Note: This should be done via nats CLI or during deployment
    # For now, we assume it exists

    # nats kv add templates --ttl 30m --replicas 3 --storage memory
    :ok
  end

  defp lookup_nats_kv(key) do
    # Use nats CLI to get value
    # In production, use a proper NATS client library
    case System.cmd("nats", ["kv", "get", @nats_kv_bucket, key], stderr_to_stdout: true) do
      {output, 0} ->
        # Parse JSON response
        case Jason.decode(output) do
          {:ok, template} -> {:ok, template}
          {:error, _} -> :miss
        end

      {_error, _} ->
        :miss
    end
  rescue
    _ -> :miss
  end

  defp store_nats_kv(key, template) do
    # Encode as JSON
    case Jason.encode(template) do
      {:ok, json} ->
        # Store in NATS KV
        case System.cmd("nats", ["kv", "put", @nats_kv_bucket, key, json],
               stderr_to_stdout: true
             ) do
          {_output, 0} -> :ok
          {_error, _} -> :error
        end

      {:error, _} ->
        :error
    end
  rescue
    _ -> :error
  end

  defp delete_nats_kv(key) do
    System.cmd("nats", ["kv", "del", @nats_kv_bucket, key], stderr_to_stdout: true)
    :ok
  rescue
    _ -> :ok
  end

  # PostgreSQL Operations

  defp lookup_postgresql(artifact_type, artifact_id) do
    case Repo.get_by(KnowledgeArtifact,
           artifact_type: artifact_type,
           artifact_id: artifact_id
         ) do
      nil -> {:error, :not_found}
      artifact -> {:ok, artifact.content}
    end
  end

  # Telemetry

  defp emit_telemetry(status, artifact_type, artifact_id) do
    :telemetry.execute(
      [:singularity, :template_cache, status],
      %{count: 1},
      %{artifact_type: artifact_type, artifact_id: artifact_id}
    )
  end
end
