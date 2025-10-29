defmodule Observer.Dashboard.SASLTrace do
  @moduledoc """
  SASL trace dashboard data fetcher.
  
  Reads SASL logs and provides trace data for the Observer web UI.
  Supports multiple log files from different applications.
  """
  
  require Logger
  
  # Multiple SASL log paths (one per app)
  @sasl_log_paths [
    "log/sasl-error.log",  # Observer app
    "../nexus/singularity/log/sasl-error.log",  # Singularity app
    "../nexus/genesis/log/sasl-error.log",  # Genesis app
    "../nexus/central_services/log/sasl-error.log",  # CentralCloud app
  ]
  
  def get_traces(limit \\ 100) do
    try do
      traces = 
        @sasl_log_paths
        |> Enum.flat_map(&read_log_file/1)
        |> Enum.sort_by(& &1.timestamp, {:desc, &String.compare/2})
        |> Enum.take(limit)
      
      {:ok, %{
        traces: traces,
        total_count: length(traces),
        log_paths: @sasl_log_paths,
        last_updated: DateTime.utc_now()
      }}
    rescue
      error ->
        Logger.error("Failed to read SASL traces", error: inspect(error))
        {:error, inspect(error)}
    end
  end
  
  defp read_log_file(path) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.map(&parse_log_line(&1, path))
      |> Enum.filter(& &1)
    else
      []
    end
  end
  
  defp parse_log_line(line, source_path) do
    # Parse SASL log format
    # Format varies, but typically includes timestamp and error details
    cond do
      String.contains?(line, "CRASH REPORT") ->
        %{
          type: :crash_report,
          timestamp: extract_timestamp(line),
          content: line,
          severity: :error,
          source: Path.basename(source_path)
        }
      
      String.contains?(line, "SUPERVISOR REPORT") ->
        %{
          type: :supervisor_report,
          timestamp: extract_timestamp(line),
          content: line,
          severity: :warning,
          source: Path.basename(source_path)
        }
      
      String.contains?(line, "PROGRESS REPORT") ->
        %{
          type: :progress_report,
          timestamp: extract_timestamp(line),
          content: line,
          severity: :info,
          source: Path.basename(source_path)
        }
      
      String.contains?(line, "ERROR REPORT") ->
        %{
          type: :error_report,
          timestamp: extract_timestamp(line),
          content: line,
          severity: :error,
          source: Path.basename(source_path)
        }
      
      String.contains?(line, "ALARM REPORT") ->
        %{
          type: :alarm_report,
          timestamp: extract_timestamp(line),
          content: line,
          severity: :warning,
          source: Path.basename(source_path)
        }
      
      true ->
        # Only include non-empty lines
        if String.trim(line) != "" do
          %{
            type: :other,
            timestamp: extract_timestamp(line),
            content: line,
            severity: :info,
            source: Path.basename(source_path)
          }
        else
          nil
        end
    end
  end
  
  defp extract_timestamp(line) do
    # Try multiple timestamp formats
    cond do
      # Format: "=CRASH REPORT 2025-01-29 12:34:56"
      match = Regex.run(~r/(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})/, line) ->
        List.last(match)
      
      # Format: "2025-01-29T12:34:56Z"
      match = Regex.run(~r/(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z?)/, line) ->
        List.last(match)
      
      # Format: Unix timestamp
      match = Regex.run(~r/(\d{10})/, line) ->
        timestamp = List.last(match) |> String.to_integer()
        DateTime.from_unix!(timestamp) |> DateTime.to_string()
      
      true ->
        # Default to current time if no timestamp found
        DateTime.utc_now() |> DateTime.to_string()
    end
  end
  
  def get_recent_errors(limit \\ 50) do
    traces = get_traces(limit * 2)
    
    case traces do
      {:ok, data} ->
        errors = 
          data.traces
          |> Enum.filter(&(&1.severity == :error))
          |> Enum.take(limit)
        
        {:ok, %{
          errors: errors,
          error_count: length(errors),
          last_updated: data.last_updated
        }}
      
      error -> error
    end
  end
  
  def get_stats do
    traces = get_traces(1000)
    
    case traces do
      {:ok, data} ->
        stats = %{
          total_traces: data.total_count,
          crash_reports: count_by_type(data.traces, :crash_report),
          supervisor_reports: count_by_type(data.traces, :supervisor_report),
          error_reports: count_by_type(data.traces, :error_report),
          progress_reports: count_by_type(data.traces, :progress_report),
          alarm_reports: count_by_type(data.traces, :alarm_report),
          errors: Enum.count(data.traces, &(&1.severity == :error)),
          warnings: Enum.count(data.traces, &(&1.severity == :warning)),
          info: Enum.count(data.traces, &(&1.severity == :info))
        }
        
        {:ok, stats}
      
      error -> error
    end
  end
  
  defp count_by_type(traces, type) do
    Enum.count(traces, &(&1.type == type))
  end
end

