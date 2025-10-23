defmodule Genesis.StructuredLogger do
  @moduledoc """
  Genesis Structured Logger

  Provides structured logging for experiments with contextual metadata
  to enable better tracking, filtering, and analysis of experiment execution.

  ## Structured Logging Context

  All logs include experiment-level metadata:
  - experiment_id: Unique identifier for the experiment
  - instance_id: Source Singularity instance
  - user_id: (Optional) User requesting the experiment
  - risk_level: Risk level (low/medium/high)
  - timestamp: When the log entry was created

  ## Usage

      alias Genesis.StructuredLogger, as: Log

      # Basic structured log
      Log.info("Experiment started", experiment_id: "exp-123", instance_id: "prod-1")

      # With risk level context
      Log.experiment_start(experiment_id, instance_id, risk_level)

      # Track progress
      Log.experiment_progress(experiment_id, stage: :validation, progress: 50)

      # Report results
      Log.experiment_complete(experiment_id, success: true, metrics: %{...})

  ## Benefits

  1. **Correlation** - Link related logs via experiment_id
  2. **Filtering** - Search logs by experiment, instance, or risk level
  3. **Analysis** - Calculate success rates, avg duration per experiment type
  4. **Debugging** - Rich context for troubleshooting failures
  5. **Metrics** - Track experiment lifecycle stages
  """

  require Logger

  @doc """
  Log experiment start with full context.
  """
  def experiment_start(experiment_id, instance_id, risk_level) do
    Logger.info(
      "Experiment started",
      experiment_id: experiment_id,
      instance_id: instance_id,
      risk_level: risk_level,
      stage: :initialization
    )
  end

  @doc """
  Log experiment progress through various stages.
  """
  def experiment_progress(experiment_id, opts) do
    stage = Keyword.get(opts, :stage, :unknown)
    progress = Keyword.get(opts, :progress, 0)

    Logger.debug(
      "Experiment progress",
      experiment_id: experiment_id,
      stage: stage,
      progress: progress
    )
  end

  @doc """
  Log sandbox creation.
  """
  def sandbox_created(experiment_id, sandbox_path) do
    Logger.debug(
      "Sandbox created",
      experiment_id: experiment_id,
      sandbox_path: sandbox_path
    )
  end

  @doc """
  Log changes applied to sandbox.
  """
  def changes_applied(experiment_id, files_modified, description) do
    Logger.info(
      "Changes applied to sandbox",
      experiment_id: experiment_id,
      files_modified: length(files_modified),
      description: description
    )
  end

  @doc """
  Log test execution completion.
  """
  def tests_completed(experiment_id, opts) do
    success_rate = Keyword.get(opts, :success_rate, 0.0)
    total_tests = Keyword.get(opts, :total_tests, 0)
    failures = Keyword.get(opts, :failures, 0)
    runtime_ms = Keyword.get(opts, :runtime_ms, 0)

    Logger.info(
      "Tests completed",
      experiment_id: experiment_id,
      success_rate: Float.round(success_rate, 3),
      total_tests: total_tests,
      failures: failures,
      runtime_ms: runtime_ms
    )
  end

  @doc """
  Log metrics measurement completion.
  """
  def metrics_measured(experiment_id, metrics) do
    Logger.info(
      "Metrics measured",
      experiment_id: experiment_id,
      success_rate: Float.round(metrics[:success_rate] || 0.0, 3),
      regression: Float.round(metrics[:regression] || 0.0, 3),
      llm_reduction: Float.round(metrics[:llm_reduction] || 0.0, 3),
      runtime_ms: metrics[:runtime_ms] || 0
    )
  end

  @doc """
  Log experiment recommendation and completion.
  """
  def experiment_complete(experiment_id, opts) do
    success = Keyword.get(opts, :success, false)
    recommendation = Keyword.get(opts, :recommendation, :unknown)
    metrics = Keyword.get(opts, :metrics, %{})

    Logger.info(
      "Experiment completed",
      experiment_id: experiment_id,
      success: success,
      recommendation: recommendation,
      success_rate: Float.round(metrics[:success_rate] || 0.0, 3),
      llm_reduction: Float.round(metrics[:llm_reduction] || 0.0, 3),
      regression: Float.round(metrics[:regression] || 0.0, 3)
    )
  end

  @doc """
  Log experiment failure with error context.
  """
  def experiment_failed(experiment_id, reason, opts \\ []) do
    stage = Keyword.get(opts, :stage, :unknown)
    context = Keyword.get(opts, :context, "")

    Logger.error(
      "Experiment failed",
      experiment_id: experiment_id,
      reason: inspect(reason),
      stage: stage,
      context: context
    )
  end

  @doc """
  Log timeout event.
  """
  def experiment_timeout(experiment_id, timeout_ms, stage) do
    Logger.error(
      "Experiment timeout",
      experiment_id: experiment_id,
      timeout_ms: timeout_ms,
      stage: stage
    )
  end

  @doc """
  Log rollback operation.
  """
  def rollback_initiated(experiment_id, reason) do
    Logger.warn(
      "Rollback initiated",
      experiment_id: experiment_id,
      reason: inspect(reason)
    )
  end

  @doc """
  Log metrics reported to CentralCloud.
  """
  def metrics_reported(source, count, destination) do
    Logger.info(
      "Metrics reported",
      source: source,
      metric_count: count,
      destination: destination
    )
  end

  @doc """
  Log connection status changes.
  """
  def connection_status(service, status, details \\ "") do
    Logger.info(
      "Connection status",
      service: service,
      status: status,
      details: details
    )
  end

  @doc """
  Log sandbox maintenance operations.
  """
  def sandbox_maintenance(operation, details) do
    Logger.info(
      "Sandbox maintenance",
      operation: operation,
      details: details
    )
  end

  @doc """
  Log trend analysis results.
  """
  def trend_analysis_complete(total_experiments, success_rate, by_type) do
    Logger.info(
      "Trend analysis complete",
      total_experiments: total_experiments,
      success_rate: Float.round(success_rate, 3),
      experiment_types: map_size(by_type)
    )
  end
end
