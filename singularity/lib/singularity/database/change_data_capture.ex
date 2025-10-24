defmodule Singularity.Database.ChangeDataCapture do
  @moduledoc """
  Change Data Capture (CDC) via PostgreSQL wal2json extension.

  Streams database changes (learned patterns, agent sessions, metrics) to CentralCloud
  using PostgreSQL logical decoding with JSON-formatted WAL (Write-Ahead Log) events.

  ## Features

  - Real-time change streaming without polling
  - JSON-formatted change events (INSERT/UPDATE/DELETE)
  - Logical replication slots for reliable delivery
  - Low overhead (logical decoding operates at WAL level)

  ## Architecture

  ```
  Singularity Write
      ↓
  PostgreSQL WAL (Write-Ahead Log)
      ↓
  wal2json Logical Decoder
      ↓
  Logical Replication Slot (singularity_centralcloud_cdc)
      ↓
  CDC Consumer (get_changes/0)
      ↓
  CentralCloud via NATS
  ```

  ## Queues

  Changes flow through pgmq queues:
  - `cdc-learned-patterns` - New/updated patterns
  - `cdc-agent-sessions` - Session changes
  - `cdc-metrics-events` - Metric records

  ## Usage

  ```elixir
  # Get all pending changes from WAL
  {:ok, changes} = ChangeDataCapture.get_changes()

  # Get only pattern changes
  pattern_changes = Enum.filter(changes, &(&1.table == "learned_patterns"))

  # Get since last LSN (Log Sequence Number)
  {:ok, changes} = ChangeDataCapture.get_changes_since("0/0")

  # Confirm changes processed (advance slot)
  :ok = ChangeDataCapture.confirm_processed(last_lsn)
  ```
  """

  require Logger
  alias CentralCloud.Repo

  @slot_name "singularity_centralcloud_cdc"
  @plugin "wal2json"

  @doc """
  Initialize logical replication slot for CDC (run once at startup).

  Creates slot if it doesn't exist. Safe to call multiple times.
  """
  def init_slot do
    case Repo.query(
      "SELECT slot_name FROM pg_replication_slots WHERE slot_name = $1",
      [@slot_name]
    ) do
      {:ok, %{rows: []}} ->
        # Slot doesn't exist, create it
        case Repo.query(
          "SELECT * FROM pg_create_logical_replication_slot($1, $2)",
          [@slot_name, @plugin]
        ) do
          {:ok, _} ->
            Logger.info("Created CDC slot: #{@slot_name}")
            {:ok, :created}

          error ->
            Logger.error("Failed to create CDC slot: #{inspect(error)}")
            error
        end

      {:ok, %{rows: [[_]]}} ->
        Logger.info("CDC slot already exists: #{@slot_name}")
        {:ok, :exists}

      error ->
        error
    end
  end

  @doc """
  Get all pending changes from logical replication slot.

  Returns list of change events with table name, operation, and data.
  Changes remain in WAL until confirmed with confirm_processed/1.
  """
  def get_changes do
    case Repo.query(
      "SELECT lsn, data FROM pg_logical_slot_peek_changes($1, NULL, NULL)",
      [@slot_name]
    ) do
      {:ok, %{rows: rows}} ->
        changes =
          Enum.map(rows, fn [lsn, json_data] ->
            case Jason.decode(json_data) do
              {:ok, data} -> parse_wal_event(lsn, data)
              {:error, _} -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, changes}

      error ->
        error
    end
  end

  @doc """
  Get changes since a specific LSN (Log Sequence Number).

  Useful for resuming after crashes without reprocessing.
  """
  def get_changes_since(since_lsn) when is_binary(since_lsn) do
    case Repo.query(
      "SELECT lsn, data FROM pg_logical_slot_peek_changes($1, $2, NULL)",
      [@slot_name, since_lsn]
    ) do
      {:ok, %{rows: rows}} ->
        changes =
          Enum.map(rows, fn [lsn, json_data] ->
            case Jason.decode(json_data) do
              {:ok, data} -> parse_wal_event(lsn, data)
              {:error, _} -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        {:ok, changes}

      error ->
        error
    end
  end

  @doc """
  Confirm changes were processed (advance replication slot).

  After processing changes, call this with the LSN of the last change
  to advance the slot and free WAL storage.

  Slot remembers position and won't replay confirmed changes on restart.
  """
  def confirm_processed(lsn) when is_binary(lsn) do
    case Repo.query(
      "SELECT pg_logical_slot_get_changes($1, NULL, NULL)",
      [@slot_name]
    ) do
      {:ok, _} ->
        Logger.debug("CDC changes confirmed up to LSN: #{lsn}")
        :ok

      error ->
        error
    end
  end

  @doc """
  Get CDC slot status (lag, memory usage, etc).
  """
  def slot_status do
    case Repo.query("""
      SELECT
        slot_name,
        slot_type,
        active,
        COALESCE(flush_lsn::text, 'N/A') as flush_lsn,
        (pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) / 1024 / 1024)::bigint as lag_mb,
        pg_size_pretty(pg_total_relation_size('pg_replslot')) as slot_size
      FROM pg_replication_slots
      WHERE slot_name = $1
    """, [@slot_name]) do
      {:ok, %{rows: [[name, type, active, flush_lsn, lag_mb, slot_size]]}} ->
        {:ok, %{
          name: name,
          type: type,
          active: active,
          flush_lsn: flush_lsn,
          lag_mb: lag_mb,
          slot_size: slot_size
        }}

      {:ok, %{rows: []}} ->
        {:error, "CDC slot not found"}

      error ->
        error
    end
  end

  @doc """
  Drop CDC slot (clean shutdown).

  Call before decommissioning to free WAL storage.
  """
  def drop_slot do
    case Repo.query(
      "SELECT pg_drop_replication_slot($1)",
      [@slot_name]
    ) do
      {:ok, _} ->
        Logger.info("Dropped CDC slot: #{@slot_name}")
        {:ok, :dropped}

      error ->
        error
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp parse_wal_event(lsn, %{"change" => changes} = data) when is_list(changes) do
    # wal2json emits "change" array with one entry per affected row
    case List.first(changes) do
      %{"kind" => kind, "schema" => schema, "table" => table, "columnnames" => cols, "columnvalues" => values} = change ->
        %{
          lsn: lsn,
          kind: kind,
          schema: schema,
          table: table,
          columns: cols,
          values: values,
          before_values: Map.get(change, "columnvalues_before"),
          identity: Map.get(change, "identity"),
          timestamp: data["timestamp"]
        }

      _ ->
        nil
    end
  end

  defp parse_wal_event(_lsn, _data), do: nil
end
