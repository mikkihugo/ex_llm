defmodule Singularity.Knowledge.TemplateCache do
  @moduledoc """
  SIMPLE template cache - just ETS!

  On startup: Load ALL templates from PostgreSQL → ETS
  At runtime: ETS lookup (<1ms)
  On update: NATS broadcast → Reload from PostgreSQL

  No NATS KV, no TTL, no complexity - just fast in-memory cache.
  """

  use GenServer
  require Logger

  alias Singularity.Repo
  alias Singularity.Knowledge.KnowledgeArtifact

  @table :template_cache

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get template from ETS (everything is preloaded)"
  @spec get(String.t(), String.t()) :: {:ok, map()} | {:error, :not_found}
  def get(artifact_type, artifact_id) do
    key = "#{artifact_type}.#{artifact_id}"

    case :ets.lookup(@table, key) do
      [{^key, template}] -> {:ok, template}
      [] -> {:error, :not_found}
    end
  end

  @doc "Load all templates from PostgreSQL into ETS"
  @spec warm_cache() :: :ok
  def warm_cache do
    GenServer.call(__MODULE__, :warm_cache, :timer.seconds(30))
  end

  @doc "Invalidate template (remove from ETS + broadcast)"
  @spec invalidate(String.t(), String.t()) :: :ok
  def invalidate(artifact_type, artifact_id) do
    GenServer.cast(__MODULE__, {:invalidate, artifact_type, artifact_id})
  end

  @doc "Clear all templates from ETS"
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end

  @doc "Get cache stats"
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table
    :ets.new(@table, [:named_table, :set, :public, {:read_concurrency, true}])

    # Connect to NATS
    gnat_name = Singularity.NatsOrchestrator.gnat_name()

    # Subscribe to template updates using Singularity.NatsClient
    Enum.each([
      "template.updated.>",
      "template.invalidate.>"
    ], fn subject ->
      case Singularity.NatsClient.subscribe(subject) do
        :ok -> Logger.info("TemplateCache subscribed to: #{subject}")
        {:error, reason} -> Logger.error("Failed to subscribe to #{subject}: #{reason}")
      end
    end)

    Logger.info("Template cache started (ETS only)")

    {:ok, %{gnat: gnat_name, hits: 0, misses: 0}}
  end

  @impl true
  def handle_call(:warm_cache, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Load ALL templates
    templates = Repo.all(KnowledgeArtifact)

    count =
      Enum.reduce(templates, 0, fn artifact, acc ->
        key = "#{artifact.artifact_type}.#{artifact.artifact_id}"
        :ets.insert(@table, {key, artifact.content})
        acc + 1
      end)

    duration = System.monotonic_time(:millisecond) - start_time
    Logger.info("Loaded #{count} templates into ETS in #{duration}ms")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:clear_all, _from, state) do
    :ets.delete_all_objects(@table)
    Logger.info("Cleared ETS cache")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    size = :ets.info(@table, :size)
    {:reply, %{cache_size: size, hits: state.hits, misses: state.misses}, state}
  end

  @impl true
  def handle_cast({:invalidate, artifact_type, artifact_id}, state) do
    key = "#{artifact_type}.#{artifact_id}"
    :ets.delete(@table, key)

    # Broadcast to other nodes
    Singularity.NatsClient.publish("template.invalidate.#{artifact_type}.#{artifact_id}", "")

    Logger.debug("Invalidated: #{key}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, %{subject: "template.updated." <> rest}}, state) do
    # Reload this template from PostgreSQL
    [artifact_type, artifact_id] = String.split(rest, ".", parts: 2)

    case Repo.get_by(KnowledgeArtifact, artifact_type: artifact_type, artifact_id: artifact_id) do
      nil ->
        # Deleted
        key = "#{artifact_type}.#{artifact_id}"
        :ets.delete(@table, key)

      artifact ->
        # Updated
        key = "#{artifact_type}.#{artifact_id}"
        :ets.insert(@table, {key, artifact.content})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:msg, %{subject: "template.invalidate." <> rest}}, state) do
    # Another node invalidated - remove from our ETS
    [artifact_type, artifact_id] = String.split(rest, ".", parts: 2)
    key = "#{artifact_type}.#{artifact_id}"
    :ets.delete(@table, key)
    {:noreply, state}
  end
end
