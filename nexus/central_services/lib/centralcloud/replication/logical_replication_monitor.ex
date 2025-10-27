defmodule CentralCloud.Replication.LogicalReplicationMonitor do
  @moduledoc """
  Monitor PostgreSQL Logical Replication status.

  Queries PostgreSQL catalog views to get real-time replication stats:
  - pg_publication - Publications we're serving
  - pg_replication_slots - Replication slots (one per subscriber)
  - pg_stat_replication - Active replication connections

  No custom tables needed - uses PostgreSQL's built-in monitoring.

  ## Architecture

  CentralCloud → PUBLICATIONS
      ↓
  Singularity/Genesis SUBSCRIPTIONS (auto-sync + streaming)
      ↓
  PostgreSQL Logical Replication Slots
      ↓
  pg_stat_replication (shows active connections)
  pg_replication_slots (shows slot status + LSN)
  """

  require Logger
  alias CentralCloud.Repo

  @doc """
  Get list of all publications on CentralCloud.
  """
  def list_publications do
    case Repo.query("""
      SELECT
        pubname as name,
        pubinsert,
        pubupdate,
        pubdelete,
        pubtruncate,
        pubviaroot
      FROM pg_publication
      ORDER BY pubname
      """, []) do
      {:ok, %{rows: rows}} ->
        publications = Enum.map(rows, &format_publication_row/1)
        {:ok, publications}

      {:error, reason} ->
        Logger.error("[LogicalRepMonitor] Failed to list publications: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[LogicalRepMonitor] Exception listing publications: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Get replication slots (one per subscriber).

  Shows which Singularity/Genesis instances are subscribed.
  """
  def list_replication_slots do
    case Repo.query("""
      SELECT
        slot_name,
        slot_type,
        datname as database,
        plugin,
        slot_xmin,
        restart_lsn,
        confirmed_flush_lsn,
        active,
        active_pid
      FROM pg_replication_slots
      ORDER BY slot_name
      """, []) do
      {:ok, %{rows: rows}} ->
        slots = Enum.map(rows, &format_slot_row/1)
        {:ok, slots}

      {:error, reason} ->
        Logger.error("[LogicalRepMonitor] Failed to list slots: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[LogicalRepMonitor] Exception listing slots: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Get active replication connections.

  Shows which Singularity/Genesis instances are currently connected and syncing.
  """
  def list_active_replications do
    case Repo.query("""
      SELECT
        pid,
        usename as user,
        application_name,
        client_addr,
        backend_start,
        backend_xmin,
        state,
        write_lsn,
        flush_lsn,
        replay_lsn,
        write_lag,
        flush_lag,
        replay_lag,
        sync_state
      FROM pg_stat_replication
      ORDER BY application_name
      """, []) do
      {:ok, %{rows: rows}} ->
        replications = Enum.map(rows, &format_replication_row/1)
        {:ok, replications}

      {:error, reason} ->
        Logger.error("[LogicalRepMonitor] Failed to list replications: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[LogicalRepMonitor] Exception listing replications: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Get overall replication health summary.
  """
  def get_replication_health do
    try do
      {:ok, publications} = list_publications()
      {:ok, slots} = list_replication_slots()
      {:ok, replications} = list_active_replications()

      active_count = Enum.count(replications)
      inactive_slots = Enum.filter(slots, fn slot -> !slot["active"] end)

      health = %{
        "publications_count" => length(publications),
        "subscriptions_total" => length(slots),
        "subscriptions_active" => active_count,
        "subscriptions_inactive" => length(inactive_slots),
        "replication_lag" => calculate_max_lag(replications),
        "status" => if(active_count > 0, do: "healthy", else: "warning"),
        "timestamp" => DateTime.utc_now()
      }

      {:ok, health}
    rescue
      e ->
        Logger.error("[LogicalRepMonitor] Exception getting health: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Get replication lag for a specific subscriber.

  Returns how far behind the subscriber is (in bytes or messages).
  Lower is better (0 = caught up).
  """
  def get_subscriber_lag(subscriber_name) do
    case Repo.query("""
      SELECT
        application_name,
        replay_lsn,
        flush_lsn,
        write_lsn,
        replay_lag
      FROM pg_stat_replication
      WHERE application_name = $1
      """, [subscriber_name]) do
      {:ok, %{rows: [row]}} ->
        [app_name, replay_lsn, flush_lsn, write_lsn, replay_lag] = row

        {:ok, %{
          "subscriber_name" => app_name,
          "replay_lsn" => replay_lsn,
          "flush_lsn" => flush_lsn,
          "write_lsn" => write_lsn,
          "replay_lag" => replay_lag,
          "is_caught_up" => replay_lag == nil or replay_lag == 0
        }}

      {:ok, %{rows: []}} ->
        {:error, :subscriber_not_connected}

      {:error, reason} ->
        Logger.error("[LogicalRepMonitor] Failed to get lag: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[LogicalRepMonitor] Exception getting lag: #{inspect(e)}")
      {:error, e}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp format_publication_row(row) do
    [name, pubinsert, pubupdate, pubdelete, pubtruncate, pubviaroot] = row

    %{
      "name" => name,
      "publish_insert" => pubinsert,
      "publish_update" => pubupdate,
      "publish_delete" => pubdelete,
      "publish_truncate" => pubtruncate,
      "publish_via_root" => pubviaroot
    }
  end

  defp format_slot_row(row) do
    [slot_name, slot_type, database, plugin, slot_xmin, restart_lsn, confirmed_flush_lsn, active, active_pid] =
      row

    %{
      "slot_name" => slot_name,
      "slot_type" => slot_type,
      "database" => database,
      "plugin" => plugin,
      "slot_xmin" => slot_xmin,
      "restart_lsn" => restart_lsn,
      "confirmed_flush_lsn" => confirmed_flush_lsn,
      "active" => active,
      "active_pid" => active_pid
    }
  end

  defp format_replication_row(row) do
    [pid, user, app_name, client_addr, backend_start, backend_xmin, state, write_lsn, flush_lsn, replay_lsn, write_lag, flush_lag, replay_lag, sync_state] =
      row

    %{
      "pid" => pid,
      "user" => user,
      "application_name" => app_name,
      "client_address" => client_addr,
      "backend_start" => backend_start,
      "backend_xmin" => backend_xmin,
      "state" => state,
      "write_lsn" => write_lsn,
      "flush_lsn" => flush_lsn,
      "replay_lsn" => replay_lsn,
      "write_lag" => write_lag,
      "flush_lag" => flush_lag,
      "replay_lag" => replay_lag,
      "sync_state" => sync_state
    }
  end

  defp calculate_max_lag(replications) do
    replications
    |> Enum.map(fn rep -> rep["replay_lag"] end)
    |> Enum.filter(&is_number/1)
    |> case do
      [] -> 0
      lags -> Enum.max(lags)
    end
  end
end
