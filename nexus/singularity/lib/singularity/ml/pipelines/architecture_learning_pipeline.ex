defmodule Singularity.ML.Pipelines.ArchitectureLearningPipeline do
  @moduledoc """
  Architecture Learning Pipeline with QuantumFlow Migration Support

  Supports both Broadway (legacy) and QuantumFlow (new) orchestration modes.
  Use PGFLOW_ARCHITECTURE_LEARNING_ENABLED=true to enable QuantumFlow mode.

  ## Migration Notes

  - **Legacy Mode**: Uses Broadway + BroadwayPGMQ producer
  - **QuantumFlow Mode**: Uses QuantumFlow workflow orchestration with better observability
  - **Canary Rollout**: Environment flag controls rollout percentage

  ## Configuration

  ```elixir
  config :singularity, :architecture_learning_pipeline,
    quantum_flow_enabled: System.get_env("PGFLOW_ARCHITECTURE_LEARNING_ENABLED", "false") == "true",
    canary_percentage: String.to_integer(System.get_env("ARCHITECTURE_LEARNING_CANARY_PERCENT", "10"))
  ```
  """

  use Broadway
  require Logger

  alias Singularity.Architecture.{PatternDetector, FrameworkDetector}
  alias Singularity.Repo

  @doc """
  Start the architecture learning pipeline.

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
    Application.get_env(:singularity, :architecture_learning_pipeline, %{})
    |> Map.get(:quantum_flow_enabled, false)
  end

  # Start QuantumFlow-based pipeline
  defp start_quantum_flow_pipeline(_opts) do
    Logger.info("🚀 Starting Architecture Learning Pipeline (QuantumFlow mode)")

    # Start QuantumFlow workflow supervisor
    QuantumFlow.WorkflowSupervisor.start_workflow(
      Singularity.Workflows.ArchitectureLearningWorkflow,
      name: ArchitectureLearningWorkflowSupervisor
    )
  end

  # Start legacy Broadway-based pipeline
  defp start_broadway_pipeline(_opts) do
    Logger.info("🎭 Starting Architecture Learning Pipeline (Broadway legacy mode)")

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayPGMQ.Producer,
           queue: "architecture_learning_tasks",
           config: [
             host: System.get_env("DATABASE_URL", "postgres://localhost/singularity"),
             port: 5432
           ]}
      ],
      processors: [
        pattern_discovery: [concurrency: 2],
        pattern_analysis: [concurrency: 3],
        # ML training - limit to 1
        model_training: [concurrency: 1],
        model_validation: [concurrency: 2],
        model_deployment: [concurrency: 1]
      ],
      batchers: [
        architecture_batch: [batch_size: 10, batch_timeout: 3000]
      ]
    )
  end

  @impl Broadway
  def handle_message(processor, message, _context) do
    case processor do
      :pattern_discovery ->
        handle_pattern_discovery(message)

      :pattern_analysis ->
        handle_pattern_analysis(message)

      :model_training ->
        handle_model_training(message)

      :model_validation ->
        handle_model_validation(message)

      :model_deployment ->
        handle_model_deployment(message)
    end
  end

  # Legacy Broadway handlers (unchanged)
  # Pattern Discovery Stage
  defp handle_pattern_discovery(message) do
    Logger.info("Discovering architectural patterns in: #{message.data.codebase_path}")

    # Use PatternDetector to discover patterns
    case PatternDetector.detect(message.data.codebase_path) do
      {:ok, patterns} ->
        discovery_data = %{
          codebase_path: message.data.codebase_path,
          patterns: patterns,
          discovery_timestamp: DateTime.utc_now()
        }

        Broadway.Message.update_data(message, fn _ -> discovery_data end)

      {:error, reason} ->
        Logger.error("Failed to discover patterns: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  # Pattern Analysis Stage
  defp handle_pattern_analysis(message) do
    Logger.info("Analyzing discovered patterns...")

    # Analyze patterns for ML training
    analyzed_patterns =
      message.data.patterns
      |> Enum.map(fn pattern ->
        pattern
        |> Map.put(:feature_vector, extract_pattern_features(pattern))
        |> Map.put(:complexity_score, calculate_pattern_complexity(pattern))
      end)

    analysis_data =
      message.data
      |> Map.put(:patterns, analyzed_patterns)
      |> Map.put(:analysis_timestamp, DateTime.utc_now())

    Broadway.Message.update_data(message, fn _ -> analysis_data end)
  end

  # Model Training Stage
  defp handle_model_training(message) do
    Logger.info("Training architecture learning model...")

    # Mock model training - in real implementation, this would:
    # 1. Build Axon model architecture
    # 2. Train with pattern data
    # 3. Save trained model

    training_result = %{
      model_id: "architecture_model_#{System.unique_integer([:positive])}",
      accuracy: 0.92,
      training_time: 180.3,
      training_timestamp: DateTime.utc_now()
    }

    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :training_result, training_result)
    end)
  end

  # Model Validation Stage
  defp handle_model_validation(message) do
    Logger.info("Validating architecture model...")

    # Mock model validation - in real implementation, this would:
    # 1. Test model on validation set
    # 2. Calculate performance metrics
    # 3. Check for overfitting

    validation_result = %{
      validation_accuracy: 0.89,
      validation_loss: 0.08,
      validation_timestamp: DateTime.utc_now()
    }

    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :validation_result, validation_result)
    end)
  end

  # Model Deployment Stage
  defp handle_model_deployment(message) do
    Logger.info("Deploying architecture model...")

    # Mock model deployment - in real implementation, this would:
    # 1. Save model to storage
    # 2. Update model registry
    # 3. Deploy to production

    deployment_result = %{
      deployment_status: :success,
      model_path: "/models/architecture/#{message.data.training_result.model_id}",
      deployment_timestamp: DateTime.utc_now()
    }

    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :deployment_result, deployment_result)
    end)
  end

  # Private helper functions (shared between Broadway and QuantumFlow)
  defp extract_pattern_features(pattern) do
    # Mock feature extraction - in real implementation, this would:
    # 1. Extract structural features
    # 2. Calculate complexity metrics
    # 3. Generate feature vectors

    [
      pattern.complexity_score || 0.5,
      length(pattern.metadata || %{}) / 10.0,
      :rand.uniform()
    ]
  end

  defp calculate_pattern_complexity(pattern) do
    # Mock complexity calculation
    base_complexity = 0.5

    # Adjust based on pattern type
    complexity_adjustment =
      case pattern.type do
        "microservice" -> 0.3
        "monolith" -> 0.1
        "event-driven" -> 0.4
        _ -> 0.2
      end

    min(1.0, base_complexity + complexity_adjustment)
  end
end
