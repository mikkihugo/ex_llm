defmodule Singularity.ML.Pipelines.CodeQualityPipeline do
  @moduledoc """
  Code Quality Pipeline with QuantumFlow Migration Support

  Supports both Broadway (legacy) and QuantumFlow (new) orchestration modes.
  Use PGFLOW_CODE_QUALITY_ENABLED=true to enable QuantumFlow mode.

  ## Migration Notes

  - **Legacy Mode**: Uses Broadway + Broadway.QuantumFlowProducer
  - **QuantumFlow Mode**: Uses QuantumFlow workflow orchestration with better observability
  - **Canary Rollout**: Environment flag controls rollout percentage

  ## Configuration

  ```elixir
  config :singularity, :code_quality_pipeline,
    quantum_flow_enabled: System.get_env("PGFLOW_CODE_QUALITY_ENABLED", "false") == "true",
    canary_percentage: String.to_integer(System.get_env("CODE_QUALITY_CANARY_PERCENT", "10"))
  ```
  """

  use Broadway
  require Logger

  alias Singularity.CodeAnalysis.{QualityAnalyzer, QualityScanner}

  @doc """
  Start the code quality pipeline.

  Supports both Broadway and QuantumFlow modes based on configuration.
  """
  def start_link(opts \\ []) do
    if quantum_flow_enabled?() do
      start_quantum_flow_pipeline(opts)
    else
      start_broadway_pipeline(opts)
    end
  end

  # Check if QuantumFlow mode is enabled
  defp quantum_flow_enabled? do
    Application.get_env(:singularity, :code_quality_pipeline, %{})
    |> Map.get(:quantum_flow_enabled, false)
  end

  # Start QuantumFlow-based pipeline
  defp start_quantum_flow_pipeline(_opts) do
    Logger.info("🚀 Starting Code Quality Pipeline (QuantumFlow mode)")

    # Start QuantumFlow workflow supervisor
    QuantumFlow.WorkflowSupervisor.start_workflow(
      Singularity.Workflows.CodeQualityTrainingWorkflow,
      name: CodeQualityTrainingWorkflowSupervisor
    )
  end

  # Start legacy Broadway-based pipeline
  defp start_broadway_pipeline(_opts) do
    Logger.info("🎭 Starting Code Quality Pipeline (Broadway legacy mode)")

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {Broadway.QuantumFlowProducer,
           [
             workflow_name: "code_quality_training_broadway",
             queue_name: "code_quality_training_jobs",
             concurrency: 3,
             batch_size: 15,
             quantum_flow_config: [timeout_ms: 300_000, retries: 3],
             resource_hints: [cpu_cores: 8]
           ]}
      ],
      processors: [
        data_collection: [concurrency: 3],
        data_preparation: [concurrency: 5],
        # ML training - limit to 1
        model_training: [concurrency: 1],
        model_validation: [concurrency: 2],
        model_deployment: [concurrency: 1]
      ],
      batchers: [
        quality_batch: [batch_size: 15, batch_timeout: 4000]
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

  # Data Collection Stage
  defp handle_data_collection(message) do
    Logger.info("Collecting code quality data from: #{message.data.codebase_path}")

    # Use QualityAnalyzer to collect quality data
    case QualityAnalyzer.analyze(message.data.codebase_path) do
      {:ok, analysis} ->
        quality_data = %{
          codebase_path: message.data.codebase_path,
          analysis: analysis,
          quality_metrics: extract_quality_metrics(analysis),
          collection_timestamp: DateTime.utc_now()
        }

        Broadway.Message.update_data(message, fn _ -> quality_data end)

      {:error, reason} ->
        Logger.error("Failed to collect quality data: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  # Data Preparation Stage
  defp handle_data_preparation(message) do
    Logger.info("Preparing quality data for training...")

    # Prepare data for ML training
    prepared_data =
      message.data
      |> Map.put(:feature_vector, prepare_feature_vector(message.data.quality_metrics))
      |> Map.put(:target_vector, prepare_target_vector(message.data.quality_metrics))
      |> Map.put(:preparation_timestamp, DateTime.utc_now())

    Broadway.Message.update_data(message, fn _ -> prepared_data end)
  end

  # Model Training Stage
  defp handle_model_training(message) do
    Logger.info("Training code quality model...")

    # Mock model training - in real implementation, this would:
    # 1. Build Axon model architecture
    # 2. Train with prepared data
    # 3. Save trained model

    training_result = %{
      model_id: "quality_model_#{System.unique_integer([:positive])}",
      accuracy: 0.87,
      training_time: 120.5,
      training_timestamp: DateTime.utc_now()
    }

    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :training_result, training_result)
    end)
  end

  # Model Validation Stage
  defp handle_model_validation(message) do
    Logger.info("Validating trained model...")

    # Mock model validation - in real implementation, this would:
    # 1. Test model on validation set
    # 2. Calculate performance metrics
    # 3. Check for overfitting

    validation_result = %{
      validation_accuracy: 0.85,
      validation_loss: 0.12,
      validation_timestamp: DateTime.utc_now()
    }

    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :validation_result, validation_result)
    end)
  end

  # Model Deployment Stage
  defp handle_model_deployment(message) do
    Logger.info("Deploying trained model...")

    # Mock model deployment - in real implementation, this would:
    # 1. Save model to storage
    # 2. Update model registry
    # 3. Deploy to production

    deployment_result = %{
      deployment_status: :success,
      model_path: "/models/quality/#{message.data.training_result.model_id}",
      deployment_timestamp: DateTime.utc_now()
    }

    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :deployment_result, deployment_result)
    end)
  end

  # Private helper functions
  defp extract_quality_metrics(analysis) do
    # Mock quality metrics extraction
    %{
      cyclomatic_complexity: :rand.uniform(20),
      maintainability_index: :rand.uniform(100),
      code_duplication: :rand.uniform(50),
      test_coverage: :rand.uniform(100)
    }
  end

  defp prepare_feature_vector(quality_metrics) do
    # Mock feature vector preparation
    [
      quality_metrics.cyclomatic_complexity / 20.0,
      quality_metrics.maintainability_index / 100.0,
      quality_metrics.code_duplication / 50.0,
      quality_metrics.test_coverage / 100.0
    ]
  end

  defp prepare_target_vector(quality_metrics) do
    # Mock target vector preparation
    overall_quality =
      (quality_metrics.maintainability_index + quality_metrics.test_coverage) / 200.0

    [overall_quality]
  end
end
