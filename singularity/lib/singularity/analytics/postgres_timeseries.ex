defmodule Singularity.Analytics.PostgresTimeseries do
  @moduledoc """
  PostgreSQL Native Time-Series Analytics - High-performance time-series operations using TimescaleDB

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.Analytics.PostgresTimeseries",
    "purpose": "Native PostgreSQL time-series analytics using TimescaleDB extension",
    "type": "Analytics service (TimescaleDB-native)",
    "operates_on": "performance_metrics, llm_call_metrics, system_metrics tables",
    "storage": "PostgreSQL with TimescaleDB extension",
    "dependencies": ["Repo", "TimescaleDB extension"]
  }
  ```

  ## Architecture (Mermaid)

  ```mermaid
  graph TD
      A[PostgresTimeseries] -->|SQL functions| B[TimescaleDB]
      B -->|Continuous aggregates| C[(Hypertables)]
      A -->|Fallback| D[Analytics]
      D -->|Elixir processing| E[Manual aggregation]
  ```

  ## Call Graph (YAML)

  ```yaml
  PostgresTimeseries:
    calls:
      - Repo.query/1  # Execute time-series functions
    called_by:
      - Analytics  # When time-series analysis is needed
      - Monitoring  # For system health checks
      - Performance  # For performance analysis
    alternative:
      - Analytics  # Fallback to Elixir-based analytics
  ```

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `TimeseriesAnalytics` - This IS the time-series analytics module
  - ❌ `TimescaleAnalytics` - Redundant naming
  - ❌ `PerformanceAnalytics` - This handles all time-series types

  **Use this module when:**
  - ✅ Need high-performance time-series analysis
  - ✅ Want real-time aggregations
  - ✅ Need forecasting and anomaly detection

  **Use Analytics when:**
  - ✅ Simple aggregations without time-series features
  - ✅ One-time analysis without continuous monitoring

  ## Search Keywords

  timescaledb, time-series, continuous-aggregates, hypertables, forecasting,
  anomaly-detection, performance-metrics, real-time-analytics, postgresql-timeseries
  """

  alias Singularity.Repo

  @doc """
  Get performance trends for a specific metric.

  ## Examples

      iex> PostgresTimeseries.get_performance_trends("cpu_usage", "24 hours", "1 hour")
      {:ok, [
        %{bucket: ~U[2025-01-14 10:00:00Z], avg_value: 45.2, trend_direction: "stable"},
        %{bucket: ~U[2025-01-14 11:00:00Z], avg_value: 52.1, trend_direction: "increasing"}
      ]}

      iex> PostgresTimeseries.get_performance_trends("memory_usage", "7 days", "1 day")
      {:ok, [...]}
  """
  def get_performance_trends(metric_name, time_range \\ "24 hours", bucket_size \\ "1 hour") do
    query_sql = """
    SELECT * FROM get_performance_trends($1, $2, $3)
    ORDER BY bucket
    """

    case Repo.query(query_sql, [metric_name, time_range, bucket_size]) do
      {:ok, result} ->
        trends =
          Enum.map(result.rows, fn row ->
            [bucket, avg_value, min_value, max_value, sample_count, trend_direction] = row

            %{
              bucket: bucket,
              avg_value: avg_value,
              min_value: min_value,
              max_value: max_value,
              sample_count: sample_count,
              trend_direction: trend_direction
            }
          end)

        {:ok, trends}

      {:error, reason} ->
        {:error, "Performance trends failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Detect performance anomalies using statistical analysis.

  ## Examples

      iex> PostgresTimeseries.detect_anomalies("cpu_usage", "24 hours", 2.0)
      {:ok, [
        %{anomaly_time: ~U[2025-01-14 14:30:00Z], value: 95.2, severity: "critical"},
        %{anomaly_time: ~U[2025-01-14 15:15:00Z], value: 88.7, severity: "high"}
      ]}
  """
  def detect_anomalies(metric_name, time_range \\ "24 hours", threshold_multiplier \\ 2.0) do
    query_sql = """
    SELECT * FROM detect_performance_anomalies($1, $2, $3)
    ORDER BY deviation DESC
    """

    case Repo.query(query_sql, [metric_name, time_range, threshold_multiplier]) do
      {:ok, result} ->
        anomalies =
          Enum.map(result.rows, fn row ->
            [anomaly_time, value, expected_value, deviation, severity] = row

            %{
              anomaly_time: anomaly_time,
              value: value,
              expected_value: expected_value,
              deviation: deviation,
              severity: severity
            }
          end)

        {:ok, anomalies}

      {:error, reason} ->
        {:error, "Anomaly detection failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Get LLM cost analysis and usage statistics.

  ## Examples

      iex> PostgresTimeseries.get_llm_cost_analysis("7 days")
      {:ok, [
        %{provider: "claude", model: "claude-3-opus", total_cost: 12.45, success_rate: 98.5},
        %{provider: "openai", model: "gpt-4", total_cost: 8.23, success_rate: 96.2}
      ]}
  """
  def get_llm_cost_analysis(time_range \\ "7 days") do
    query_sql = """
    SELECT * FROM get_llm_cost_analysis($1)
    """

    case Repo.query(query_sql, [time_range]) do
      {:ok, result} ->
        analysis =
          Enum.map(result.rows, fn row ->
            [
              provider,
              model,
              total_tokens,
              total_cost,
              avg_cost_per_token,
              call_count,
              success_rate,
              avg_response_time
            ] = row

            %{
              provider: provider,
              model: model,
              total_tokens: total_tokens,
              total_cost: total_cost,
              avg_cost_per_token: avg_cost_per_token,
              call_count: call_count,
              success_rate: success_rate,
              avg_response_time: avg_response_time
            }
          end)

        {:ok, analysis}

      {:error, reason} ->
        {:error, "LLM cost analysis failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Get system health summary with recommendations.

  ## Examples

      iex> PostgresTimeseries.get_system_health_summary("1 hour")
      {:ok, [
        %{metric_type: "cpu", current_value: 45.2, health_status: "healthy", recommendation: "System operating normally"},
        %{metric_type: "memory", current_value: 7500.0, health_status: "warning", recommendation: "Consider increasing memory"}
      ]}
  """
  def get_system_health_summary(time_range \\ "1 hour") do
    query_sql = """
    SELECT * FROM get_system_health_summary($1)
    """

    case Repo.query(query_sql, [time_range]) do
      {:ok, result} ->
        health =
          Enum.map(result.rows, fn row ->
            [metric_type, current_value, avg_value, max_value, health_status, recommendation] =
              row

            %{
              metric_type: metric_type,
              current_value: current_value,
              avg_value: avg_value,
              max_value: max_value,
              health_status: health_status,
              recommendation: recommendation
            }
          end)

        {:ok, health}

      {:error, reason} ->
        {:error, "System health summary failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Forecast metric trends using statistical analysis.

  ## Examples

      iex> PostgresTimeseries.forecast_trend("cpu_usage", 24)
      {:ok, [
        %{forecast_time: ~U[2025-01-15 00:00:00Z], predicted_value: 45.2, confidence_interval_lower: 35.1, confidence_interval_upper: 55.3},
        %{forecast_time: ~U[2025-01-15 01:00:00Z], predicted_value: 47.8, confidence_interval_lower: 37.7, confidence_interval_upper: 57.9}
      ]}
  """
  def forecast_trend(metric_name, forecast_hours \\ 24) do
    query_sql = """
    SELECT * FROM forecast_metric_trend($1, $2)
    ORDER BY forecast_time
    """

    case Repo.query(query_sql, [metric_name, forecast_hours]) do
      {:ok, result} ->
        forecast =
          Enum.map(result.rows, fn row ->
            [forecast_time, predicted_value, confidence_interval_lower, confidence_interval_upper] =
              row

            %{
              forecast_time: forecast_time,
              predicted_value: predicted_value,
              confidence_interval_lower: confidence_interval_lower,
              confidence_interval_upper: confidence_interval_upper
            }
          end)

        {:ok, forecast}

      {:error, reason} ->
        {:error, "Trend forecasting failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Get real-time metrics from continuous aggregates.

  ## Examples

      iex> PostgresTimeseries.get_realtime_metrics("performance_metrics_1min", "cpu_usage")
      {:ok, [
        %{bucket: ~U[2025-01-14 14:00:00Z], avg_value: 45.2, sample_count: 60},
        %{bucket: ~U[2025-01-14 14:01:00Z], avg_value: 47.8, sample_count: 60}
      ]}
  """
  def get_realtime_metrics(aggregate_view, metric_name \\ nil, limit \\ 100) do
    where_clause = if metric_name, do: "WHERE metric_name = $2", else: ""
    order_clause = "ORDER BY bucket DESC LIMIT $#{if metric_name, do: "3", else: "2"}"

    query_sql = """
    SELECT bucket, avg_value, sample_count
    FROM #{aggregate_view}
    #{where_clause}
    #{order_clause}
    """

    params = if metric_name, do: [metric_name, limit], else: [limit]

    case Repo.query(query_sql, params) do
      {:ok, result} ->
        metrics =
          Enum.map(result.rows, fn row ->
            [bucket, avg_value, sample_count] = row

            %{
              bucket: bucket,
              avg_value: avg_value,
              sample_count: sample_count
            }
          end)

        {:ok, metrics}

      {:error, reason} ->
        {:error, "Real-time metrics failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Get performance comparison between time periods.

  ## Examples

      iex> PostgresTimeseries.compare_periods("cpu_usage", "1 hour", "24 hours")
      {:ok, %{
        current_period: %{avg: 45.2, max: 67.8, min: 23.1},
        previous_period: %{avg: 42.1, max: 65.2, min: 21.5},
        change_percent: 7.4
      }}
  """
  def compare_periods(metric_name, current_period, previous_period) do
    query_sql = """
    WITH current_stats AS (
      SELECT 
        avg(value) as avg_value,
        max(value) as max_value,
        min(value) as min_value
      FROM performance_metrics
      WHERE metric_name = $1
        AND created_at > NOW() - $2::INTERVAL
    ),
    previous_stats AS (
      SELECT 
        avg(value) as avg_value,
        max(value) as max_value,
        min(value) as min_value
      FROM performance_metrics
      WHERE metric_name = $1
        AND created_at BETWEEN NOW() - $3::INTERVAL AND NOW() - $2::INTERVAL
    )
    SELECT 
      c.avg_value as current_avg,
      c.max_value as current_max,
      c.min_value as current_min,
      p.avg_value as previous_avg,
      p.max_value as previous_max,
      p.min_value as previous_min,
      ((c.avg_value - p.avg_value) / p.avg_value * 100) as change_percent
    FROM current_stats c
    CROSS JOIN previous_stats p
    """

    case Repo.query(query_sql, [metric_name, current_period, previous_period]) do
      {:ok, result} ->
        case result.rows do
          [
            [
              current_avg,
              current_max,
              current_min,
              previous_avg,
              previous_max,
              previous_min,
              change_percent
            ]
            | _
          ] ->
            {:ok,
             %{
               current_period: %{
                 avg: current_avg,
                 max: current_max,
                 min: current_min
               },
               previous_period: %{
                 avg: previous_avg,
                 max: previous_max,
                 min: previous_min
               },
               change_percent: change_percent
             }}

          [] ->
            {:ok,
             %{
               current_period: %{avg: 0, max: 0, min: 0},
               previous_period: %{avg: 0, max: 0, min: 0},
               change_percent: 0
             }}
        end

      {:error, reason} ->
        {:error, "Period comparison failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Get TimescaleDB performance metrics.

  ## Examples

      iex> PostgresTimeseries.get_performance_metrics()
      {:ok, %{
        hypertable_count: 3,
        continuous_aggregate_count: 5,
        total_chunks: 1247,
        compression_ratio: 0.23
      }}
  """
  def get_performance_metrics do
    query_sql = """
    SELECT 
      (SELECT count(*) FROM timescaledb_information.hypertables WHERE hypertable_schema = 'public') as hypertable_count,
      (SELECT count(*) FROM timescaledb_information.continuous_aggregates WHERE view_schema = 'public') as continuous_aggregate_count,
      (SELECT count(*) FROM timescaledb_information.chunks WHERE chunk_schema = 'public') as total_chunks,
      (SELECT round(avg(compression_ratio), 2) FROM timescaledb_information.compression_stats WHERE hypertable_schema = 'public') as compression_ratio
    """

    case Repo.query(query_sql) do
      {:ok, result} ->
        case result.rows do
          [[hypertable_count, continuous_aggregate_count, total_chunks, compression_ratio] | _] ->
            {:ok,
             %{
               hypertable_count: hypertable_count,
               continuous_aggregate_count: continuous_aggregate_count,
               total_chunks: total_chunks,
               compression_ratio: compression_ratio
             }}

          [] ->
            {:ok,
             %{
               hypertable_count: 0,
               continuous_aggregate_count: 0,
               total_chunks: 0,
               compression_ratio: 0.0
             }}
        end

      {:error, reason} ->
        {:error, "Performance metrics failed: #{inspect(reason)}"}
    end
  end
end
