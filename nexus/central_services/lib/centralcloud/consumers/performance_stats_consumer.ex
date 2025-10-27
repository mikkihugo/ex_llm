defmodule CentralCloud.Consumers.PerformanceStatsConsumer do
  @moduledoc """
  Consumes performance and execution statistics from Genesis and Singularity.

  Reads from:
  - pgmq: execution_statistics_per_job
  - pgmq: execution_metrics_aggregated

  Stores metrics in local database for analytics, trending, and cross-instance learning.

  ## Message Format

  Per-Job Statistics:
  ```json
  {
    "type": "execution_statistics",
    "job_id": "uuid",
    "language": "elixir",
    "status": "success",
    "execution_time_ms": 1234,
    "memory_used_mb": 45.6,
    "lines_analyzed": 520,
    "timestamp": "2025-01-10T..."
  }
  ```

  Aggregated Metrics:
  ```json
  {
    "type": "execution_metrics",
    "jobs_completed": 156,
    "jobs_failed": 3,
    "success_rate": 0.98,
    "avg_execution_time_ms": 892,
    "total_memory_used_mb": 2450,
    "timestamp": "2025-01-10T..."
  }
  ```
  """

  require Logger

  @doc """
  Handle incoming performance statistics message.

  Returns :ok on success, {:error, reason} on failure.
  """
  def handle_message(%{"type" => "execution_statistics", "job_id" => job_id} = msg) do
    Logger.info("[PerformanceStats] Received job stats for #{job_id}",
      language: msg["language"],
      status: msg["status"],
      execution_time_ms: msg["execution_time_ms"]
    )

    case store_job_statistics(msg) do
      :ok ->
        Logger.debug("[PerformanceStats] Stored job statistics for #{job_id}")
        :ok

      {:error, reason} ->
        Logger.error("[PerformanceStats] Failed to store job statistics: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_message(%{"type" => "execution_metrics"} = msg) do
    Logger.info("[PerformanceStats] Received aggregated metrics",
      jobs_completed: msg["jobs_completed"],
      success_rate: msg["success_rate"],
      avg_execution_time_ms: msg["avg_execution_time_ms"]
    )

    case store_aggregated_metrics(msg) do
      :ok ->
        Logger.debug("[PerformanceStats] Stored aggregated metrics")
        :ok

      {:error, reason} ->
        Logger.error("[PerformanceStats] Failed to store aggregated metrics: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def handle_message(msg) do
    Logger.warning("[PerformanceStats] Unknown message type: #{inspect(msg)}")
    {:error, :unknown_message_type}
  end

  # ===========================
  # Private Functions
  # ===========================

  defp store_job_statistics(%{
         "job_id" => job_id,
         "language" => language,
         "status" => status,
         "execution_time_ms" => execution_time_ms
       } = msg) do
    try do
      Logger.debug("[PerformanceStats] Storing job statistics",
        job_id: job_id,
        language: language,
        status: status,
        execution_time_ms: execution_time_ms
      )

      memory_used_mb = msg["memory_used_mb"]
      lines_analyzed = msg["lines_analyzed"]
      instance_id = msg["instance_id"]

      case CentralCloud.Repo.query("""
        INSERT INTO job_statistics (
          id, job_id, language, status, execution_time_ms,
          memory_used_mb, lines_analyzed, instance_id, recorded_at,
          inserted_at, updated_at
        ) VALUES (
          uuid_generate_v7(), $1, $2, $3, $4, $5, $6, $7, NOW(),
          NOW(), NOW()
        )
        """, [job_id, language, status, execution_time_ms, memory_used_mb, lines_analyzed, instance_id]) do
        {:ok, _} ->
          Logger.debug("[PerformanceStats] ✓ Stored job statistics #{job_id}")
          :ok

        {:error, reason} ->
          Logger.error("[PerformanceStats] ✗ Failed to store job statistics: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error storing job statistics: #{inspect(e)}")
        {:error, e}
    end
  end

  defp store_job_statistics(_msg), do: {:error, :invalid_format}

  defp store_aggregated_metrics(%{
         "jobs_completed" => jobs_completed,
         "success_rate" => success_rate,
         "avg_execution_time_ms" => avg_execution_time_ms
       } = msg) do
    try do
      Logger.debug("[PerformanceStats] Storing aggregated metrics",
        jobs_completed: jobs_completed,
        success_rate: success_rate,
        avg_execution_time_ms: avg_execution_time_ms
      )

      jobs_failed = msg["jobs_failed"] || 0
      total_memory_used_mb = msg["total_memory_used_mb"]
      instance_id = msg["instance_id"]
      timestamp = msg["timestamp"] || DateTime.utc_now() |> DateTime.to_iso8601()

      case CentralCloud.Repo.query("""
        INSERT INTO execution_metrics (
          id, period_start, period_end, jobs_completed, jobs_failed,
          success_rate, avg_execution_time_ms, total_memory_used_mb,
          instance_id, inserted_at, updated_at
        ) VALUES (
          uuid_generate_v7(), $1::utc_datetime_usec, NOW(), $2, $3,
          $4, $5, $6, $7, NOW(), NOW()
        )
        """, [timestamp, jobs_completed, jobs_failed, success_rate, avg_execution_time_ms, total_memory_used_mb, instance_id]) do
        {:ok, _} ->
          Logger.debug("[PerformanceStats] ✓ Stored aggregated metrics",
            success_rate: success_rate,
            jobs_completed: jobs_completed
          )
          :ok

        {:error, reason} ->
          Logger.error("[PerformanceStats] ✗ Failed to store aggregated metrics: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.error("Error storing aggregated metrics: #{inspect(e)}")
        {:error, e}
    end
  end

  defp store_aggregated_metrics(_msg), do: {:error, :invalid_format}
end
