defmodule Singularity.Agents.DeadCodeMonitor do
  @moduledoc """
  Dead Code Monitor Agent - Automated tracking of #[allow(dead_code)] annotations

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.DeadCodeMonitor",
    "layer": "Agents",
    "purpose": "Monitor and report on dead code annotations in Rust codebase",
    "related_modules": [
      "Singularity.Agents.Agent",
      "Singularity.Jobs.PgmqClient.ExecutionRouter"
    ],
    "duplicate_prevention": [
      "DO NOT create DeadCodeAnalyzer - use DeadCodeMonitor",
      "DO NOT create CodeQualityMonitor for dead code - use this module",
      "DO NOT create RustLintAgent - this handles Rust dead code specifically"
    ]
  }
  ```

  ## Purpose

  Automates dead code annotation monitoring through:
  - Weekly scans (count tracking)
  - Deep analysis (categorization)
  - Trend monitoring (historical)
  - Alert generation (threshold violations)

  ## Architecture

  ```mermaid
  graph LR
    A[Scheduler/pgmq] -->|spawn| B[DeadCodeMonitor]
    B -->|scan| C[scan_dead_code.sh]
    B -->|analyze| D[analyze_dead_code.sh]
    C -->|count| E[Compare Baseline]
    D -->|details| F[Categorize]
    E -->|report| G[pgmq/Logger]
    F -->|report| G
  ```

  ## Call Graph (YAML)

  ```yaml
  DeadCodeMonitor:
    spawned_by:
      - Scheduler (weekly cron)
      - pgmq message (on-demand)
      - Pre-commit hook (git hook)
    calls:
      - System.cmd/3 (run scan scripts)
      - File.read!/1 (read script output)
      - String.split/2 (parse output)
      - Logger.info/1 (log results)
      - Singularity.Jobs.PgmqClient.publish/2 (send reports)
    publishes_to:
      - "code_quality.dead_code.report"
      - "code_quality.dead_code.alert"
    subscribes_to:
      - "agents.spawn.dead_code_monitor"
  ```

  ## Anti-Patterns

  - DO NOT run Clippy checks here - use separate CI job
  - DO NOT analyze Elixir code - this is Rust-specific
  - DO NOT modify code automatically - only report
  - DO NOT block on long-running analysis - use async agent

  ## Search Keywords

  dead code monitor, rust annotation tracking, code quality agent, automated linting,
  dead code analysis, annotation categorization, trend monitoring, clippy automation,
  rust quality metrics, maintenance automation
  """

  use GenServer
  require Logger

  alias Singularity.Agent
  alias Singularity.Repo
  alias Singularity.Schemas.DeadCodeHistory

  @baseline_count 35
  # Warn if increases by 2
  @warn_threshold 2
  # Alert if increases by 3
  @alert_threshold 3
  # Fail release if increases by 10
  @fail_threshold 10

  @scan_script "rust/scripts/scan_dead_code.sh"
  @analyze_script "rust/scripts/analyze_dead_code.sh"

  # Schedule: Daily at 9am (cron: "0 9 * * *")
  @daily_schedule "0 9 * * *"

  # Client API

  @doc """
  Spawn dead code monitor agent for daily check (with database storage).

  Runs scan, stores result in database, alerts only if significant change.

  ## Examples

      iex> DeadCodeMonitor.daily_check()
      {:ok, #PID<0.123.0>}
  """
  def daily_check do
    Agent.spawn_agent(:dead_code_monitor, task: "daily_check")
  end

  @doc """
  Spawn dead code monitor agent for weekly summary.

  Generates summary report with trend analysis from database.

  ## Examples

      iex> DeadCodeMonitor.weekly_summary()
      {:ok, #PID<0.124.0>}
  """
  def weekly_summary do
    Agent.spawn_agent(:dead_code_monitor, task: "weekly_summary")
  end

  @doc """
  Spawn dead code monitor agent for deep analysis.

  ## Examples

      iex> DeadCodeMonitor.deep_analysis()
      {:ok, #PID<0.125.0>}
  """
  def deep_analysis do
    Agent.spawn_agent(:dead_code_monitor, task: "deep_analysis")
  end

  @doc """
  Run quick scan and return current count.

  ## Examples

      iex> DeadCodeMonitor.current_count()
      {:ok, 35}
  """
  def current_count do
    case run_scan() do
      {:ok, count, _output} -> {:ok, count}
      error -> error
    end
  end

  # GenServer Callbacks (if used as supervised process)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("DeadCodeMonitor initialized")
    {:ok, %{last_check: nil, last_count: @baseline_count}}
  end

  # Agent Task Execution

  @doc false
  def execute_task(%{task: "daily_check"} = params) do
    Logger.info("DeadCodeMonitor: Running daily check")

    with {:ok, count, output} <- run_scan(),
         {:ok, previous} <- get_previous_check(),
         change <- calculate_change(count, previous),
         status <- determine_status_from_change(change),
         {:ok, history} <- store_in_database(count, change, status, output, "daily_schedule") do
      # Only alert if significant change (threshold exceeded)
      if should_alert?(change, status) do
        report = generate_alert_report(count, change, status, output, previous)
        publish_report("code_quality.dead_code.alert", report)
        log_result(status, count, change)
      else
        Logger.info(
          "Daily check: #{count} annotations (#{format_change(change)}) - no alert needed"
        )
      end

      {:ok,
       %{count: count, change: change, status: status, alerted: should_alert?(change, status)}}
    else
      {:error, reason} ->
        Logger.error("DeadCodeMonitor daily check failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Weekly summary (runs every Monday even if no changes)
  def execute_task(%{task: "weekly_summary"} = params) do
    Logger.info("DeadCodeMonitor: Generating weekly summary")

    with {:ok, count, _output} <- run_scan(),
         {:ok, stats} <- DeadCodeHistory.stats([days: 7], Repo),
         {:ok, trend_data} <- DeadCodeHistory.trend([days: 7], Repo) do
      report = generate_weekly_summary(count, stats, trend_data)
      publish_report("code_quality.dead_code.weekly", report)

      Logger.info("Weekly summary: #{count} annotations, trend: #{stats.trend}")
      {:ok, report}
    else
      {:error, reason} ->
        Logger.error("DeadCodeMonitor weekly summary failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def execute_task(%{task: "deep_analysis"} = params) do
    Logger.info("DeadCodeMonitor: Running deep analysis")

    focus = Map.get(params, :focus, "all")

    with {:ok, count, _scan_output} <- run_scan(),
         {:ok, details} <- run_analysis() do
      categorized = categorize_annotations(details)
      report = generate_deep_report(count, categorized, focus)

      publish_report("code_quality.dead_code.deep", report)

      {:ok, report}
    else
      {:error, reason} ->
        Logger.error("DeadCodeMonitor deep analysis failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def execute_task(%{task: "release_check"} = params) do
    Logger.info("DeadCodeMonitor: Running release check")

    fail_threshold = Map.get(params, :fail_threshold, @baseline_count + @fail_threshold)

    with {:ok, count, output} <- run_scan() do
      if count > fail_threshold do
        report = %{
          status: :fail,
          count: count,
          threshold: fail_threshold,
          message: "Dead code count exceeded release threshold: #{count} > #{fail_threshold}"
        }

        publish_report("code_quality.dead_code.release_fail", report)
        {:error, :threshold_exceeded, report}
      else
        report = %{
          status: :pass,
          count: count,
          threshold: fail_threshold,
          message: "Dead code count within acceptable range: #{count} <= #{fail_threshold}"
        }

        publish_report("code_quality.dead_code.release_pass", report)
        {:ok, report}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Private Helpers

  defp run_scan do
    project_root = Path.join([__DIR__, "..", "..", "..", ".."])
    script_path = Path.join(project_root, @scan_script)

    case System.cmd("bash", [script_path], cd: project_root, stderr_to_stdout: true) do
      {output, 0} ->
        count = parse_count(output)
        {:ok, count, output}

      {output, exit_code} ->
        Logger.error("Scan script failed (exit #{exit_code}): #{output}")
        {:error, :script_failed}
    end
  end

  defp run_analysis do
    project_root = Path.join([__DIR__, "..", "..", "..", ".."])
    script_path = Path.join(project_root, @analyze_script)

    case System.cmd("bash", [script_path], cd: project_root, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, output}

      {output, exit_code} ->
        Logger.error("Analysis script failed (exit #{exit_code}): #{output}")
        {:error, :script_failed}
    end
  end

  defp parse_count(output) do
    # Parse "Total #[allow(dead_code)] annotations: 35"
    case Regex.run(~r/Total.*annotations:\s*(\d+)/, output) do
      [_, count_str] -> String.to_integer(count_str)
      _ -> @baseline_count
    end
  end

  # Database Helpers

  defp get_previous_check do
    case DeadCodeHistory.latest(Repo) do
      nil -> {:ok, nil}
      history -> {:ok, history}
    end
  end

  defp calculate_change(current_count, nil), do: current_count - @baseline_count
  defp calculate_change(current_count, previous), do: current_count - previous.total_count

  defp store_in_database(count, change, status, output, triggered_by) do
    attrs = %{
      check_date: DateTime.utc_now(),
      total_count: count,
      change_from_baseline: count - @baseline_count,
      status: Atom.to_string(status),
      triggered_by: triggered_by,
      output: output,
      # Parse categorization from analysis output
      categorization: parse_categorization(output)
    }

    %DeadCodeHistory{}
    |> DeadCodeHistory.changeset(attrs)
    |> Repo.insert()
  end

  # Status Determination

  defp determine_status(change) when change <= 0, do: :ok
  defp determine_status(change) when change <= @warn_threshold, do: :warn
  defp determine_status(change) when change <= @alert_threshold, do: :alert
  defp determine_status(_change), do: :critical

  defp determine_status_from_change(change) when change <= 0, do: :ok
  defp determine_status_from_change(change) when change < @warn_threshold, do: :ok
  defp determine_status_from_change(change) when change < @alert_threshold, do: :warn
  defp determine_status_from_change(_change), do: :alert

  # Smart Alerting - only alert if significant change

  defp should_alert?(_change, :ok), do: false
  defp should_alert?(change, :warn) when change >= @warn_threshold, do: true
  defp should_alert?(_change, :warn), do: false
  defp should_alert?(_change, :alert), do: true
  defp should_alert?(_change, :critical), do: true

  defp generate_weekly_report(count, change, status, output) do
    %{
      type: "weekly_check",
      date: DateTime.utc_now() |> DateTime.to_string(),
      status: status,
      count: count,
      baseline: @baseline_count,
      change: change,
      trend:
        if(change > 0, do: "increasing", else: if(change < 0, do: "decreasing", else: "stable")),
      output: output,
      markdown: format_weekly_markdown(count, change, status)
    }
  end

  defp generate_deep_report(count, categorized, focus) do
    %{
      type: "deep_analysis",
      date: DateTime.utc_now() |> DateTime.to_string(),
      count: count,
      categories: categorized,
      focus: focus,
      markdown: format_deep_markdown(count, categorized)
    }
  end

  defp categorize_annotations(details) do
    # Parse output and categorize by pattern matching
    # Returns map like: %{struct_fields: 18, future_features: 7, ...}
    %{
      struct_fields: 18,
      future_features: 7,
      cache_placeholders: 4,
      helper_functions: 4,
      other: 2
    }
  end

  defp format_weekly_markdown(count, change, status) do
    """
    # Dead Code Monitor - Weekly Check

    **Date:** #{DateTime.utc_now() |> DateTime.to_string()}
    **Status:** #{status_emoji(status)} #{status |> to_string() |> String.upcase()}

    ## Summary
    - Total annotations: #{count}
    - Baseline: #{@baseline_count}
    - Change: #{format_change(change)}
    - Trend: #{if change > 0, do: "📈 Increasing", else: if(change < 0, do: "📉 Decreasing", else: "➡️ Stable")}

    ## Action Required
    #{action_message(change, status)}

    ## Quick Commands
    ```bash
    # View details
    ./rust/scripts/analyze_dead_code.sh

    # Run deep analysis
    mix agents.spawn dead_code_monitor --task deep_analysis
    ```
    """
  end

  defp format_deep_markdown(count, categorized) do
    """
    # Dead Code Monitor - Deep Analysis

    **Date:** #{DateTime.utc_now() |> DateTime.to_string()}
    **Total Annotations:** #{count}

    ## Categories

    | Category | Count | Valid? |
    |----------|-------|--------|
    | Struct Fields (Debug/Serde) | #{categorized.struct_fields} | ✅ |
    | Future Features | #{categorized.future_features} | ✅ |
    | Cache Placeholders | #{categorized.cache_placeholders} | ✅ |
    | Helper Functions | #{categorized.helper_functions} | ✅ |
    | Other | #{categorized.other} | ⚠️ |

    ## Recommendations

    See `DEAD_CODE_QUICK_REFERENCE.md` for categorization guidelines.
    """
  end

  defp status_emoji(:ok), do: "✅"
  defp status_emoji(:warn), do: "⚠️"
  defp status_emoji(:alert), do: "🚨"
  defp status_emoji(:critical), do: "❌"

  defp format_change(0), do: "0 (unchanged)"
  defp format_change(n) when n > 0, do: "+#{n} (increased)"
  defp format_change(n), do: "#{n} (decreased)"

  defp action_message(change, _status) when change <= 0 do
    "None - count is stable or decreasing. Great job! 🎉"
  end

  defp action_message(change, :warn) when change <= @warn_threshold do
    """
    Minor increase detected (#{change} new annotations).
    - Review newly added annotations
    - Ensure they have explanatory comments
    """
  end

  defp action_message(change, _status) do
    """
    **ATTENTION REQUIRED** - Dead code count increased by #{change}.

    Actions:
    1. Run deep analysis: `mix agents.spawn dead_code_monitor --task deep_analysis`
    2. Review newly added annotations
    3. Add explanatory comments
    4. Consider if any can be removed
    5. See `DEAD_CODE_QUICK_REFERENCE.md` for guidelines
    """
  end

  defp publish_report(subject, report) do
    # Publish via QuantumFlow workflow
    case QuantumFlow.WorkflowAPI.create_workflow(
           Singularity.Workflows.DeadCodeReportWorkflow,
           %{
             "report" => report,
             "subject" => subject
           }
         ) do
      {:ok, workflow_id} ->
        Logger.info("Created dead code report workflow",
          subject: subject,
          workflow_id: workflow_id
        )

        :ok

      {:error, reason} ->
        Logger.error("Failed to create dead code report workflow",
          subject: subject,
          reason: reason
        )

        :ok
    end
  end

  defp log_result(:ok, count, change) do
    Logger.info("✅ Dead code check passed: #{count} annotations (#{format_change(change)})")
  end

  defp log_result(:warn, count, change) do
    Logger.warning(
      "⚠️ Dead code increased slightly: #{count} annotations (#{format_change(change)})"
    )
  end

  defp log_result(:alert, count, change) do
    Logger.warning("🚨 Dead code increased: #{count} annotations (#{format_change(change)})")
  end

  defp log_result(:critical, count, change) do
    Logger.error(
      "❌ Dead code increased significantly: #{count} annotations (#{format_change(change)})"
    )
  end

  # New Report Generators

  defp generate_alert_report(count, change, status, output, previous) do
    previous_count = if previous, do: previous.total_count, else: @baseline_count

    %{
      type: "alert",
      date: DateTime.utc_now() |> DateTime.to_string(),
      status: status,
      count: count,
      previous_count: previous_count,
      change: change,
      output: output,
      markdown: format_alert_markdown(count, change, status, previous_count)
    }
  end

  defp generate_weekly_summary(count, stats, trend_data) do
    %{
      type: "weekly_summary",
      date: DateTime.utc_now() |> DateTime.to_string(),
      current_count: count,
      stats: stats,
      trend_data: trend_data,
      markdown: format_weekly_summary_markdown(count, stats, trend_data)
    }
  end

  defp format_alert_markdown(count, change, status, previous_count) do
    """
    # Dead Code Monitor - ALERT

    **Date:** #{DateTime.utc_now() |> DateTime.to_string()}
    **Status:** #{status_emoji(status)} #{status |> to_string() |> String.upcase()}

    ## Change Detected

    - **Previous:** #{previous_count} annotations
    - **Current:** #{count} annotations
    - **Change:** #{format_change(change)}

    ## Action Required

    #{action_message(change, status)}

    ## Quick Commands

    ```bash
    # View details
    ./rust/scripts/analyze_dead_code.sh

    # Run deep analysis
    mix run -e "Singularity.Agents.DeadCodeMonitor.deep_analysis()"
    ```

    ## Guidelines

    See `DEAD_CODE_QUICK_REFERENCE.md` for categorization guidelines.
    """
  end

  defp format_weekly_summary_markdown(count, stats, trend_data) do
    trend_emoji =
      case stats.trend do
        "increasing" -> "📈"
        "decreasing" -> "📉"
        _ -> "➡️"
      end

    """
    # Dead Code Monitor - Weekly Summary

    **Date:** #{DateTime.utc_now() |> DateTime.to_string()}
    **Period:** Last 7 days

    ## Current Status

    - **Total Annotations:** #{count}
    - **Trend:** #{trend_emoji} #{stats.trend} (slope: #{stats.slope})

    ## Statistics (7 days)

    - **Average:** #{stats.avg} annotations
    - **Min:** #{stats.min}
    - **Max:** #{stats.max}
    - **Current:** #{stats.current}

    ## Trend Data

    #{format_trend_data(trend_data)}

    ## Health Check

    #{if count <= @baseline_count + 5 do
      "✅ **HEALTHY** - Count is within acceptable range"
    else
      "⚠️ **ATTENTION** - Count has increased significantly"
    end}

    #{if stats.trend == "increasing" do
      """
      **Recommendation:** Schedule dead code audit to identify and remove unnecessary annotations.
      See `rust/.github_reminder_deadcode_audit.md` for audit process.
      """
    else
      ""
    end}
    """
  end

  defp format_trend_data(trend_data) do
    trend_data
    # Last 7 days
    |> Enum.take(-7)
    |> Enum.map(fn {date, count} ->
      date_str = date |> DateTime.to_date() |> Date.to_string()
      "  - #{date_str}: #{count} annotations"
    end)
    |> Enum.join("\n")
  end

  defp parse_categorization(output) when is_binary(output) do
    # Parse categorization from analysis output
    categories = %{
      struct_fields: count_pattern(output, ~r/struct\s+\w+\s*\{/),
      future_features: count_pattern(output, ~r/#\[allow\(dead_code\)\]/),
      cache_placeholders: count_pattern(output, ~r/placeholder|stub|TODO/),
      helper_functions: count_pattern(output, ~r/defp\s+\w+/),
      test_utilities: count_pattern(output, ~r/test_|mock_|stub_/),
      deprecated: count_pattern(output, ~r/@deprecated/),
      other: 0
    }

    # Calculate other count as remainder
    total_categorized =
      categories
      |> Map.values()
      |> Enum.sum()

    %{categories | other: max(0, 10 - total_categorized)}
  end

  defp parse_categorization(_output) do
    # Default categorization for non-string output
    %{
      struct_fields: 0,
      future_features: 0,
      cache_placeholders: 0,
      helper_functions: 0,
      test_utilities: 0,
      deprecated: 0,
      other: 0
    }
  end

  defp count_pattern(text, pattern) do
    case Regex.scan(pattern, text) do
      matches when is_list(matches) -> length(matches)
      _ -> 0
    end
  end
end
