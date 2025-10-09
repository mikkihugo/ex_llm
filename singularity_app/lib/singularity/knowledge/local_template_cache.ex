defmodule Singularity.Knowledge.LocalTemplateCache do
  @moduledoc """
  Local template cache with NATS sync to central cloud.

  Architecture:
  - Central cloud stores global templates via NATS
  - Local instance caches templates in PostgreSQL
  - 24h TTL with background refresh
  - Offline capable (uses stale cache)
  - Contributes learned improvements back to central

  NATS subjects:
  - `central.template.get` - Download template from central
  - `central.template.sync` - Bulk download
  - `central.learning.contribute` - Upload learned improvements
  - `central.template.updated` - Subscribe to updates
  """

  use GenServer
  require Logger

  alias Singularity.Repo
  alias Singularity.Schemas.{TemplateCache, LocalLearning}
  alias Singularity.NATS

  import Ecto.Query

  @cache_ttl_hours 24
  @sync_interval_minutes 60
  @min_usage_for_contribution 100
  @min_confidence 0.8

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get template by ID (checks cache first, downloads from central if needed)
  """
  def get_template(artifact_id) do
    GenServer.call(__MODULE__, {:get_template, artifact_id})
  end

  @doc """
  Track template usage (for learning)
  """
  def track_usage(artifact_id, result) do
    GenServer.cast(__MODULE__, {:track_usage, artifact_id, result})
  end

  @doc """
  Force refresh template from central
  """
  def refresh_template(artifact_id) do
    GenServer.call(__MODULE__, {:refresh_template, artifact_id})
  end

  @doc """
  Sync all templates from central (bulk download)
  """
  def sync_all_templates do
    GenServer.call(__MODULE__, :sync_all, :timer.minutes(5))
  end

  @doc """
  Get cache statistics
  """
  def cache_stats do
    GenServer.call(__MODULE__, :cache_stats)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("LocalTemplateCache starting...")

    # Schedule periodic sync
    schedule_sync()

    # Subscribe to central template updates
    subscribe_to_central_updates()

    {:ok, %{
      nats_connected: false,
      last_sync: nil,
      pending_contributions: []
    }}
  end

  @impl true
  def handle_call({:get_template, artifact_id}, _from, state) do
    result = case get_from_cache(artifact_id) do
      {:ok, cached} when cache_fresh?(cached) ->
        Logger.debug("Template cache HIT (fresh): #{artifact_id}")
        {:ok, cached.content}

      {:ok, cached} ->
        Logger.debug("Template cache HIT (stale): #{artifact_id} - refreshing in background")
        # Use stale cache but refresh in background
        Task.start(fn -> refresh_from_central(artifact_id) end)
        {:ok, cached.content}

      {:error, :not_found} ->
        Logger.debug("Template cache MISS: #{artifact_id} - downloading from central")
        download_from_central(artifact_id)
    end

    {:reply, result, state}
  end

  @impl true
  def handle_call({:refresh_template, artifact_id}, _from, state) do
    result = download_from_central(artifact_id)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:sync_all, _from, state) do
    Logger.info("Syncing all templates from central...")

    case NATS.request("central.template.sync", %{instance_id: get_instance_id()}) do
      {:ok, %{"templates" => templates}} ->
        count = Enum.reduce(templates, 0, fn template, acc ->
          case save_to_cache(template) do
            {:ok, _} -> acc + 1
            {:error, _} -> acc
          end
        end)

        Logger.info("Synced #{count} templates from central")
        {:reply, {:ok, count}, %{state | last_sync: DateTime.utc_now()}}

      {:error, reason} ->
        Logger.error("Failed to sync templates: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:cache_stats, _from, state) do
    stats = Repo.one(from t in TemplateCache,
      select: %{
        total: count(t.id),
        fresh: filter(count(t.id), t.downloaded_at > ago(^@cache_ttl_hours, "hour")),
        stale: filter(count(t.id), t.downloaded_at <= ago(^@cache_ttl_hours, "hour"))
      }
    )

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:track_usage, artifact_id, result}, state) do
    # Update local usage stats
    Repo.query!("""
      UPDATE template_cache
      SET
        local_usage_count = local_usage_count + 1,
        local_success_count = local_success_count + $2,
        local_failure_count = local_failure_count + $3,
        last_used_at = NOW()
      WHERE artifact_id = $1
    """, [artifact_id, (if result.success?, do: 1, else: 0), (if result.success?, do: 0, else: 1)])

    # Check if should contribute learning
    if should_contribute_learning?(artifact_id) do
      contribute_to_central(artifact_id)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:periodic_sync, state) do
    # Sync pending contributions to central
    sync_pending_contributions()

    # Refresh stale templates in background
    refresh_stale_templates()

    # Schedule next sync
    schedule_sync()

    {:noreply, %{state | last_sync: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:central_template_updated, payload}, state) do
    Logger.info("Received template update from central: #{payload["artifact_id"]}")

    # Invalidate local cache for this template
    Repo.delete_all(from t in TemplateCache, where: t.artifact_id == ^payload["artifact_id"])

    {:noreply, state}
  end

  ## Private Functions

  defp get_from_cache(artifact_id) do
    case Repo.get_by(TemplateCache, artifact_id: artifact_id) do
      nil -> {:error, :not_found}
      cached -> {:ok, cached}
    end
  end

  defp cache_fresh?(%{downloaded_at: downloaded_at}) do
    DateTime.diff(DateTime.utc_now(), downloaded_at, :hour) < @cache_ttl_hours
  end

  defp download_from_central(artifact_id) do
    # Request template from central via NATS
    case NATS.request("central.template.get", %{id: artifact_id}, timeout: 5_000) do
      {:ok, template} ->
        save_to_cache(template)
        {:ok, template["content"]}

      {:error, :timeout} ->
        Logger.warn("Central timeout for #{artifact_id}, using stale cache if available")
        use_stale_cache(artifact_id)

      {:error, reason} ->
        Logger.error("Failed to download template #{artifact_id}: #{inspect(reason)}")
        use_stale_cache(artifact_id)
    end
  end

  defp refresh_from_central(artifact_id) do
    case download_from_central(artifact_id) do
      {:ok, _} -> Logger.debug("Refreshed template: #{artifact_id}")
      {:error, _} -> Logger.warn("Failed to refresh template: #{artifact_id}")
    end
  end

  defp save_to_cache(template) do
    attrs = %{
      artifact_id: template["artifact_id"] || template["id"],
      version: template["version"] || "1.0.0",
      content: template["content"] || template,
      downloaded_at: DateTime.utc_now(),
      source: "central"
    }

    Repo.insert(
      TemplateCache.changeset(%TemplateCache{}, attrs),
      on_conflict: {:replace_all_except, [:local_usage_count, :local_success_count, :local_failure_count]},
      conflict_target: [:artifact_id, :version]
    )
  end

  defp use_stale_cache(artifact_id) do
    case Repo.get_by(TemplateCache, artifact_id: artifact_id) do
      nil ->
        Logger.error("No cached template found for #{artifact_id}, even stale")
        {:error, :not_found}

      cached ->
        Logger.warn("Using stale cache for #{artifact_id}")
        {:ok, cached.content}
    end
  end

  defp should_contribute_learning?(artifact_id) do
    case Repo.one(from t in TemplateCache,
      where: t.artifact_id == ^artifact_id,
      select: %{
        usage: t.local_usage_count,
        success_rate: fragment("?::float / NULLIF(?, 0)", t.local_success_count, t.local_usage_count)
      }
    ) do
      %{usage: usage, success_rate: rate} when usage >= @min_usage_for_contribution and rate >= @min_confidence ->
        # Check if already contributed recently
        not Repo.exists?(from l in LocalLearning,
          where: l.artifact_id == ^artifact_id,
          where: l.synced_to_central == true,
          where: l.synced_at > ago(7, "day")
        )

      _ ->
        false
    end
  end

  defp contribute_to_central(artifact_id) do
    Logger.info("Contributing learning for #{artifact_id} to central")

    # Get local stats
    stats = Repo.one!(from t in TemplateCache,
      where: t.artifact_id == ^artifact_id,
      select: %{
        usage_count: t.local_usage_count,
        success_count: t.local_success_count,
        failure_count: t.local_failure_count,
        success_rate: fragment("?::float / NULLIF(?, 0)", t.local_success_count, t.local_usage_count)
      }
    )

    # TODO: AI analyzes usage and generates improvements
    # For now, just send raw stats
    improvements = %{
      confidence: stats.success_rate,
      usage_count: stats.usage_count
    }

    # Save to local_learning table
    learning = Repo.insert!(%LocalLearning{
      artifact_id: artifact_id,
      version: "current",
      usage_data: stats,
      learned_improvements: improvements
    })

    # Try to sync to central immediately
    sync_learning_to_central(learning)
  end

  defp sync_learning_to_central(learning) do
    payload = %{
      artifact_id: learning.artifact_id,
      instance_id: get_instance_id(),
      usage_data: learning.usage_data,
      improvements: learning.learned_improvements
    }

    case NATS.publish("central.learning.contribute", payload) do
      :ok ->
        Repo.update!(Ecto.Changeset.change(learning, %{
          synced_to_central: true,
          synced_at: DateTime.utc_now()
        }))
        Logger.info("Synced learning for #{learning.artifact_id} to central")

      {:error, reason} ->
        Logger.warn("Failed to sync learning to central: #{inspect(reason)}")
        # Will retry in periodic sync
    end
  end

  defp sync_pending_contributions do
    pending = Repo.all(from l in LocalLearning,
      where: l.synced_to_central == false
    )

    Enum.each(pending, &sync_learning_to_central/1)
  end

  defp refresh_stale_templates do
    stale = Repo.all(from t in TemplateCache,
      where: t.downloaded_at <= ago(^@cache_ttl_hours, "hour"),
      select: t.artifact_id,
      limit: 10
    )

    Enum.each(stale, fn artifact_id ->
      Task.start(fn -> refresh_from_central(artifact_id) end)
    end)
  end

  defp subscribe_to_central_updates do
    # Subscribe to template updates from central
    NATS.subscribe("central.template.updated", fn msg ->
      send(__MODULE__, {:central_template_updated, msg.payload})
    end)
  end

  defp schedule_sync do
    Process.send_after(self(), :periodic_sync, :timer.minutes(@sync_interval_minutes))
  end

  defp get_instance_id do
    # Unique ID for this Singularity instance
    System.get_env("SINGULARITY_INSTANCE_ID") || Node.self() |> to_string()
  end
end
