defmodule Singularity.Monitoring.CodeEngineHealthTracker do
  @moduledoc """
  CodeEngine Health Tracker - Monitors CodeEngine performance and fallback scenarios.

  Tracks CodeEngine analysis failures, fallback usage, and provides data for
  self-improvement systems to enhance CodeEngine integration.

  ## What it tracks:
  - CodeEngine analysis success/failure rates
  - Fallback usage (degraded_fallback scenarios)
  - Language-specific performance
  - File type analysis patterns
  - Performance degradation over time

  ## Integration with Evolution:
  The evolution system can use this data to:
  - Detect when CodeEngine integration needs improvement
  - Measure impact of CodeEngine fixes
  - Prioritize languages/files with high fallback rates
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record a successful CodeEngine analysis.
  """
  def record_success(language, file_path, analysis_time_ms) do
    GenServer.cast(__MODULE__, {:success, language, file_path, analysis_time_ms})
  end

  @doc """
  Record a CodeEngine analysis failure with fallback.
  """
  def record_fallback(language, file_path, error_reason) do
    GenServer.cast(__MODULE__, {:fallback, language, file_path, error_reason})
  end

  @doc """
  Record a complete CodeEngine failure (no fallback).
  """
  def record_failure(language, file_path, error_reason) do
    GenServer.cast(__MODULE__, {:failure, language, file_path, error_reason})
  end

  @doc """
  Get current health metrics.
  """
  def get_health_report do
    GenServer.call(__MODULE__, :get_health_report)
  end

  @doc """
  Check if a language has acceptable CodeEngine performance.
  """
  def is_language_healthy(language) do
    report = get_health_report()
    lang_stats = report.language_stats[language] || %{}

    success_rate = lang_stats.success_rate || 0.0
    fallback_rate = lang_stats.fallback_rate || 0.0

    # Consider healthy if > 80% success rate and < 20% fallback rate
    success_rate > 0.8 and fallback_rate < 0.2
  end

  # Server Implementation

  @impl true
  def init(_opts) do
    Logger.info("[CodeEngineHealth] Starting CodeEngine health tracker")

    state = %{
      total_analyses: 0,
      successful_analyses: 0,
      fallback_analyses: 0,
      failed_analyses: 0,
      language_stats: %{},
      # Keep last 100 errors
      recent_errors: [],
      start_time: DateTime.utc_now()
    }

    # Schedule periodic health reporting
    # Every 5 minutes
    Process.send_after(self(), :report_health, 300_000)

    {:ok, state}
  end

  @impl true
  def handle_cast({:success, language, file_path, analysis_time_ms}, state) do
    Logger.debug("[CodeEngineHealth] Success: #{language} #{file_path} (#{analysis_time_ms}ms)")

    new_state =
      state
      |> update_counter(:total_analyses)
      |> update_counter(:successful_analyses)
      |> update_language_stats(language, :success, analysis_time_ms)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:fallback, language, file_path, error_reason}, state) do
    Logger.warning(
      "[CodeEngineHealth] ⚠️ Fallback used: #{language} #{file_path} - #{error_reason}"
    )

    new_state =
      state
      |> update_counter(:total_analyses)
      |> update_counter(:fallback_analyses)
      |> update_language_stats(language, :fallback, error_reason)
      |> add_recent_error(language, file_path, error_reason, :fallback)

    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:failure, language, file_path, error_reason}, state) do
    SASL.critical_failure(
      :code_engine_complete_failure,
      "CodeEngine complete failure - no analysis possible",
      language: language,
      file_path: file_path,
      error_reason: error_reason
    )

    new_state =
      state
      |> update_counter(:total_analyses)
      |> update_counter(:failed_analyses)
      |> update_language_stats(language, :failure, error_reason)
      |> add_recent_error(language, file_path, error_reason, :failure)

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_health_report, _from, state) do
    report = %{
      total_analyses: state.total_analyses,
      successful_analyses: state.successful_analyses,
      fallback_analyses: state.fallback_analyses,
      failed_analyses: state.failed_analyses,
      success_rate: calculate_rate(state.successful_analyses, state.total_analyses),
      fallback_rate: calculate_rate(state.fallback_analyses, state.total_analyses),
      failure_rate: calculate_rate(state.failed_analyses, state.total_analyses),
      language_stats: state.language_stats,
      # Last 10 errors
      recent_errors: Enum.take(state.recent_errors, 10),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.start_time),
      health_score: calculate_health_score(state)
    }

    {:reply, report, state}
  end

  @impl true
  def handle_info(:report_health, state) do
    report = get_health_report()

    # Log health summary
    Logger.info("[CodeEngineHealth] 📊 Health Report:")
    Logger.info("  Total analyses: #{report.total_analyses}")
    Logger.info("  Success rate: #{Float.round(report.success_rate * 100, 1)}%")
    Logger.info("  Fallback rate: #{Float.round(report.fallback_rate * 100, 1)}%")
    Logger.info("  Failure rate: #{Float.round(report.failure_rate * 100, 1)}%")
    Logger.info("  Health score: #{Float.round(report.health_score, 2)}/10")

    # Warn if health is poor
    if report.health_score < 7.0 do
      Logger.warning("[CodeEngineHealth] 🚨 Poor CodeEngine health detected!")
      Logger.warning("  Consider improving CodeEngine integration or fallback strategies")
    end

    # Schedule next report
    Process.send_after(self(), :report_health, 300_000)

    {:noreply, state}
  end

  # Helper Functions

  defp update_counter(state, counter_key) do
    Map.update!(state, counter_key, &(&1 + 1))
  end

  defp update_language_stats(state, language, event_type, data) do
    lang_stats =
      state.language_stats[language] || %{success: 0, fallback: 0, failure: 0, total: 0}

    new_lang_stats =
      lang_stats
      |> Map.update!(:total, &(&1 + 1))
      |> Map.update!(event_type, &(&1 + 1))

    # Calculate rates
    new_lang_stats =
      new_lang_stats
      |> Map.put(:success_rate, lang_stats.success / new_lang_stats.total)
      |> Map.put(:fallback_rate, lang_stats.fallback / new_lang_stats.total)
      |> Map.put(:failure_rate, lang_stats.failure / new_lang_stats.total)

    put_in(state.language_stats[language], new_lang_stats)
  end

  defp add_recent_error(state, language, file_path, error_reason, error_type) do
    error = %{
      timestamp: DateTime.utc_now(),
      language: language,
      file_path: file_path,
      error_reason: error_reason,
      error_type: error_type
    }

    # Keep last 100
    new_errors = [error | state.recent_errors] |> Enum.take(100)
    %{state | recent_errors: new_errors}
  end

  defp calculate_rate(numerator, denominator) when denominator > 0 do
    numerator / denominator
  end

  defp calculate_rate(_numerator, _denominator) do
    0.0
  end

  defp calculate_health_score(state) do
    if state.total_analyses == 0 do
      # Perfect score if no analyses yet
      10.0
    else
      success_weight = 0.6
      fallback_penalty = 0.3
      failure_penalty = 0.1

      success_score = state.successful_analyses / state.total_analyses * success_weight
      fallback_score = (1 - state.fallback_analyses / state.total_analyses) * fallback_penalty
      failure_score = (1 - state.failed_analyses / state.total_analyses) * failure_penalty

      (success_score + fallback_score + failure_score) * 10
    end
  end
end
