defmodule Singularity.Pipelines.ArchitectureLearningPipeline do
  @moduledoc """
  Broadway Pipeline for Architecture Learning

  Supports dual modes:
  - Broadway mode: Uses Broadway.DummyProducer for simple in-memory processing
  - PGFlow mode: Uses Broadway.PgflowProducer for durable, orchestrated processing

  Mode is determined by pipelines.architecture_learning.enabled setting.
  """

  use Broadway

  require Logger

  alias Broadway.Message
  alias Singularity.Workflows.ArchitectureLearningWorkflow
  alias Singularity.Architecture.PatternDetector

  @doc """
  Start the architecture learning Broadway pipeline with appropriate producer based on environment
  """
  def start_link(_opts \\ []) do
    producer_config = build_producer_config()

    pipeline_config = [
      name: __MODULE__,
      producer: producer_config,
      processors: [
        default: [concurrency: 2]
      ],
      batchers: [
        architecture_analysis: [concurrency: 2, batch_size: 8],
        learning_data: [concurrency: 1, batch_size: 4]
      ]
    ]

    Broadway.start_link(__MODULE__, pipeline_config)
  end

  @doc """
  Build producer configuration based on PGFlow mode setting
  """
  def build_producer_config do
    pgflow_enabled =
      Singularity.Settings.get_boolean("pipelines.architecture_learning.enabled", false)

    if pgflow_enabled do
      Logger.info("ArchitectureLearningPipeline: Starting in PGFlow mode")

      [
        module:
          {Broadway.PgflowProducer,
           [
             workflow_name: "architecture_learning_producer",
             queue_name: "architecture_learning_jobs",
             concurrency: 2,
             batch_size: 8,
             pgflow_config: [timeout_ms: 900_000, retries: 3],
             resource_hints: [gpu: false, memory_gb: 16]
           ]},
        concurrency: 2
      ]
    else
      Logger.info("ArchitectureLearningPipeline: Starting in Broadway mode")

      [
        module: {Broadway.DummyProducer, []},
        concurrency: 1
      ]
    end
  end

  @impl Broadway
  def handle_message(:default, %Message{data: data} = message, _context) do
    Logger.debug("ArchitectureLearningPipeline: Processing message",
      message_id: message.metadata.message_id
    )

    case analyze_architecture(data) do
      {:ok, architecture_metrics} ->
        message
        |> Message.put_data(%{original: data, architecture_metrics: architecture_metrics})
        |> Message.put_batcher(:architecture_analysis)

      {:error, reason} ->
        Logger.error("ArchitectureLearningPipeline: Architecture analysis failed", error: reason)
        Message.failed(message, reason)
    end
  end

  @impl Broadway
  def handle_batch(:architecture_analysis, messages, _batch_info, _context) do
    Logger.info("ArchitectureLearningPipeline: Processing architecture analysis batch",
      batch_size: length(messages)
    )

    processed_messages =
      Enum.map(messages, fn message ->
        %{architecture_metrics: metrics} = message.data

        should_learn = should_trigger_learning?(metrics)

        if should_learn do
          Message.put_batcher(message, :learning_data)
        else
          message
        end
      end)

    processed_messages
  end

  @impl Broadway
  def handle_batch(:learning_data, messages, _batch_info, _context) do
    Logger.info("ArchitectureLearningPipeline: Processing learning data batch",
      batch_size: length(messages)
    )

    pgflow_enabled =
      Singularity.Settings.get_boolean("pipelines.architecture_learning.enabled", false)

    if pgflow_enabled do
      learning_data = Enum.map(messages, & &1.data)

      # Execute via Pgflow workflow system
      case Pgflow.Executor.execute(
             Singularity.Workflows.ArchitectureLearningWorkflow,
             %{"learning_data" => learning_data},
             timeout: 300_000
           ) do
        {:ok, result} ->
          Logger.info("ArchitectureLearningPipeline: Learning completed via PGFlow",
            result: result
          )

          messages

        {:error, reason} ->
          Logger.error("ArchitectureLearningPipeline: Learning failed", error: reason)
          Enum.map(messages, &Message.failed(&1, reason))
      end
    else
      learning_data = Enum.map(messages, & &1.data)
      perform_simple_learning(learning_data)
      messages
    end
  end

  # Private functions

  defp analyze_architecture(data) do
    codebase_path = Map.get(data, :codebase_path) || Map.get(data, "codebase_path") || "."

    try do
      # Use PatternDetector for architecture analysis
      # Returns {:ok, %{framework: [...], technology: [...], ...}}
      case PatternDetector.detect(codebase_path) do
        {:ok, patterns} when is_map(patterns) ->
          # Count total patterns across all types
          # Map.values() returns lists, flatten to count all patterns
          total_patterns =
            patterns
            |> Map.values()
            |> List.flatten()
            |> length()

          {:ok,
           %{
             architecture_complexity: calculate_complexity(total_patterns),
             patterns: patterns,
             pattern_count: total_patterns
           }}

        {:ok, invalid} ->
          SASL.execution_failure(
            :pattern_detector_invalid_format,
            "PatternDetector returned unexpected format",
            result: inspect(invalid),
            codebase_path: codebase_path
          )

          {:ok, %{architecture_complexity: 0.5, patterns: %{}, pattern_count: 0}}

        {:error, reason} ->
          SASL.execution_failure(
            :pattern_detection_failed,
            "Pattern detection failed in architecture learning pipeline",
            error: inspect(reason),
            codebase_path: codebase_path
          )

          {:ok, %{architecture_complexity: 0.5, patterns: %{}, pattern_count: 0}}
      end
    rescue
      error ->
        SASL.execution_failure(
          :architecture_analysis_exception,
          "Architecture analysis raised exception",
          error: inspect(error),
          codebase_path: codebase_path
        )

        {:error, :analysis_failed}
    end
  end

  defp calculate_complexity(total_patterns) do
    case total_patterns do
      0 -> 0.0
      count when count < 5 -> 0.3
      count when count < 10 -> 0.5
      count when count < 20 -> 0.7
      _ -> 0.9
    end
  end

  defp should_trigger_learning?(metrics) do
    complexity_score = Map.get(metrics, :architecture_complexity, 0.0)
    # High architectural complexity indicates need for learning
    complexity_score > 0.8
  end

  defp perform_simple_learning(_learning_data) do
    Logger.info("ArchitectureLearningPipeline: Performing simple learning (Broadway mode)")
    :ok
  end
end
