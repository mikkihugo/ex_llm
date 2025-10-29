defmodule Singularity.Pipelines.EmbeddingTrainingPipeline do
  @moduledoc """
  Broadway Pipeline for Embedding Training

  Supports dual modes:
  - Broadway mode: Uses Broadway.DummyProducer for simple in-memory processing
  - PGFlow mode: Uses Broadway.PgflowProducer for durable, orchestrated processing

  Mode is determined by pipelines.embedding_training.enabled setting.
  """

  use Broadway

  require Logger

  alias Broadway.Message
  alias Singularity.Embedding.NxService
  alias Singularity.Workflows.EmbeddingTrainingWorkflow

  @doc """
  Start the embedding training Broadway pipeline with appropriate producer based on environment
  """
  def start_link(opts \\ []) do
    producer_config = build_producer_config()

    pipeline_config = [
      name: __MODULE__,
      producer: producer_config,
      processors: [
        default: [concurrency: 4]
      ],
      batchers: [
        embedding_generation: [concurrency: 4, batch_size: 32],
        training_data: [concurrency: 1, batch_size: 16]
      ]
    ]

    Broadway.start_link(__MODULE__, pipeline_config)
  end

  @doc """
  Build producer configuration based on PGFlow mode setting
  """
  def build_producer_config do
    pgflow_enabled = Singularity.Settings.get_boolean("pipelines.embedding_training.enabled", false)

    if pgflow_enabled do
      Logger.info("EmbeddingTrainingPipeline: Starting in PGFlow mode")
      [
        module: {Broadway.PgflowProducer, [
          workflow_name: "embedding_training_producer",
          queue_name: "embedding_training_jobs",
          concurrency: 4,
          batch_size: 32,
          pgflow_config: [timeout_ms: 300_000, retries: 3],
          resource_hints: [gpu: true]
        ]},
        concurrency: 4
      ]
    else
      Logger.info("EmbeddingTrainingPipeline: Starting in Broadway mode")
      [
        module: {Broadway.DummyProducer, []},
        concurrency: 1
      ]
    end
  end

  @impl Broadway
  def handle_message(:default, %Message{data: data} = message, _context) do
    Logger.debug("EmbeddingTrainingPipeline: Processing message", message_id: message.metadata.message_id)

    case generate_embeddings(data) do
      {:ok, embeddings} ->
        message
        |> Message.put_data(%{original: data, embeddings: embeddings})
        |> Message.put_batcher(:embedding_generation)

      {:error, reason} ->
        Logger.error("EmbeddingTrainingPipeline: Embedding generation failed", error: reason)
        Message.failed(message, reason)
    end
  end

  @impl Broadway
  def handle_batch(:embedding_generation, messages, _batch_info, _context) do
    Logger.info("EmbeddingTrainingPipeline: Processing embedding generation batch", batch_size: length(messages))

    processed_messages = Enum.map(messages, fn message ->
      %{embeddings: embeddings} = message.data

      should_train = should_trigger_training?(embeddings)

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
    Logger.info("EmbeddingTrainingPipeline: Processing training data batch", batch_size: length(messages))

    pgflow_enabled = Singularity.Settings.get_boolean("pipelines.embedding_training.enabled", false)

    if pgflow_enabled do
      training_data = Enum.map(messages, & &1.data)

      case EmbeddingTrainingWorkflow.execute(%{training_data: training_data}) do
        {:ok, result} ->
          Logger.info("EmbeddingTrainingPipeline: Training completed via PGFlow", result: result)
          messages

        {:error, reason} ->
          Logger.error("EmbeddingTrainingPipeline: Training failed", error: reason)
          Enum.map(messages, &Message.failed(&1, reason))
      end
    else
      training_data = Enum.map(messages, & &1.data)
      perform_simple_training(training_data)
      messages
    end
  end

  # Private functions

  defp generate_embeddings(data) do
    try do
      NxService.embed(data)
    rescue
      error ->
        Logger.error("EmbeddingTrainingPipeline: Embedding generation error", error: error)
        {:error, :embedding_failed}
    end
  end

  defp should_trigger_training?(embeddings) do
    # Check if embeddings need retraining based on quality metrics
    quality_score = calculate_embedding_quality(embeddings)
    quality_score < 0.85  # Retrain if quality drops below threshold
  end

  defp calculate_embedding_quality(embeddings) do
    # Simple quality calculation - in real implementation this would be more sophisticated
    # For now, just return a mock quality score
    0.9
  end

  defp perform_simple_training(_training_data) do
    Logger.info("EmbeddingTrainingPipeline: Performing simple training (Broadway mode)")
    :ok
  end
end