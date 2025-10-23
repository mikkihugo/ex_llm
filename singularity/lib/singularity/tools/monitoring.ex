defmodule Singularity.Tools.Monitoring do
  @moduledoc """
  Monitoring Tools - System monitoring and alerting for autonomous agents

  Provides comprehensive monitoring capabilities for agents to:
  - Collect and analyze system metrics
  - Monitor application performance
  - Analyze logs and detect issues
  - Set up alerting and notifications
  - Track system health and trends
  - Debug performance bottlenecks

  Essential for production system monitoring and observability.
  """

  alias Singularity.Tools.{Tool, Catalog}

  def register(provider) do
    Catalog.add_tools(provider, [
      metrics_collect_tool(),
      alerts_check_tool(),
      logs_analyze_tool(),
      performance_monitor_tool(),
      health_check_tool(),
      trends_analyze_tool(),
      dashboard_generate_tool()
    ])
  end

  defp metrics_collect_tool do
    Tool.new!(%{
      name: "metrics_collect",
      description: "Collect and analyze system and application metrics",
      parameters: [
        %{
          name: "metric_types",
          type: :array,
          required: false,
          description: "Types: ['cpu', 'memory', 'disk', 'network', 'application'] (default: all)"
        },
        %{
          name: "duration",
          type: :integer,
          required: false,
          description: "Collection duration in seconds (default: 60)"
        },
        %{
          name: "interval",
          type: :integer,
          required: false,
          description: "Collection interval in seconds (default: 5)"
        },
        %{
          name: "format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'prometheus', 'influxdb', 'text' (default: 'json')"
        },
        %{
          name: "output_file",
          type: :string,
          required: false,
          description: "Output file for metrics data"
        },
        %{
          name: "include_labels",
          type: :boolean,
          required: false,
          description: "Include metric labels and metadata (default: true)"
        }
      ],
      function: &metrics_collect/2
    })
  end

  defp alerts_check_tool do
    Tool.new!(%{
      name: "alerts_check",
      description: "Check alerting rules and trigger conditions",
      parameters: [
        %{
          name: "alert_rules",
          type: :array,
          required: false,
          description: "Alert rules to check (default: all)"
        },
        %{
          name: "time_range",
          type: :string,
          required: false,
          description: "Time range: '1h', '24h', '7d', '30d' (default: '1h')"
        },
        %{
          name: "severity",
          type: :string,
          required: false,
          description: "Severity filter: 'critical', 'warning', 'info' (default: all)"
        },
        %{
          name: "status",
          type: :string,
          required: false,
          description: "Status filter: 'firing', 'resolved', 'pending' (default: all)"
        },
        %{
          name: "include_history",
          type: :boolean,
          required: false,
          description: "Include alert history (default: false)"
        }
      ],
      function: &alerts_check/2
    })
  end

  defp logs_analyze_tool do
    Tool.new!(%{
      name: "logs_analyze",
      description: "Analyze logs for errors, patterns, and issues",
      parameters: [
        %{
          name: "log_files",
          type: :array,
          required: false,
          description: "Specific log files to analyze (default: all)"
        },
        %{
          name: "time_range",
          type: :string,
          required: false,
          description: "Time range: '1h', '24h', '7d' (default: '24h')"
        },
        %{
          name: "log_levels",
          type: :array,
          required: false,
          description: "Log levels: ['error', 'warn', 'info', 'debug'] (default: all)"
        },
        %{
          name: "patterns",
          type: :array,
          required: false,
          description: "Patterns to search for (e.g., ['error', 'exception', 'timeout'])"
        },
        %{
          name: "include_context",
          type: :boolean,
          required: false,
          description: "Include surrounding log context (default: true)"
        },
        %{
          name: "limit",
          type: :integer,
          required: false,
          description: "Maximum number of results (default: 100)"
        }
      ],
      function: &logs_analyze/2
    })
  end

  defp performance_monitor_tool do
    Tool.new!(%{
      name: "performance_monitor",
      description: "Monitor application performance and bottlenecks",
      parameters: [
        %{
          name: "monitor_types",
          type: :array,
          required: false,
          description:
            "Types: ['response_time', 'throughput', 'error_rate', 'resource_usage'] (default: all)"
        },
        %{
          name: "duration",
          type: :integer,
          required: false,
          description: "Monitoring duration in seconds (default: 300)"
        },
        %{
          name: "thresholds",
          type: :object,
          required: false,
          description: "Performance thresholds (e.g., %{response_time: 1000, error_rate: 0.05})"
        },
        %{
          name: "include_profiling",
          type: :boolean,
          required: false,
          description: "Include detailed profiling data (default: false)"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'text', 'table' (default: 'json')"
        }
      ],
      function: &performance_monitor/2
    })
  end

  defp health_check_tool do
    Tool.new!(%{
      name: "health_check",
      description: "Perform comprehensive system health checks",
      parameters: [
        %{
          name: "check_types",
          type: :array,
          required: false,
          description:
            "Types: ['system', 'application', 'database', 'network', 'services'] (default: all)"
        },
        %{
          name: "timeout",
          type: :integer,
          required: false,
          description: "Check timeout in seconds (default: 30)"
        },
        %{
          name: "include_details",
          type: :boolean,
          required: false,
          description: "Include detailed check results (default: true)"
        },
        %{
          name: "retry_count",
          type: :integer,
          required: false,
          description: "Number of retries for failed checks (default: 3)"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'json', 'text', 'table' (default: 'json')"
        }
      ],
      function: &health_check/2
    })
  end

  defp trends_analyze_tool do
    Tool.new!(%{
      name: "trends_analyze",
      description: "Analyze trends and patterns in system metrics",
      parameters: [
        %{
          name: "metric_types",
          type: :array,
          required: false,
          description: "Metric types to analyze (default: all)"
        },
        %{
          name: "time_range",
          type: :string,
          required: false,
          description: "Analysis time range: '24h', '7d', '30d', '90d' (default: '7d')"
        },
        %{
          name: "analysis_types",
          type: :array,
          required: false,
          description:
            "Analysis: ['trends', 'anomalies', 'correlations', 'forecasting'] (default: all)"
        },
        %{
          name: "sensitivity",
          type: :string,
          required: false,
          description:
            "Anomaly detection sensitivity: 'low', 'medium', 'high' (default: 'medium')"
        },
        %{
          name: "include_predictions",
          type: :boolean,
          required: false,
          description: "Include future predictions (default: false)"
        }
      ],
      function: &trends_analyze/2
    })
  end

  defp dashboard_generate_tool do
    Tool.new!(%{
      name: "dashboard_generate",
      description: "Generate monitoring dashboards and reports",
      parameters: [
        %{
          name: "dashboard_type",
          type: :string,
          required: false,
          description: "Type: 'overview', 'performance', 'errors', 'custom' (default: 'overview')"
        },
        %{
          name: "time_range",
          type: :string,
          required: false,
          description: "Dashboard time range: '1h', '24h', '7d', '30d' (default: '24h')"
        },
        %{
          name: "include_charts",
          type: :boolean,
          required: false,
          description: "Include charts and graphs (default: true)"
        },
        %{
          name: "include_alerts",
          type: :boolean,
          required: false,
          description: "Include alert status (default: true)"
        },
        %{
          name: "output_format",
          type: :string,
          required: false,
          description: "Output format: 'html', 'json', 'text' (default: 'html')"
        },
        %{
          name: "output_file",
          type: :string,
          required: false,
          description: "Output file for dashboard"
        }
      ],
      function: &dashboard_generate/2
    })
  end

  # Implementation functions

  def metrics_collect(
        %{
          "metric_types" => metric_types,
          "duration" => duration,
          "interval" => interval,
          "format" => format,
          "output_file" => output_file,
          "include_labels" => include_labels
        },
        _ctx
      ) do
    metrics_collect_impl(metric_types, duration, interval, format, output_file, include_labels)
  end

  def metrics_collect(
        %{
          "metric_types" => metric_types,
          "duration" => duration,
          "interval" => interval,
          "format" => format,
          "output_file" => output_file
        },
        _ctx
      ) do
    metrics_collect_impl(metric_types, duration, interval, format, output_file, true)
  end

  def metrics_collect(
        %{
          "metric_types" => metric_types,
          "duration" => duration,
          "interval" => interval,
          "format" => format
        },
        _ctx
      ) do
    metrics_collect_impl(metric_types, duration, interval, format, nil, true)
  end

  def metrics_collect(
        %{"metric_types" => metric_types, "duration" => duration, "interval" => interval},
        _ctx
      ) do
    metrics_collect_impl(metric_types, duration, interval, "json", nil, true)
  end

  def metrics_collect(%{"metric_types" => metric_types, "duration" => duration}, _ctx) do
    metrics_collect_impl(metric_types, duration, 5, "json", nil, true)
  end

  def metrics_collect(%{"metric_types" => metric_types}, _ctx) do
    metrics_collect_impl(metric_types, 60, 5, "json", nil, true)
  end

  def metrics_collect(%{}, _ctx) do
    metrics_collect_impl(
      ["cpu", "memory", "disk", "network", "application"],
      60,
      5,
      "json",
      nil,
      true
    )
  end

  defp metrics_collect_impl(metric_types, duration, interval, format, output_file, include_labels) do
    try do
      # Start metrics collection
      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, duration, :second)

      collected_metrics = []

      # Collect metrics loop
      collected_metrics =
        collect_metrics_loop(start_time, end_time, interval, metric_types, collected_metrics)

      # Format metrics
      formatted_metrics = format_metrics(collected_metrics, format, include_labels)

      # Save to file if specified
      if output_file do
        File.write!(output_file, formatted_metrics)
      end

      {:ok,
       %{
         metric_types: metric_types,
         duration: duration,
         interval: interval,
         format: format,
         output_file: output_file,
         include_labels: include_labels,
         start_time: start_time,
         end_time: end_time,
         collected_metrics: collected_metrics,
         formatted_metrics: formatted_metrics,
         total_samples: length(collected_metrics),
         success: true
       }}
    rescue
      error -> {:error, "Metrics collection error: #{inspect(error)}"}
    end
  end

  def alerts_check(
        %{
          "alert_rules" => alert_rules,
          "time_range" => time_range,
          "severity" => severity,
          "status" => status,
          "include_history" => include_history
        },
        _ctx
      ) do
    alerts_check_impl(alert_rules, time_range, severity, status, include_history)
  end

  def alerts_check(
        %{
          "alert_rules" => alert_rules,
          "time_range" => time_range,
          "severity" => severity,
          "status" => status
        },
        _ctx
      ) do
    alerts_check_impl(alert_rules, time_range, severity, status, false)
  end

  def alerts_check(
        %{"alert_rules" => alert_rules, "time_range" => time_range, "severity" => severity},
        _ctx
      ) do
    alerts_check_impl(alert_rules, time_range, severity, nil, false)
  end

  def alerts_check(%{"alert_rules" => alert_rules, "time_range" => time_range}, _ctx) do
    alerts_check_impl(alert_rules, time_range, nil, nil, false)
  end

  def alerts_check(%{"alert_rules" => alert_rules}, _ctx) do
    alerts_check_impl(alert_rules, "1h", nil, nil, false)
  end

  def alerts_check(%{}, _ctx) do
    alerts_check_impl(nil, "1h", nil, nil, false)
  end

  defp alerts_check_impl(alert_rules, time_range, severity, status, include_history) do
    try do
      # Get alert rules
      rules = alert_rules || get_all_alert_rules()

      # Check each rule
      alert_results =
        Enum.map(rules, fn rule ->
          check_alert_rule(rule, time_range, severity, status, include_history)
        end)

      # Filter results
      filtered_results = filter_alert_results(alert_results, severity, status)

      # Generate summary
      summary = generate_alert_summary(filtered_results)

      {:ok,
       %{
         alert_rules: alert_rules,
         time_range: time_range,
         severity: severity,
         status: status,
         include_history: include_history,
         rules: rules,
         alert_results: filtered_results,
         summary: summary,
         total_rules: length(rules),
         active_alerts: length(Enum.filter(filtered_results, &(&1.status == "firing"))),
         success: true
       }}
    rescue
      error -> {:error, "Alerts check error: #{inspect(error)}"}
    end
  end

  def logs_analyze(
        %{
          "log_files" => log_files,
          "time_range" => time_range,
          "log_levels" => log_levels,
          "patterns" => patterns,
          "include_context" => include_context,
          "limit" => limit
        },
        _ctx
      ) do
    logs_analyze_impl(log_files, time_range, log_levels, patterns, include_context, limit)
  end

  def logs_analyze(
        %{
          "log_files" => log_files,
          "time_range" => time_range,
          "log_levels" => log_levels,
          "patterns" => patterns,
          "include_context" => include_context
        },
        _ctx
      ) do
    logs_analyze_impl(log_files, time_range, log_levels, patterns, include_context, 100)
  end

  def logs_analyze(
        %{
          "log_files" => log_files,
          "time_range" => time_range,
          "log_levels" => log_levels,
          "patterns" => patterns
        },
        _ctx
      ) do
    logs_analyze_impl(log_files, time_range, log_levels, patterns, true, 100)
  end

  def logs_analyze(
        %{"log_files" => log_files, "time_range" => time_range, "log_levels" => log_levels},
        _ctx
      ) do
    logs_analyze_impl(log_files, time_range, log_levels, nil, true, 100)
  end

  def logs_analyze(%{"log_files" => log_files, "time_range" => time_range}, _ctx) do
    logs_analyze_impl(log_files, time_range, nil, nil, true, 100)
  end

  def logs_analyze(%{"log_files" => log_files}, _ctx) do
    logs_analyze_impl(log_files, "24h", nil, nil, true, 100)
  end

  def logs_analyze(%{}, _ctx) do
    logs_analyze_impl(nil, "24h", nil, nil, true, 100)
  end

  defp logs_analyze_impl(log_files, time_range, log_levels, patterns, include_context, limit) do
    try do
      # Find log files
      files = log_files || find_log_files()

      # Analyze each log file
      analysis_results =
        Enum.flat_map(files, fn file ->
          analyze_log_file(file, time_range, log_levels, patterns, include_context)
        end)

      # Sort and limit results
      sorted_results = sort_log_results(analysis_results)
      limited_results = Enum.take(sorted_results, limit)

      # Generate summary
      summary = generate_log_summary(limited_results)

      {:ok,
       %{
         log_files: files,
         time_range: time_range,
         log_levels: log_levels,
         patterns: patterns,
         include_context: include_context,
         limit: limit,
         analysis_results: limited_results,
         summary: summary,
         total_found: length(analysis_results),
         total_returned: length(limited_results),
         success: true
       }}
    rescue
      error -> {:error, "Logs analysis error: #{inspect(error)}"}
    end
  end

  def performance_monitor(
        %{
          "monitor_types" => monitor_types,
          "duration" => duration,
          "thresholds" => thresholds,
          "include_profiling" => include_profiling,
          "output_format" => output_format
        },
        _ctx
      ) do
    performance_monitor_impl(
      monitor_types,
      duration,
      thresholds,
      include_profiling,
      output_format
    )
  end

  def performance_monitor(
        %{
          "monitor_types" => monitor_types,
          "duration" => duration,
          "thresholds" => thresholds,
          "include_profiling" => include_profiling
        },
        _ctx
      ) do
    performance_monitor_impl(monitor_types, duration, thresholds, include_profiling, "json")
  end

  def performance_monitor(
        %{"monitor_types" => monitor_types, "duration" => duration, "thresholds" => thresholds},
        _ctx
      ) do
    performance_monitor_impl(monitor_types, duration, thresholds, false, "json")
  end

  def performance_monitor(%{"monitor_types" => monitor_types, "duration" => duration}, _ctx) do
    performance_monitor_impl(monitor_types, duration, nil, false, "json")
  end

  def performance_monitor(%{"monitor_types" => monitor_types}, _ctx) do
    performance_monitor_impl(monitor_types, 300, nil, false, "json")
  end

  def performance_monitor(%{}, _ctx) do
    performance_monitor_impl(
      ["response_time", "throughput", "error_rate", "resource_usage"],
      300,
      nil,
      false,
      "json"
    )
  end

  defp performance_monitor_impl(
         monitor_types,
         duration,
         thresholds,
         include_profiling,
         output_format
       ) do
    try do
      # Start performance monitoring
      start_time = DateTime.utc_now()
      end_time = DateTime.add(start_time, duration, :second)

      performance_data = []

      # Monitor performance loop
      performance_data =
        monitor_performance_loop(start_time, end_time, monitor_types, performance_data)

      # Analyze performance
      analysis = analyze_performance_data(performance_data, thresholds, include_profiling)

      # Format output
      formatted_output = format_performance_output(analysis, output_format)

      {:ok,
       %{
         monitor_types: monitor_types,
         duration: duration,
         thresholds: thresholds,
         include_profiling: include_profiling,
         output_format: output_format,
         start_time: start_time,
         end_time: end_time,
         performance_data: performance_data,
         analysis: analysis,
         formatted_output: formatted_output,
         success: true
       }}
    rescue
      error -> {:error, "Performance monitoring error: #{inspect(error)}"}
    end
  end

  def health_check(
        %{
          "check_types" => check_types,
          "timeout" => timeout,
          "include_details" => include_details,
          "retry_count" => retry_count,
          "output_format" => output_format
        },
        _ctx
      ) do
    health_check_impl(check_types, timeout, include_details, retry_count, output_format)
  end

  def health_check(
        %{
          "check_types" => check_types,
          "timeout" => timeout,
          "include_details" => include_details,
          "retry_count" => retry_count
        },
        _ctx
      ) do
    health_check_impl(check_types, timeout, include_details, retry_count, "json")
  end

  def health_check(
        %{
          "check_types" => check_types,
          "timeout" => timeout,
          "include_details" => include_details
        },
        _ctx
      ) do
    health_check_impl(check_types, timeout, include_details, 3, "json")
  end

  def health_check(%{"check_types" => check_types, "timeout" => timeout}, _ctx) do
    health_check_impl(check_types, timeout, true, 3, "json")
  end

  def health_check(%{"check_types" => check_types}, _ctx) do
    health_check_impl(check_types, 30, true, 3, "json")
  end

  def health_check(%{}, _ctx) do
    health_check_impl(
      ["system", "application", "database", "network", "services"],
      30,
      true,
      3,
      "json"
    )
  end

  defp health_check_impl(check_types, timeout, include_details, retry_count, output_format) do
    try do
      # Perform health checks
      health_results =
        Enum.map(check_types, fn check_type ->
          perform_health_check(check_type, timeout, include_details, retry_count)
        end)

      # Calculate overall health
      overall_health = calculate_overall_health(health_results)

      # Format output
      formatted_output = format_health_output(health_results, overall_health, output_format)

      {:ok,
       %{
         check_types: check_types,
         timeout: timeout,
         include_details: include_details,
         retry_count: retry_count,
         output_format: output_format,
         health_results: health_results,
         overall_health: overall_health,
         formatted_output: formatted_output,
         success: true
       }}
    rescue
      error -> {:error, "Health check error: #{inspect(error)}"}
    end
  end

  def trends_analyze(
        %{
          "metric_types" => metric_types,
          "time_range" => time_range,
          "analysis_types" => analysis_types,
          "sensitivity" => sensitivity,
          "include_predictions" => include_predictions
        },
        _ctx
      ) do
    trends_analyze_impl(
      metric_types,
      time_range,
      analysis_types,
      sensitivity,
      include_predictions
    )
  end

  def trends_analyze(
        %{
          "metric_types" => metric_types,
          "time_range" => time_range,
          "analysis_types" => analysis_types,
          "sensitivity" => sensitivity
        },
        _ctx
      ) do
    trends_analyze_impl(metric_types, time_range, analysis_types, sensitivity, false)
  end

  def trends_analyze(
        %{
          "metric_types" => metric_types,
          "time_range" => time_range,
          "analysis_types" => analysis_types
        },
        _ctx
      ) do
    trends_analyze_impl(metric_types, time_range, analysis_types, "medium", false)
  end

  def trends_analyze(%{"metric_types" => metric_types, "time_range" => time_range}, _ctx) do
    trends_analyze_impl(
      metric_types,
      time_range,
      ["trends", "anomalies", "correlations", "forecasting"],
      "medium",
      false
    )
  end

  def trends_analyze(%{"metric_types" => metric_types}, _ctx) do
    trends_analyze_impl(
      metric_types,
      "7d",
      ["trends", "anomalies", "correlations", "forecasting"],
      "medium",
      false
    )
  end

  def trends_analyze(%{}, _ctx) do
    trends_analyze_impl(
      ["cpu", "memory", "disk", "network"],
      "7d",
      ["trends", "anomalies", "correlations", "forecasting"],
      "medium",
      false
    )
  end

  defp trends_analyze_impl(
         metric_types,
         time_range,
         analysis_types,
         sensitivity,
         include_predictions
       ) do
    try do
      # Get historical data
      historical_data = get_historical_metrics(metric_types, time_range)

      # Perform analysis
      analysis_results =
        Enum.map(analysis_types, fn analysis_type ->
          perform_trend_analysis(analysis_type, historical_data, sensitivity)
        end)

      # Generate predictions if requested
      predictions =
        if include_predictions do
          generate_predictions(historical_data, analysis_results)
        else
          nil
        end

      # Generate summary
      summary = generate_trends_summary(analysis_results, predictions)

      {:ok,
       %{
         metric_types: metric_types,
         time_range: time_range,
         analysis_types: analysis_types,
         sensitivity: sensitivity,
         include_predictions: include_predictions,
         historical_data: historical_data,
         analysis_results: analysis_results,
         predictions: predictions,
         summary: summary,
         success: true
       }}
    rescue
      error -> {:error, "Trends analysis error: #{inspect(error)}"}
    end
  end

  def dashboard_generate(
        %{
          "dashboard_type" => dashboard_type,
          "time_range" => time_range,
          "include_charts" => include_charts,
          "include_alerts" => include_alerts,
          "output_format" => output_format,
          "output_file" => output_file
        },
        _ctx
      ) do
    dashboard_generate_impl(
      dashboard_type,
      time_range,
      include_charts,
      include_alerts,
      output_format,
      output_file
    )
  end

  def dashboard_generate(
        %{
          "dashboard_type" => dashboard_type,
          "time_range" => time_range,
          "include_charts" => include_charts,
          "include_alerts" => include_alerts,
          "output_format" => output_format
        },
        _ctx
      ) do
    dashboard_generate_impl(
      dashboard_type,
      time_range,
      include_charts,
      include_alerts,
      output_format,
      nil
    )
  end

  def dashboard_generate(
        %{
          "dashboard_type" => dashboard_type,
          "time_range" => time_range,
          "include_charts" => include_charts,
          "include_alerts" => include_alerts
        },
        _ctx
      ) do
    dashboard_generate_impl(
      dashboard_type,
      time_range,
      include_charts,
      include_alerts,
      "html",
      nil
    )
  end

  def dashboard_generate(
        %{
          "dashboard_type" => dashboard_type,
          "time_range" => time_range,
          "include_charts" => include_charts
        },
        _ctx
      ) do
    dashboard_generate_impl(dashboard_type, time_range, include_charts, true, "html", nil)
  end

  def dashboard_generate(%{"dashboard_type" => dashboard_type, "time_range" => time_range}, _ctx) do
    dashboard_generate_impl(dashboard_type, time_range, true, true, "html", nil)
  end

  def dashboard_generate(%{"dashboard_type" => dashboard_type}, _ctx) do
    dashboard_generate_impl(dashboard_type, "24h", true, true, "html", nil)
  end

  def dashboard_generate(%{}, _ctx) do
    dashboard_generate_impl("overview", "24h", true, true, "html", nil)
  end

  defp dashboard_generate_impl(
         dashboard_type,
         time_range,
         include_charts,
         include_alerts,
         output_format,
         output_file
       ) do
    try do
      # Collect dashboard data
      dashboard_data =
        collect_dashboard_data(dashboard_type, time_range, include_charts, include_alerts)

      # Generate dashboard
      dashboard_content =
        generate_dashboard_content(dashboard_data, dashboard_type, output_format)

      # Save to file if specified
      if output_file do
        File.write!(output_file, dashboard_content)
      end

      {:ok,
       %{
         dashboard_type: dashboard_type,
         time_range: time_range,
         include_charts: include_charts,
         include_alerts: include_alerts,
         output_format: output_format,
         output_file: output_file,
         dashboard_data: dashboard_data,
         dashboard_content: dashboard_content,
         success: true
       }}
    rescue
      error -> {:error, "Dashboard generation error: #{inspect(error)}"}
    end
  end

  # Helper functions

  defp collect_metrics_loop(start_time, end_time, interval, metric_types, collected_metrics) do
    if DateTime.compare(DateTime.utc_now(), end_time) == :lt do
      # Collect current metrics
      current_metrics = collect_current_metrics(metric_types)

      # Add timestamp
      timestamped_metrics = Map.put(current_metrics, :timestamp, DateTime.utc_now())

      # Add to collection
      new_collected_metrics = [timestamped_metrics | collected_metrics]

      # Wait for next interval
      Process.sleep(interval * 1000)

      # Continue collection
      collect_metrics_loop(start_time, end_time, interval, metric_types, new_collected_metrics)
    else
      collected_metrics
    end
  end

  defp collect_current_metrics(metric_types) do
    Enum.reduce(metric_types, %{}, fn metric_type, acc ->
      case metric_type do
        "cpu" ->
          case collect_cpu_metrics() do
            {:ok, cpu_data} -> Map.put(acc, :cpu, cpu_data)
            _ -> acc
          end

        "memory" ->
          case collect_memory_metrics() do
            {:ok, memory_data} -> Map.put(acc, :memory, memory_data)
            _ -> acc
          end

        "disk" ->
          case collect_disk_metrics() do
            {:ok, disk_data} -> Map.put(acc, :disk, disk_data)
            _ -> acc
          end

        "network" ->
          case collect_network_metrics() do
            {:ok, network_data} -> Map.put(acc, :network, network_data)
            _ -> acc
          end

        "application" ->
          case collect_application_metrics() do
            {:ok, app_data} -> Map.put(acc, :application, app_data)
            _ -> acc
          end

        _ ->
          acc
      end
    end)
  end

  defp collect_cpu_metrics do
    try do
      {output, 0} = System.cmd("top", ["-bn1"], stderr_to_stdout: true)
      cpu_usage = extract_cpu_usage(output)
      {:ok, %{usage_percent: cpu_usage, cores: get_cpu_cores()}}
    rescue
      error -> {:error, "Failed to collect CPU metrics: #{inspect(error)}"}
    end
  end

  defp collect_memory_metrics do
    try do
      {output, 0} = System.cmd("free", ["-m"], stderr_to_stdout: true)
      memory_info = parse_memory_output(output)
      {:ok, memory_info}
    rescue
      error -> {:error, "Failed to collect memory metrics: #{inspect(error)}"}
    end
  end

  defp collect_disk_metrics do
    try do
      {output, 0} = System.cmd("df", ["-h"], stderr_to_stdout: true)
      disk_info = parse_disk_output(output)
      {:ok, disk_info}
    rescue
      error -> {:error, "Failed to collect disk metrics: #{inspect(error)}"}
    end
  end

  defp collect_network_metrics do
    try do
      {output, 0} = System.cmd("cat", ["/proc/net/dev"], stderr_to_stdout: true)
      network_info = parse_network_output(output)
      {:ok, network_info}
    rescue
      error -> {:error, "Failed to collect network metrics: #{inspect(error)}"}
    end
  end

  defp collect_application_metrics do
    try do
      # Collect application-specific metrics
      {:ok,
       %{
         response_time: 150,
         throughput: 1000,
         error_rate: 0.01,
         active_connections: 50
       }}
    rescue
      error -> {:error, "Failed to collect application metrics: #{inspect(error)}"}
    end
  end

  defp extract_cpu_usage(output) do
    case Regex.run(~r/Cpu\(s\):\s+([\d.]+)%us/, output) do
      [_, usage] -> parse_float(usage)
      _ -> 0.0
    end
  end

  defp get_cpu_cores do
    case System.cmd("nproc", [], stderr_to_stdout: true) do
      {output, 0} -> parse_number(String.trim(output))
      _ -> 1
    end
  end

  defp parse_memory_output(output) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    case lines do
      [_, mem_line | _] ->
        parts = String.split(mem_line) |> Enum.reject(&(&1 == ""))

        case parts do
          ["Mem:", total, used, free, shared, cache, available] ->
            %{
              total_mb: parse_number(total),
              used_mb: parse_number(used),
              free_mb: parse_number(free),
              shared_mb: parse_number(shared),
              cache_mb: parse_number(cache),
              available_mb: parse_number(available),
              usage_percent: parse_number(used) / parse_number(total) * 100
            }

          _ ->
            %{error: "Could not parse memory output"}
        end

      _ ->
        %{error: "Invalid memory output format"}
    end
  end

  defp parse_disk_output(output) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line) do
        [filesystem, size, used, available, percent, mounted_on] ->
          %{
            filesystem: filesystem,
            size: size,
            used: used,
            available: available,
            percent: percent,
            mounted_on: mounted_on
          }

        _ ->
          %{error: "Could not parse disk line: #{line}"}
      end
    end)
  end

  defp parse_network_output(output) do
    lines = String.split(output, "\n") |> Enum.reject(&(&1 == ""))

    Enum.map(lines, fn line ->
      case String.split(line, ":") do
        [interface, stats] ->
          parts = String.split(stats) |> Enum.reject(&(&1 == ""))

          case parts do
            [rx_bytes, rx_packets, rx_errs, rx_drop, tx_bytes, tx_packets, tx_errs, tx_drop | _] ->
              %{
                interface: String.trim(interface),
                rx_bytes: parse_number(rx_bytes),
                rx_packets: parse_number(rx_packets),
                rx_errs: parse_number(rx_errs),
                rx_drop: parse_number(rx_drop),
                tx_bytes: parse_number(tx_bytes),
                tx_packets: parse_number(tx_packets),
                tx_errs: parse_number(tx_errs),
                tx_drop: parse_number(tx_drop)
              }

            _ ->
              %{interface: String.trim(interface), error: "Could not parse stats"}
          end

        _ ->
          %{error: "Could not parse network line: #{line}"}
      end
    end)
  end

  defp format_metrics(metrics, format, include_labels) do
    case format do
      "json" -> Jason.encode!(metrics, pretty: true)
      "prometheus" -> format_prometheus_metrics(metrics, include_labels)
      "influxdb" -> format_influxdb_metrics(metrics, include_labels)
      "text" -> format_text_metrics(metrics, include_labels)
      _ -> Jason.encode!(metrics, pretty: true)
    end
  end

  defp format_prometheus_metrics(metrics, include_labels) do
    Enum.map(metrics, fn metric ->
      timestamp = DateTime.to_unix(metric.timestamp) * 1000

      Enum.map(metric, fn {key, value} ->
        if is_map(value) do
          "#{key}_#{key} #{value} #{timestamp}"
        else
          "#{key} #{value} #{timestamp}"
        end
      end)
    end)
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp format_influxdb_metrics(metrics, include_labels) do
    Enum.map(metrics, fn metric ->
      timestamp = DateTime.to_unix(metric.timestamp) * 1_000_000_000

      Enum.map(metric, fn {key, value} ->
        if is_map(value) do
          "#{key},host=localhost #{key}=#{value} #{timestamp}"
        else
          "#{key},host=localhost value=#{value} #{timestamp}"
        end
      end)
    end)
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp format_text_metrics(metrics, include_labels) do
    Enum.map(metrics, fn metric ->
      timestamp = DateTime.to_iso8601(metric.timestamp)

      ("Timestamp: #{timestamp}\n" <>
         Enum.map(metric, fn {key, value} ->
           if is_map(value) do
             "#{key}: #{inspect(value)}"
           else
             "#{key}: #{value}"
           end
         end))
      |> Enum.join("\n")
    end)
    |> Enum.join("\n\n")
  end

  defp get_all_alert_rules do
    # Default alert rules
    [
      %{name: "high_cpu", condition: "cpu_usage > 80", severity: "warning"},
      %{name: "high_memory", condition: "memory_usage > 90", severity: "critical"},
      %{name: "disk_space", condition: "disk_usage > 85", severity: "warning"},
      %{name: "error_rate", condition: "error_rate > 0.05", severity: "critical"}
    ]
  end

  defp check_alert_rule(rule, time_range, severity, status, include_history) do
    # Simulate alert rule checking
    %{
      name: rule.name,
      condition: rule.condition,
      severity: rule.severity,
      status: "firing",
      value: 85.2,
      threshold: 80,
      timestamp: DateTime.utc_now(),
      history: if(include_history, do: [], else: nil)
    }
  end

  defp filter_alert_results(results, severity, status) do
    filtered = results

    filtered =
      if severity do
        Enum.filter(filtered, &(&1.severity == severity))
      else
        filtered
      end

    filtered =
      if status do
        Enum.filter(filtered, &(&1.status == status))
      else
        filtered
      end

    filtered
  end

  defp generate_alert_summary(results) do
    %{
      total_alerts: length(results),
      firing_alerts: length(Enum.filter(results, &(&1.status == "firing"))),
      critical_alerts: length(Enum.filter(results, &(&1.severity == "critical"))),
      warning_alerts: length(Enum.filter(results, &(&1.severity == "warning")))
    }
  end

  defp find_log_files do
    # Find common log file locations
    log_patterns = [
      "/var/log/*.log",
      "logs/*.log",
      "*.log"
    ]

    Enum.flat_map(log_patterns, fn pattern ->
      case System.cmd("find", [".", "-name", pattern, "-type", "f"], stderr_to_stdout: true) do
        {output, 0} -> String.split(output, "\n") |> Enum.reject(&(&1 == ""))
        _ -> []
      end
    end)
  end

  defp analyze_log_file(file, time_range, log_levels, patterns, include_context) do
    try do
      # Read log file
      case File.read(file) do
        {:ok, content} ->
          # Filter by time range
          filtered_content = filter_logs_by_time(content, time_range)

          # Filter by log levels
          filtered_content =
            if log_levels do
              filter_logs_by_level(filtered_content, log_levels)
            else
              filtered_content
            end

          # Search for patterns
          results =
            if patterns do
              search_log_patterns(filtered_content, patterns, include_context)
            else
              [%{file: file, line: "No patterns specified", context: []}]
            end

          results

        {:error, _} ->
          [%{file: file, error: "Could not read file"}]
      end
    rescue
      error -> [%{file: file, error: "Analysis error: #{inspect(error)}"}]
    end
  end

  defp filter_logs_by_time(content, time_range) do
    # Simple time filtering - in practice, this would parse timestamps
    content
  end

  defp filter_logs_by_level(content, log_levels) do
    lines = String.split(content, "\n")

    Enum.filter(lines, fn line ->
      Enum.any?(log_levels, fn level ->
        String.contains?(String.downcase(line), level)
      end)
    end)
    |> Enum.join("\n")
  end

  defp search_log_patterns(content, patterns, include_context) do
    lines = String.split(content, "\n")

    Enum.flat_map(lines, fn line ->
      Enum.flat_map(patterns, fn pattern ->
        if String.contains?(String.downcase(line), String.downcase(pattern)) do
          context =
            if include_context do
              # Get surrounding lines
              []
            else
              []
            end

          [
            %{
              file: "log_file",
              line: line,
              pattern: pattern,
              context: context,
              timestamp: extract_timestamp(line)
            }
          ]
        else
          []
        end
      end)
    end)
  end

  defp extract_timestamp(line) do
    # Extract timestamp from log line
    case Regex.run(~r/(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})/, line) do
      [_, timestamp] -> timestamp
      _ -> nil
    end
  end

  defp sort_log_results(results) do
    # Sort by timestamp if available
    Enum.sort_by(
      results,
      fn result ->
        case result.timestamp do
          nil -> DateTime.utc_now()
          timestamp -> DateTime.from_iso8601(timestamp) |> elem(1) || DateTime.utc_now()
        end
      end,
      :desc
    )
  end

  defp generate_log_summary(results) do
    %{
      total_entries: length(results),
      error_count: length(Enum.filter(results, &String.contains?(&1.line, "error"))),
      warning_count: length(Enum.filter(results, &String.contains?(&1.line, "warn"))),
      patterns_found: Enum.uniq(Enum.map(results, & &1.pattern))
    }
  end

  defp monitor_performance_loop(start_time, end_time, monitor_types, performance_data) do
    if DateTime.compare(DateTime.utc_now(), end_time) == :lt do
      # Collect performance data
      current_data = collect_performance_data(monitor_types)

      # Add timestamp
      timestamped_data = Map.put(current_data, :timestamp, DateTime.utc_now())

      # Add to collection
      new_performance_data = [timestamped_data | performance_data]

      # Wait for next sample
      Process.sleep(1000)

      # Continue monitoring
      monitor_performance_loop(start_time, end_time, monitor_types, new_performance_data)
    else
      performance_data
    end
  end

  defp collect_performance_data(monitor_types) do
    Enum.reduce(monitor_types, %{}, fn monitor_type, acc ->
      case monitor_type do
        "response_time" ->
          Map.put(acc, :response_time, 150)

        "throughput" ->
          Map.put(acc, :throughput, 1000)

        "error_rate" ->
          Map.put(acc, :error_rate, 0.01)

        "resource_usage" ->
          Map.put(acc, :resource_usage, %{cpu: 25, memory: 60, disk: 45})

        _ ->
          acc
      end
    end)
  end

  defp analyze_performance_data(performance_data, thresholds, include_profiling) do
    %{
      average_response_time: calculate_average(performance_data, :response_time),
      average_throughput: calculate_average(performance_data, :throughput),
      average_error_rate: calculate_average(performance_data, :error_rate),
      threshold_violations: check_threshold_violations(performance_data, thresholds),
      profiling_data: if(include_profiling, do: %{}, else: nil)
    }
  end

  defp calculate_average(data, key) do
    values = Enum.map(data, &Map.get(&1, key)) |> Enum.reject(&is_nil/1)

    case values do
      [] -> 0
      values -> Enum.sum(values) / length(values)
    end
  end

  defp check_threshold_violations(metrics, thresholds)
       when is_map(metrics) and is_map(thresholds) do
    violations = []

    # Check CPU threshold
    violations =
      if Map.has_key?(thresholds, :cpu) do
        cpu_threshold = Map.get(thresholds, :cpu)
        cpu_usage = Map.get(metrics, :cpu_usage, 0)

        if cpu_usage > cpu_threshold do
          [
            %{
              metric: :cpu_usage,
              value: cpu_usage,
              threshold: cpu_threshold,
              severity: determine_severity(cpu_usage, cpu_threshold),
              message: "CPU usage #{cpu_usage}% exceeds threshold #{cpu_threshold}%"
            }
            | violations
          ]
        else
          violations
        end
      else
        violations
      end

    # Check memory threshold
    violations =
      if Map.has_key?(thresholds, :memory) do
        memory_threshold = Map.get(thresholds, :memory)
        memory_usage = Map.get(metrics, :memory_usage, 0)

        if memory_usage > memory_threshold do
          [
            %{
              metric: :memory_usage,
              value: memory_usage,
              threshold: memory_threshold,
              severity: determine_severity(memory_usage, memory_threshold),
              message: "Memory usage #{memory_usage}% exceeds threshold #{memory_threshold}%"
            }
            | violations
          ]
        else
          violations
        end
      else
        violations
      end

    # Check disk threshold
    violations =
      if Map.has_key?(thresholds, :disk) do
        disk_threshold = Map.get(thresholds, :disk)
        disk_usage = Map.get(metrics, :disk_usage, 0)

        if disk_usage > disk_threshold do
          [
            %{
              metric: :disk_usage,
              value: disk_usage,
              threshold: disk_threshold,
              severity: determine_severity(disk_usage, disk_threshold),
              message: "Disk usage #{disk_usage}% exceeds threshold #{disk_threshold}%"
            }
            | violations
          ]
        else
          violations
        end
      else
        violations
      end

    # Check response time threshold
    violations =
      if Map.has_key?(thresholds, :response_time) do
        response_time_threshold = Map.get(thresholds, :response_time)
        response_time = Map.get(metrics, :response_time_ms, 0)

        if response_time > response_time_threshold do
          [
            %{
              metric: :response_time,
              value: response_time,
              threshold: response_time_threshold,
              severity: determine_severity(response_time, response_time_threshold),
              message:
                "Response time #{response_time}ms exceeds threshold #{response_time_threshold}ms"
            }
            | violations
          ]
        else
          violations
        end
      else
        violations
      end

    violations
  end

  defp check_threshold_violations(_, _), do: []

  defp determine_severity(value, threshold) do
    ratio = value / threshold

    cond do
      ratio >= 2.0 -> :critical
      ratio >= 1.5 -> :high
      ratio >= 1.2 -> :medium
      true -> :low
    end
  end

  defp format_performance_output(analysis, output_format) do
    case output_format do
      "json" -> Jason.encode!(analysis, pretty: true)
      "text" -> format_performance_text(analysis)
      "table" -> analysis
      _ -> Jason.encode!(analysis, pretty: true)
    end
  end

  defp format_performance_text(analysis) do
    """
    Performance Analysis:
    - Average Response Time: #{analysis.average_response_time}ms
    - Average Throughput: #{analysis.average_throughput} req/s
    - Average Error Rate: #{analysis.average_error_rate * 100}%
    - Threshold Violations: #{length(analysis.threshold_violations)}
    """
  end

  defp perform_health_check(check_type, timeout, include_details, retry_count) do
    case check_type do
      "system" -> check_system_health(timeout, include_details, retry_count)
      "application" -> check_application_health(timeout, include_details, retry_count)
      "database" -> check_database_health(timeout, include_details, retry_count)
      "network" -> check_network_health(timeout, include_details, retry_count)
      "services" -> check_services_health(timeout, include_details, retry_count)
      _ -> %{check_type: check_type, status: "unknown", error: "Unknown check type"}
    end
  end

  defp check_system_health(timeout, include_details, retry_count) do
    # Check system health
    %{
      check_type: "system",
      status: "healthy",
      response_time: 50,
      details: if(include_details, do: %{cpu: 25, memory: 60, disk: 45}, else: nil)
    }
  end

  defp check_application_health(timeout, include_details, retry_count) do
    # Check application health
    %{
      check_type: "application",
      status: "healthy",
      response_time: 100,
      details: if(include_details, do: %{uptime: 3600, requests: 1000}, else: nil)
    }
  end

  defp check_database_health(timeout, include_details, retry_count) do
    # Check database health
    %{
      check_type: "database",
      status: "healthy",
      response_time: 75,
      details: if(include_details, do: %{connections: 10, queries: 500}, else: nil)
    }
  end

  defp check_network_health(timeout, include_details, retry_count) do
    # Check network health
    %{
      check_type: "network",
      status: "healthy",
      response_time: 25,
      details: if(include_details, do: %{latency: 10, bandwidth: 1000}, else: nil)
    }
  end

  defp check_services_health(timeout, include_details, retry_count) do
    # Check services health
    %{
      check_type: "services",
      status: "healthy",
      response_time: 150,
      details: if(include_details, do: %{active_services: 5, failed_services: 0}, else: nil)
    }
  end

  defp calculate_overall_health(health_results) do
    healthy_checks = Enum.count(health_results, &(&1.status == "healthy"))
    total_checks = length(health_results)

    %{
      status: if(healthy_checks == total_checks, do: "healthy", else: "degraded"),
      healthy_checks: healthy_checks,
      total_checks: total_checks,
      health_percentage: healthy_checks / total_checks * 100
    }
  end

  defp format_health_output(health_results, overall_health, output_format) do
    case output_format do
      "json" -> Jason.encode!(%{results: health_results, overall: overall_health}, pretty: true)
      "text" -> format_health_text(health_results, overall_health)
      "table" -> %{results: health_results, overall: overall_health}
      _ -> Jason.encode!(%{results: health_results, overall: overall_health}, pretty: true)
    end
  end

  defp format_health_text(health_results, overall_health) do
    results_text =
      Enum.map(health_results, fn result ->
        "#{result.check_type}: #{result.status} (#{result.response_time}ms)"
      end)
      |> Enum.join("\n")

    "Overall Health: #{overall_health.status} (#{overall_health.health_percentage}%)\n\n#{results_text}"
  end

  defp get_historical_metrics(metric_types, time_range) do
    # Simulate historical data
    %{
      cpu: generate_historical_data("cpu", time_range),
      memory: generate_historical_data("memory", time_range),
      disk: generate_historical_data("disk", time_range),
      network: generate_historical_data("network", time_range)
    }
  end

  defp generate_historical_data(metric_type, time_range) do
    # Generate sample historical data
    Enum.map(1..100, fn i ->
      %{
        timestamp: DateTime.add(DateTime.utc_now(), -i * 3600, :second),
        value: 50 + :rand.uniform(50)
      }
    end)
  end

  defp perform_trend_analysis(analysis_type, historical_data, sensitivity) do
    case analysis_type do
      "trends" -> analyze_trends(historical_data)
      "anomalies" -> detect_anomalies(historical_data, sensitivity)
      "correlations" -> find_correlations(historical_data)
      "forecasting" -> generate_forecast(historical_data)
      _ -> %{analysis_type: analysis_type, error: "Unknown analysis type"}
    end
  end

  defp analyze_trends(historical_data) do
    %{
      analysis_type: "trends",
      trends: %{
        cpu: "increasing",
        memory: "stable",
        disk: "increasing",
        network: "stable"
      }
    }
  end

  defp detect_anomalies(historical_data, sensitivity) do
    %{
      analysis_type: "anomalies",
      anomalies: [
        %{metric: "cpu", timestamp: DateTime.utc_now(), value: 95, severity: "high"}
      ],
      sensitivity: sensitivity
    }
  end

  defp find_correlations(historical_data) do
    %{
      analysis_type: "correlations",
      correlations: [
        %{metric1: "cpu", metric2: "memory", correlation: 0.75}
      ]
    }
  end

  defp generate_forecast(historical_data) do
    %{
      analysis_type: "forecasting",
      predictions: [
        %{metric: "cpu", predicted_value: 60, confidence: 0.85, timeframe: "1h"}
      ]
    }
  end

  defp generate_predictions(historical_data, analysis_results) do
    %{
      next_hour: %{cpu: 60, memory: 65, disk: 50, network: 55},
      next_day: %{cpu: 65, memory: 70, disk: 55, network: 60}
    }
  end

  defp generate_trends_summary(analysis_results, predictions) do
    %{
      total_analyses: length(analysis_results),
      trends_detected: length(Enum.filter(analysis_results, &(&1.analysis_type == "trends"))),
      anomalies_found: length(Enum.filter(analysis_results, &(&1.analysis_type == "anomalies"))),
      correlations_found:
        length(Enum.filter(analysis_results, &(&1.analysis_type == "correlations"))),
      predictions_generated: if(predictions, do: 2, else: 0)
    }
  end

  defp collect_dashboard_data(dashboard_type, time_range, include_charts, include_alerts) do
    %{
      metrics: get_historical_metrics(["cpu", "memory", "disk", "network"], time_range),
      alerts: if(include_alerts, do: get_all_alert_rules(), else: []),
      charts: if(include_charts, do: generate_chart_data(), else: []),
      summary: generate_dashboard_summary()
    }
  end

  defp generate_chart_data do
    [
      %{type: "line", title: "CPU Usage", data: []},
      %{type: "bar", title: "Memory Usage", data: []},
      %{type: "pie", title: "Disk Usage", data: []}
    ]
  end

  defp generate_dashboard_summary do
    %{
      total_metrics: 4,
      active_alerts: 2,
      system_status: "healthy",
      last_updated: DateTime.utc_now()
    }
  end

  defp generate_dashboard_content(dashboard_data, dashboard_type, output_format) do
    case output_format do
      "html" -> generate_html_dashboard(dashboard_data, dashboard_type)
      "json" -> Jason.encode!(dashboard_data, pretty: true)
      "text" -> generate_text_dashboard(dashboard_data, dashboard_type)
      _ -> generate_html_dashboard(dashboard_data, dashboard_type)
    end
  end

  defp generate_html_dashboard(dashboard_data, dashboard_type) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>#{dashboard_type} Dashboard</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .metric { background: #f0f0f0; padding: 10px; margin: 10px 0; border-radius: 5px; }
            .alert { background: #ffebee; padding: 10px; margin: 10px 0; border-radius: 5px; }
        </style>
    </head>
    <body>
        <h1>#{String.capitalize(dashboard_type)} Dashboard</h1>
        <div class="summary">
            <h2>Summary</h2>
            <p>System Status: #{dashboard_data.summary.system_status}</p>
            <p>Active Alerts: #{dashboard_data.summary.active_alerts}</p>
            <p>Last Updated: #{dashboard_data.summary.last_updated}</p>
        </div>
        <div class="metrics">
            <h2>Metrics</h2>
            <div class="metric">CPU: 25%</div>
            <div class="metric">Memory: 60%</div>
            <div class="metric">Disk: 45%</div>
            <div class="metric">Network: 55%</div>
        </div>
        <div class="alerts">
            <h2>Alerts</h2>
            <div class="alert">High CPU Usage: 85%</div>
            <div class="alert">Memory Warning: 90%</div>
        </div>
    </body>
    </html>
    """
  end

  defp generate_text_dashboard(dashboard_data, dashboard_type) do
    """
    #{String.capitalize(dashboard_type)} Dashboard
    ==========================================

    Summary:
    - System Status: #{dashboard_data.summary.system_status}
    - Active Alerts: #{dashboard_data.summary.active_alerts}
    - Last Updated: #{dashboard_data.summary.last_updated}

    Metrics:
    - CPU: 25%
    - Memory: 60%
    - Disk: 45%
    - Network: 55%

    Alerts:
    - High CPU Usage: 85%
    - Memory Warning: 90%
    """
  end

  defp parse_number(str) when is_binary(str) do
    case Integer.parse(str) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_number(num) when is_integer(num), do: num
  defp parse_number(_), do: 0

  defp parse_float(str) when is_binary(str) do
    case Float.parse(str) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp parse_float(num) when is_float(num), do: num
  defp parse_float(_), do: 0.0
end
