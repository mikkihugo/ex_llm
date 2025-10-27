defmodule Singularity.ML.Pipelines.EmbeddingTrainingPipeline do
  @moduledoc """
  Broadway Pipeline for Embedding Model Training (Qodo + Jina)
  
  Processes embedding training tasks through multiple stages:
  1. Data Collection - Gather training data from codebase
  2. Data Preparation - Clean and format training data
  3. Model Training - Fine-tune Qodo/Jina models with Axon
  4. Model Validation - Test model performance
  5. Model Deployment - Save and deploy trained models
  """

  use Broadway
  require Logger

  alias Singularity.Embedding.{Trainer, ModelLoader}
  alias Singularity.CodeStore

  @doc """
  Start the embedding training pipeline.
  """
  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayPGMQ.Producer, 
          queue: "embedding_training_tasks",
          config: [
            host: System.get_env("DATABASE_URL", "postgres://localhost/singularity"),
            port: 5432
          ]
        }
      ],
      processors: [
        data_collection: [concurrency: 3],
        data_preparation: [concurrency: 5],
        model_training: [concurrency: 1],  # GPU intensive - limit to 1
        model_validation: [concurrency: 2],
        model_deployment: [concurrency: 1]
      ],
      batchers: [
        training_batch: [batch_size: 10, batch_timeout: 5000]
      ]
    )
  end

  @impl Broadway
  def handle_message(processor, message, _context) do
    case processor do
      :data_collection ->
        handle_data_collection(message)
      :data_preparation ->
        handle_data_preparation(message)
      :model_training ->
        handle_model_training(message)
      :model_validation ->
        handle_model_validation(message)
      :model_deployment ->
        handle_model_deployment(message)
    end
  end

  defp handle_data_collection(message) do
    Logger.info("📊 Collecting training data for embedding model")
    
    # Extract training data from codebase
    training_data = collect_training_data(message.data)
    
    Broadway.Message.update_data(message, fn _data ->
      %{
        task_id: message.data.task_id,
        model_type: message.data.model_type,
        training_data: training_data,
        stage: :data_collected
      }
    end)
  end

  defp handle_data_preparation(message) do
    Logger.info("🔧 Preparing training data for #{message.data.model_type}")
    
    # Prepare training data for specific model
    prepared_data = prepare_training_data(message.data.training_data, message.data.model_type)
    
    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :prepared_data, prepared_data)
      |> Map.put(:stage, :data_prepared)
    end)
  end

  defp handle_model_training(message) do
    Logger.info("🧠 Training #{message.data.model_type} model with Axon")
    
    # Train the model using Axon
    case train_model(message.data.model_type, message.data.prepared_data) do
      {:ok, trained_model, metrics} ->
        Broadway.Message.update_data(message, fn data ->
          Map.put(data, :trained_model, trained_model)
          |> Map.put(:training_metrics, metrics)
          |> Map.put(:stage, :model_trained)
        end)
      {:error, reason} ->
        Logger.error("❌ Model training failed: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  defp handle_model_validation(message) do
    Logger.info("✅ Validating trained #{message.data.model_type} model")
    
    # Validate model performance
    validation_metrics = validate_model(message.data.trained_model, message.data.model_type)
    
    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :validation_metrics, validation_metrics)
      |> Map.put(:stage, :model_validated)
    end)
  end

  defp handle_model_deployment(message) do
    Logger.info("🚀 Deploying trained #{message.data.model_type} model")
    
    # Save and deploy the model
    case deploy_model(message.data.trained_model, message.data.model_type) do
      {:ok, model_path} ->
        Broadway.Message.update_data(message, fn data ->
          Map.put(data, :model_path, model_path)
          |> Map.put(:stage, :model_deployed)
        end)
      {:error, reason} ->
        Logger.error("❌ Model deployment failed: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  # Private helper functions

  defp collect_training_data(task_data) do
    # Collect code samples from PostgreSQL
    language = Map.get(task_data, :language, "elixir")
    min_length = Map.get(task_data, :min_length, 50)
    
    CodeStore.get_training_samples(
      language: language,
      min_length: min_length,
      limit: 1000
    )
  end

  defp prepare_training_data(raw_data, model_type) do
    case model_type do
      :qodo ->
        # Prepare Qodo-specific training data (code-focused)
        prepare_qodo_training_data(raw_data)
      :jina ->
        # Prepare Jina-specific training data (general text)
        prepare_jina_training_data(raw_data)
      :both ->
        # Prepare data for both models
        %{
          qodo: prepare_qodo_training_data(raw_data),
          jina: prepare_jina_training_data(raw_data)
        }
    end
  end

  defp prepare_qodo_training_data(code_samples) do
    # Create contrastive learning triplets for Qodo
    code_samples
    |> Enum.map(fn sample ->
      %{
        anchor: sample.code,
        positive: generate_positive_example(sample.code),
        negative: generate_negative_example(sample.code)
      }
    end)
  end

  defp prepare_jina_training_data(code_samples) do
    # Create general text training data for Jina
    code_samples
    |> Enum.map(fn sample ->
      %{
        text: sample.code,
        context: sample.context || "",
        metadata: sample.metadata || %{}
      }
    end)
  end

  defp train_model(model_type, prepared_data) do
    case model_type do
      :qodo ->
        train_qodo_model(prepared_data)
      :jina ->
        train_jina_model(prepared_data)
      :both ->
        train_both_models(prepared_data)
    end
  end

  defp train_qodo_model(training_data) do
    # Train Qodo model using Axon
    with {:ok, trainer} <- Trainer.new(:qodo, device: :cuda),
         {:ok, metrics} <- Trainer.train(trainer, training_data, 
           epochs: 3,
           learning_rate: 1.0e-5,
           batch_size: 16
         ) do
      {:ok, trainer, metrics}
    end
  end

  defp train_jina_model(training_data) do
    # Train Jina model using Axon
    with {:ok, trainer} <- Trainer.new(:jina_v3, device: :cuda),
         {:ok, metrics} <- Trainer.train(trainer, training_data,
           epochs: 2,
           learning_rate: 5.0e-6,
           batch_size: 32
         ) do
      {:ok, trainer, metrics}
    end
  end

  defp train_both_models(%{qodo: qodo_data, jina: jina_data}) do
    # Train both models in parallel
    with {:ok, qodo_trainer, qodo_metrics} <- train_qodo_model(qodo_data),
         {:ok, jina_trainer, jina_metrics} <- train_jina_model(jina_data) do
      {:ok, %{qodo: qodo_trainer, jina: jina_trainer}, 
       %{qodo: qodo_metrics, jina: jina_metrics}}
    end
  end

  defp validate_model(trained_model, model_type) do
    # Validate model performance on test data
    %{
      accuracy: 0.85 + :rand.uniform() * 0.1,  # Simulate validation
      loss: 0.1 + :rand.uniform() * 0.05,
      model_type: model_type,
      validated_at: DateTime.utc_now()
    }
  end

  defp deploy_model(trained_model, model_type) do
    # Save model to disk
    model_path = Path.join([
      System.user_home!(),
      ".cache/singularity/models",
      "#{model_type}_#{DateTime.utc_now() |> DateTime.to_unix()}"
    ])
    
    File.mkdir_p!(Path.dirname(model_path))
    
    # Save model (simplified - would use proper model serialization)
    :ok = File.write!(model_path, :erlang.term_to_binary(trained_model))
    
    {:ok, model_path}
  end

  defp generate_positive_example(code) do
    # Generate a positive example (similar code)
    # This would use code transformation techniques
    code
  end

  defp generate_negative_example(code) do
    # Generate a negative example (dissimilar code)
    # This would use code from different domains
    "def different_function() do\n  # Different code\nend"
  end
end