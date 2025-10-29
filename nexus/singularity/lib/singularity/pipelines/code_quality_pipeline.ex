defmodule Singularity.Pipelines.CodeQualityPipeline do
  @moduledoc """
  Broadway Pipeline for Code Quality Analysis and Training

  Supports dual modes:
  - Broadway mode: Uses Broadway.DummyProducer for simple in-memory processing
  - PGFlow mode: Uses Broadway.PgflowProducer for durable, orchestrated processing

  Mode is determined by PGFLOW_CODE_QUALITY_ENABLED environment variable.
  """

  use Broadway

  require Logger

  alias Broadway.Message
  alias Singularity.Workflows.CodeQualityTrainingWorkflow

  @doc """
  Start the code quality Broadway pipeline with appropriate producer based on environment
  """
  def start_link(opts \\ []) do
    # Determine which producer to use based on environment variable
    producer_config = build_producer_config()

    pipeline_config = [
      name: __MODULE__,
      producer: producer_config,
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        quality_analysis: [concurrency: 2, batch_size: 10],
        training_data: [concurrency: 1, batch_size: 5]
      ]
    ]

    Broadway.start_link(__MODULE__, pipeline_config)
  end

  @doc """
  Build producer configuration based on PGFlow mode setting
  """
  def build_producer_config do
    pgflow_enabled = Singularity.Settings.get_boolean("pipelines.code_quality.enabled", false)

    if pgflow_enabled do
      Logger.info("CodeQualityPipeline: Starting in PGFlow mode")
      [
        module: {Broadway.PgflowProducer, [
          workflow_name: "code_quality_training_producer",
          queue_name: "code_quality_jobs",
          concurrency: 2,
          batch_size: 10,
          pgflow_config: [timeout_ms: 300_000, retries: 3],
          resource_hints: [cpu_cores: 4]
        ]},
        concurrency: 2
      ]
    else
      Logger.info("CodeQualityPipeline: Starting in Broadway mode")
      [
        module: {Broadway.DummyProducer, []},
        concurrency: 1
      ]
    end
  end

  @impl Broadway
  def handle_message(:default, %Message{data: data} = message, _context) do
    Logger.debug("CodeQualityPipeline: Processing message", message_id: message.metadata.message_id)

    # Analyze code quality
    case analyze_code_quality(data) do
      {:ok, quality_metrics} ->
        message
        |> Message.put_data(%{original: data, quality_metrics: quality_metrics})
        |> Message.put_batcher(:quality_analysis)

      {:error, reason} ->
        Logger.error("CodeQualityPipeline: Quality analysis failed", error: reason)
        Message.failed(message, reason)
    end
  end

  @impl Broadway
  def handle_batch(:quality_analysis, messages, _batch_info, _context) do
    Logger.info("CodeQualityPipeline: Processing quality analysis batch", batch_size: length(messages))

    # Process quality metrics and prepare for training if needed
    processed_messages = Enum.map(messages, fn message ->
      %{quality_metrics: metrics} = message.data

      # Determine if this should trigger training
      should_train = should_trigger_training?(metrics)

      if should_train do
        Message.put_batcher(message, :training_data)
      else
        message
      end
    end)

    processed_messages
  end

  @impl Broadway
  def handle_batch(:training_data, messages, _batch_info, _context) do
    Logger.info("CodeQualityPipeline: Processing training data batch", batch_size: length(messages))

    # Check if PGFlow mode is enabled for training
    pgflow_enabled = Singularity.Settings.get_boolean("pipelines.code_quality.enabled", false)

    if pgflow_enabled do
      # Use PGFlow workflow for training
      training_data = Enum.map(messages, & &1.data)

      case CodeQualityTrainingWorkflow.execute(%{training_data: training_data}) do
        {:ok, result} ->
          Logger.info("CodeQualityPipeline: Training completed via PGFlow", result: result)
          messages

        {:error, reason} ->
          Logger.error("CodeQualityPipeline: Training failed", error: reason)
          Enum.map(messages, &Message.failed(&1, reason))
      end
    else
      # Simple in-memory training
      training_data = Enum.map(messages, & &1.data)
      perform_simple_training(training_data)
      messages
    end
  end

  # Private functions

  defp analyze_code_quality(data) do
    try do
      # Use existing quality analysis modules
      case QualityAnalyzer.analyze(data) do
        {:ok, metrics} -> {:ok, metrics}
        {:error, _} -> QualityScanner.scan(data)
      end
    rescue
      error ->
        Logger.error("CodeQualityPipeline: Analysis error", error: error)
        {:error, :analysis_failed}
    end
  end

  defp should_trigger_training?(metrics) do
    # Logic to determine if quality metrics warrant model retraining
    # This could be based on accuracy thresholds, data volume, etc.
    confidence_score = Map.get(metrics, :confidence, 0.0)
    confidence_score < 0.8
  end

  defp perform_simple_training(_training_data) do
    # Simple training logic for Broadway mode
    Logger.info("CodeQualityPipeline: Performing simple training (Broadway mode)")
    # In a real implementation, this would update quality models
    :ok
  end
end