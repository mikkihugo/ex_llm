defmodule Singularity.Jobs.TrainT5ModelJob do
  @moduledoc """
  Oban job for training T5 models on codebase data.

  **What it does:**
  - Trains T5 models on Rust/Elixir patterns from codebase
  - Stores trained models in database
  - Publishes completion events to NATS for centralcloud
  - Tracks training metrics and performance

  **Job Configuration:**
  - Queue: `:ml_training` (high priority for ML workloads)
  - Max attempts: 3 (retry on failure)
  - Priority: 1 (lower number = higher priority)

  **NATS Integration:**
  Publishes to `ml.training.t5.completed` when successful
  Publishes to `ml.training.t5.failed` on error

  ## Usage

      # Schedule T5 training job
      %{
        name: "rust_elixir_v1",
        languages: ["rust", "elixir"],
        max_examples: 20000,
        epochs: 12
      }
      |> Singularity.Jobs.TrainT5ModelJob.new()
      |> Oban.insert()

      # Schedule with custom priority
      %{name: "urgent_training", languages: ["elixir"]}
      |> Singularity.Jobs.TrainT5ModelJob.new(priority: 0)
      |> Oban.insert()
  """

  use Oban.Worker,
    queue: :ml_training,
    max_attempts: 3,
    priority: 1

  require Logger
  alias Singularity.MultiLanguageT5Trainer

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.info("Starting T5 training job", args: args)

    training_name = Map.fetch!(args, "name")
    languages = Map.get(args, "languages", ["rust", "elixir"])
    max_examples = Map.get(args, "max_examples", 10000)
    epochs = Map.get(args, "epochs", 12)
    learning_rate = Map.get(args, "learning_rate", 2.0e-4)
    batch_size = Map.get(args, "batch_size", 4)

    with {:ok, session_id} <- prepare_training_session(training_name, languages, max_examples),
         {:ok, model_id} <- fine_tune_model(session_id, epochs, learning_rate, batch_size),
         {:ok, _eval_results} <- evaluate_model(model_id),
         :ok <- publish_completion(session_id, model_id) do
      Logger.info("T5 training job completed successfully",
        session_id: session_id,
        model_id: model_id
      )

      {:ok, %{session_id: session_id, model_id: model_id}}
    else
      {:error, reason} = error ->
        Logger.error("T5 training job failed", error: inspect(reason))
        publish_failure(training_name, reason)
        error
    end
  rescue
    exception ->
      Logger.error("T5 training job exception", exception: inspect(exception))
      publish_failure(args["name"], exception)
      {:error, exception}
  end

  ## Private Functions

  defp prepare_training_session(name, languages, max_examples) do
    Logger.info("Preparing T5 training session",
      name: name,
      languages: languages,
      max_examples: max_examples
    )

    case MultiLanguageT5Trainer.prepare_multi_language_training(
           name: name,
           languages: languages,
           max_examples: max_examples,
           cross_language_learning: true,
           quality_threshold: 0.7
         ) do
      {:ok, session_id} ->
        Logger.info("Training session prepared", session_id: session_id)
        {:ok, session_id}

      {:error, reason} = error ->
        Logger.error("Failed to prepare training session", error: inspect(reason))
        error
    end
  end

  defp fine_tune_model(session_id, epochs, learning_rate, batch_size) do
    Logger.info("Fine-tuning T5 model",
      session_id: session_id,
      epochs: epochs,
      learning_rate: learning_rate,
      batch_size: batch_size
    )

    case MultiLanguageT5Trainer.fine_tune(session_id,
           epochs: epochs,
           learning_rate: learning_rate,
           batch_size: batch_size,
           cross_language_learning: true
         ) do
      {:ok, model_id} ->
        Logger.info("Model fine-tuning completed", model_id: model_id)
        {:ok, model_id}

      {:error, reason} = error ->
        Logger.error("Fine-tuning failed", error: inspect(reason))
        error
    end
  end

  defp evaluate_model(model_id) do
    Logger.info("Evaluating T5 model", model_id: model_id)

    case MultiLanguageT5Trainer.evaluate_rust_elixir_performance(model_id) do
      {:ok, eval_results} ->
        Logger.info("Model evaluation completed",
          model_id: model_id,
          overall_score: eval_results.overall_score
        )

        {:ok, eval_results}

      {:error, reason} = error ->
        Logger.error("Evaluation failed", error: inspect(reason))
        error
    end
  end

  defp publish_completion(session_id, model_id) do
    Logger.debug("Publishing T5 training completion to NATS")

    payload =
      Jason.encode!(%{
        event: "t5_training_completed",
        session_id: session_id,
        model_id: model_id,
        timestamp: DateTime.utc_now()
      })

    case Singularity.Messaging.Client.publish("ml.training.t5.completed", payload) do
      :ok ->
        Logger.info("Published training completion to NATS",
          session_id: session_id,
          model_id: model_id
        )

        :ok

      {:error, reason} ->
        Logger.warning("Failed to publish to NATS (non-critical)", error: inspect(reason))
        # Don't fail the job if NATS publish fails
        :ok
    end
  rescue
    exception ->
      Logger.warning("Exception publishing to NATS (non-critical)", exception: inspect(exception))
      :ok
  end

  defp publish_failure(training_name, reason) do
    Logger.debug("Publishing T5 training failure to NATS")

    payload =
      Jason.encode!(%{
        event: "t5_training_failed",
        training_name: training_name,
        error: inspect(reason),
        timestamp: DateTime.utc_now()
      })

    case Singularity.Messaging.Client.publish("ml.training.t5.failed", payload) do
      :ok ->
        Logger.info("Published training failure to NATS", training_name: training_name)

      {:error, nats_error} ->
        Logger.warning("Failed to publish failure to NATS", error: inspect(nats_error))
    end
  rescue
    exception ->
      Logger.warning("Exception publishing failure to NATS", exception: inspect(exception))
  end
end
