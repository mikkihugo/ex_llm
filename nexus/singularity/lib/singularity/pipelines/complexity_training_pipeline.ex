defmodule Singularity.Pipelines.ComplexityTrainingPipeline do
  @moduledoc """
  Broadway Pipeline for Complexity Analysis Training

  Supports dual modes:
  - Broadway mode: Uses Broadway.DummyProducer for simple in-memory processing
  - PGFlow mode: Uses Broadway.PgflowProducer for durable, orchestrated processing

  Mode is determined by PGFLOW_COMPLEXITY_TRAINING_ENABLED environment variable.
  """

  use Broadway

  require Logger

  alias Broadway.Message
  alias Singularity.CodeAnalysis.ComplexityAnalyzer
  alias Singularity.Workflows.ComplexityTrainingWorkflow

  @doc """
  Start the complexity training Broadway pipeline with appropriate producer based on environment
  """
  def start_link(opts \\ []) do
    producer_config = build_producer_config()

    pipeline_config = [
      name: __MODULE__,
      producer: producer_config,
      processors: [
        default: [concurrency: 3]
      ],
      batchers: [
        complexity_analysis: [concurrency: 2, batch_size: 15],
        training_data: [concurrency: 1, batch_size: 8]
      ]
    ]

    Broadway.start_link(__MODULE__, pipeline_config)
  end

  @doc """
  Build producer configuration based on PGFlow mode setting
  """
  def build_producer_config do
    pgflow_enabled =
      Singularity.Settings.get_boolean("pipelines.complexity_training.enabled", false)

    if pgflow_enabled do
      Logger.info("ComplexityTrainingPipeline: Starting in PGFlow mode")

      [
        module:
          {Broadway.PgflowProducer,
           [
             workflow_name: "complexity_training_producer",
             queue_name: "complexity_training_jobs",
             concurrency: 3,
             batch_size: 15,
             pgflow_config: [timeout_ms: 600_000, retries: 5],
             resource_hints: [gpu: true, cpu_cores: 8]
           ]},
        concurrency: 3
      ]
    else
      Logger.info("ComplexityTrainingPipeline: Starting in Broadway mode")

      [
        module: {Broadway.DummyProducer, []},
        concurrency: 1
      ]
    end
  end

  @impl Broadway
  def handle_message(:default, %Message{data: data} = message, _context) do
    Logger.debug("ComplexityTrainingPipeline: Processing message",
      message_id: message.metadata.message_id
    )

    case analyze_complexity(data) do
      {:ok, complexity_metrics} ->
        message
        |> Message.put_data(%{original: data, complexity_metrics: complexity_metrics})
        |> Message.put_batcher(:complexity_analysis)

      {:error, reason} ->
        Logger.error("ComplexityTrainingPipeline: Complexity analysis failed", error: reason)
        Message.failed(message, reason)
    end
  end

  @impl Broadway
  def handle_batch(:complexity_analysis, messages, _batch_info, _context) do
    Logger.info("ComplexityTrainingPipeline: Processing complexity analysis batch",
      batch_size: length(messages)
    )

    processed_messages =
      Enum.map(messages, fn message ->
        %{complexity_metrics: metrics} = message.data

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
    Logger.info("ComplexityTrainingPipeline: Processing training data batch",
      batch_size: length(messages)
    )

    pgflow_enabled =
      Singularity.Settings.get_boolean("pipelines.complexity_training.enabled", false)

    if pgflow_enabled do
      training_data = Enum.map(messages, & &1.data)

      case ComplexityTrainingWorkflow.execute(%{training_data: training_data}) do
        {:ok, result} ->
          Logger.info("ComplexityTrainingPipeline: Training completed via PGFlow", result: result)
          messages

        {:error, reason} ->
          Logger.error("ComplexityTrainingPipeline: Training failed", error: reason)
          Enum.map(messages, &Message.failed(&1, reason))
      end
    else
      training_data = Enum.map(messages, & &1.data)
      perform_simple_training(training_data)
      messages
    end
  end

  # Private functions

  defp analyze_complexity(data) do
    try do
      ComplexityAnalyzer.analyze(data)
    rescue
      error ->
        Logger.error("ComplexityTrainingPipeline: Analysis error", error: error)
        {:error, :analysis_failed}
    end
  end

  defp should_trigger_training?(metrics) do
    complexity_score = Map.get(metrics, :complexity_score, 0.0)
    # High complexity indicates need for better models
    complexity_score > 0.7
  end

  defp perform_simple_training(_training_data) do
    Logger.info("ComplexityTrainingPipeline: Performing simple training (Broadway mode)")
    :ok
  end
end
