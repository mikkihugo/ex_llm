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
        |> Enum.sort(&newer_trace?/2)
        |> Enum.take(limit)

      {:ok,
       %{
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
        build_trace(:crash_report, :error, line, source_path)
      
      String.contains?(line, "SUPERVISOR REPORT") ->
        build_trace(:supervisor_report, :warning, line, source_path)
      
      String.contains?(line, "PROGRESS REPORT") ->
        build_trace(:progress_report, :info, line, source_path)
      
      String.contains?(line, "ERROR REPORT") ->
        build_trace(:error_report, :error, line, source_path)
      
      String.contains?(line, "ALARM REPORT") ->
        build_trace(:alarm_report, :warning, line, source_path)
      
      true ->
        # Only include non-empty lines
        if String.trim(line) != "" do
          build_trace(:other, :info, line, source_path)
        else
          nil
        end
    end
  end
  
  defp build_trace(type, severity, line, source_path) do
    timestamp = extract_timestamp(line)

    %{
      type: type,
      timestamp: timestamp,
      content: line,
      severity: severity,
      source: Path.basename(source_path)
    }
  end

  defp extract_timestamp(line) do
    cond do
      match = Regex.run(~r/(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})/, line) ->
        match |> List.last() |> parse_naive_timestamp()

      match = Regex.run(~r/(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z?)/, line) ->
        match |> List.last() |> parse_iso_timestamp()

      match = Regex.run(~r/(\d{10})/, line) ->
        match |> List.last() |> String.to_integer() |> DateTime.from_unix!()

      true ->
        DateTime.utc_now()
    end
  end

  defp parse_naive_timestamp(value) do
    value
    |> String.trim()
    |> String.replace(" ", "T")
    |> Kernel.<>("Z")
    |> parse_iso_timestamp()
  end

  defp parse_iso_timestamp(value) do
    value = String.trim(value)

    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, _} ->
        case DateTime.from_iso8601(value <> "Z") do
          {:ok, datetime, _offset} -> datetime
          {:error, _} -> DateTime.utc_now()
        end
    end
  end

  defp newer_trace?(%{timestamp: ts1}, %{timestamp: ts2}) do
    DateTime.compare(ts1, ts2) != :lt
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
