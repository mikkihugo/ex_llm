defmodule CentralCloud.Replication.InstanceRegistry do
  @moduledoc """
  Registry for managing Singularity instance replication targets.

  Maintains the list of Singularity instances that should receive
  approved patterns and metrics from CentralCloud via pg_net HTTP push.

  ## Architecture

  CentralCloud (pg_net triggers)
         ↓ HTTP POST (via pg_cron worker every 5s)
  Singularity Instance HTTP Endpoint
         ↓
  Singularity Repo (upsert approved_patterns)

  ## Usage

  Register instance:
      CentralCloud.Replication.InstanceRegistry.register_instance(%{
        instance_name: "singularity-prod-1",
        instance_id: "uuid",
        http_endpoint: "http://localhost:4000/sync/patterns"
      })

  Deregister instance:
      CentralCloud.Replication.InstanceRegistry.deregister_instance("uuid")

  List active instances:
      CentralCloud.Replication.InstanceRegistry.list_active_instances()
  """

  require Logger
  alias CentralCloud.Repo

  @doc """
  Register a new Singularity instance for replication.

  The instance will immediately start receiving approved patterns
  and metrics via pg_net HTTP push.
  """
  def register_instance(attrs) do
    instance_id = attrs.instance_id || Ecto.UUID.generate()

    case Repo.query("""
      INSERT INTO replication_instances (
        id, instance_name, instance_id, http_endpoint, is_active,
        inserted_at, updated_at
      ) VALUES (
        uuid_generate_v7(), $1, $2, $3, true, NOW(), NOW()
      )
      ON CONFLICT (instance_id) DO UPDATE SET
        http_endpoint = $3,
        is_active = true,
        updated_at = NOW()
      RETURNING id, instance_id, instance_name, http_endpoint
      """, [attrs.instance_name, instance_id, attrs.http_endpoint]) do
      {:ok, %{rows: [row]}} ->
        Logger.info("[Replication] ✓ Registered instance",
          instance_name: attrs.instance_name,
          instance_id: instance_id,
          endpoint: attrs.http_endpoint
        )

        {:ok, format_instance_row(row)}

      {:error, reason} ->
        Logger.error("[Replication] ✗ Failed to register instance: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[Replication] Exception registering instance: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Deregister a Singularity instance (stop sending replications).

  Does not delete the instance record, just marks as inactive.
  """
  def deregister_instance(instance_id) do
    case Repo.query("""
      UPDATE replication_instances
      SET is_active = false, updated_at = NOW()
      WHERE instance_id = $1
      RETURNING id, instance_id, instance_name
      """, [instance_id]) do
      {:ok, %{rows: [row]}} ->
        Logger.info("[Replication] ✓ Deregistered instance",
          instance_id: instance_id
        )

        {:ok, format_instance_row(row)}

      {:error, reason} ->
        Logger.error("[Replication] ✗ Failed to deregister instance: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[Replication] Exception deregistering instance: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  List all active replication instances.
  """
  def list_active_instances do
    case Repo.query("""
      SELECT id, instance_id, instance_name, http_endpoint, is_active,
             last_sync_at, error_count, success_count
      FROM replication_instances
      WHERE is_active = true
      ORDER BY instance_name ASC
      """, []) do
      {:ok, %{rows: rows}} ->
        instances = Enum.map(rows, &format_instance_row/1)
        {:ok, instances}

      {:error, reason} ->
        Logger.error("[Replication] Failed to list instances: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[Replication] Exception listing instances: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Get replication status for an instance.
  """
  def get_instance_status(instance_id) do
    case Repo.query("""
      SELECT id, instance_id, instance_name, http_endpoint, is_active,
             last_sync_at, last_error, error_count, success_count
      FROM replication_instances
      WHERE instance_id = $1
      """, [instance_id]) do
      {:ok, %{rows: [row]}} ->
        status = format_instance_row(row)
        {:ok, status}

      {:ok, %{rows: []}} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("[Replication] Failed to get instance status: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[Replication] Exception getting instance status: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Get replication queue stats.
  """
  def get_queue_stats do
    case Repo.query("""
      SELECT
        COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
        COUNT(*) FILTER (WHERE status = 'success') as success_count,
        COUNT(*) FILTER (WHERE status = 'failed') as failed_count,
        COUNT(*) as total_count,
        MAX(inserted_at) as last_event_at
      FROM replication_queue
      """, []) do
      {:ok, %{rows: [[pending, success, failed, total, last_at]]}} ->
        {:ok, %{
          pending: pending,
          success: success,
          failed: failed,
          total: total,
          last_event_at: last_at
        }}

      {:error, reason} ->
        Logger.error("[Replication] Failed to get queue stats: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[Replication] Exception getting queue stats: #{inspect(e)}")
      {:error, e}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp format_instance_row(row) do
    case row do
      [id, instance_id, instance_name, http_endpoint, is_active, last_sync_at, error_count, success_count] ->
        %{
          "id" => id,
          "instance_id" => instance_id,
          "instance_name" => instance_name,
          "http_endpoint" => http_endpoint,
          "is_active" => is_active,
          "last_sync_at" => last_sync_at,
          "error_count" => error_count,
          "success_count" => success_count
        }

      [id, instance_id, instance_name, http_endpoint, is_active, last_sync_at, last_error, error_count, success_count] ->
        %{
          "id" => id,
          "instance_id" => instance_id,
          "instance_name" => instance_name,
          "http_endpoint" => http_endpoint,
          "is_active" => is_active,
          "last_sync_at" => last_sync_at,
          "last_error" => last_error,
          "error_count" => error_count,
          "success_count" => success_count
        }

      _ ->
        row
    end
  end
end
