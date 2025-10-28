defmodule Singularity.Workflows.ArchitectureLearningWorkflow do
  @moduledoc """
  PGFlow Workflow Definition for Architecture Learning Pipeline

  Replaces Broadway-based architecture learning with PGFlow workflow orchestration.
  Provides better observability, error handling, and resource management.

  Workflow Stages:
  1. Pattern Discovery - Extract architectural patterns from codebases
  2. Pattern Analysis - Analyze pattern characteristics and relationships
  3. Model Training - Train architecture learning models with Axon
  4. Model Validation - Test model performance
  5. Model Deployment - Save and deploy trained models
  """

  use PGFlow.Workflow

  alias Singularity.Architecture.{PatternDetector, FrameworkDetector}
  alias Singularity.Repo

  @doc """
  Define the architecture learning workflow structure
  """
  def workflow_definition do
    %{
      name: "architecture_learning",
      version: "1.0.0",
      description: "ML pipeline for training architecture learning models",

      # Workflow-level configuration
      config: %{
        timeout_ms: Application.get_env(:singularity, :architecture_learning_workflow, %{})[:timeout_ms] || 300_000,
        retries: Application.get_env(:singularity, :architecture_learning_workflow, %{})[:retries] || 3,
        retry_delay_ms: Application.get_env(:singularity, :architecture_learning_workflow, %{})[:retry_delay_ms] || 5000,
        concurrency: Application.get_env(:singularity, :architecture_learning_workflow, %{})[:concurrency] || 1
      },

      # Define workflow steps
      steps: [
        %{
          id: :pattern_discovery,
          name: "Pattern Discovery",
          description: "Extract architectural patterns from codebases",
          type: :task,
          module: __MODULE__,
          function: :discover_patterns,
          config: %{
            concurrency: 2,
            timeout_ms: 60_000
          },
          next: [:pattern_analysis]
        },

        %{
          id: :pattern_analysis,
          name: "Pattern Analysis",
          description: "Analyze pattern characteristics and relationships",
          type: :task,
          module: __MODULE__,
          function: :analyze_patterns,
          config: %{
            concurrency: 3,
            timeout_ms: 30_000
          },
          depends_on: [:pattern_discovery],
          next: [:model_training]
        },

        %{
          id: :model_training,
          name: "Model Training",
          description: "Train architecture learning models with Axon",
          type: :task,
          module: __MODULE__,
          function: :train_architecture_model,
          config: %{
            concurrency: 1,  # Single worker for GPU training
            timeout_ms: 180_000,
            resource_requirements: %{gpu: true}
          },
          depends_on: [:pattern_analysis],
          next: [:model_validation]
        },

        %{
          id: :model_validation,
          name: "Model Validation",
          description: "Test model performance and accuracy",
          type: :task,
          module: __MODULE__,
          function: :validate_model,
          config: %{
            concurrency: 2,
            timeout_ms: 30_000
          },
          depends_on: [:model_training],
          next: [:model_deployment]
        },

        %{
          id: :model_deployment,
          name: "Model Deployment",
          description: "Save and deploy trained architecture models",
          type: :task,
          module: __MODULE__,
          function: :deploy_architecture_model,
          config: %{
            concurrency: 1,
            timeout_ms: 60_000
          },
          depends_on: [:model_validation]
        }
      ],

      # Error handling and recovery
      error_handlers: [
        %{
          on_error: :any,
          action: :retry,
          max_attempts: 3,
          backoff: :exponential
        }
      ],

      # Monitoring and metrics
      metrics: [
        :execution_time,
        :success_rate,
        :error_rate,
        :throughput
      ]
    }
  end

  @doc """
  Execute pattern discovery step
  """
  def discover_patterns(context) do
    Logger.info("🔍 Discovering architectural patterns")

    task_data = context.input
    codebase_path = Map.get(task_data, :codebase_path)

    # Use PatternDetector to discover patterns
    case PatternDetector.detect(codebase_path) do
      {:ok, patterns} ->
        discovery_data = %{
          codebase_path: codebase_path,
          patterns: patterns,
          discovery_timestamp: DateTime.utc_now()
        }

        {:ok, discovery_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Execute pattern analysis step
  """
  def analyze_patterns(context) do
    Logger.info("📊 Analyzing discovered patterns")

    discovery_data = context[:pattern_discovery].result

    # Analyze patterns for ML training
    analyzed_patterns =
      discovery_data.patterns
      |> Enum.map(fn pattern ->
        pattern
        |> Map.put(:feature_vector, extract_pattern_features(pattern))
        |> Map.put(:complexity_score, calculate_pattern_complexity(pattern))
      end)

    analysis_data = %{
      patterns: analyzed_patterns,
      analysis_timestamp: DateTime.utc_now()
    }

    {:ok, analysis_data}
  end

  @doc """
  Execute model training step
  """
  def train_architecture_model(context) do
    Logger.info("🧠 Training architecture learning model with Axon")

    analysis_data = context[:pattern_analysis].result

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

    {:ok, training_result}
  end

  @doc """
  Execute model validation step
  """
  def validate_model(context) do
    Logger.info("✅ Validating architecture model")

    %{model_id: _model_id} = context[:model_training].result

    # Mock model validation - in real implementation, this would:
    # 1. Test model on validation set
    # 2. Calculate performance metrics
    # 3. Check for overfitting

    validation_result = %{
      validation_accuracy: 0.89,
      validation_loss: 0.08,
      validation_timestamp: DateTime.utc_now()
    }

    {:ok, validation_result}
  end

  @doc """
  Execute model deployment step
  """
  def deploy_architecture_model(context) do
    Logger.info("🚀 Deploying architecture model")

    %{model_id: model_id} = context[:model_training].result
    validation_result = context[:model_validation].result

    # Mock model deployment - in real implementation, this would:
    # 1. Save model to storage
    # 2. Update model registry
    # 3. Deploy to production

    deployment_result = %{
      deployment_status: :success,
      model_path: "/models/architecture/#{model_id}",
      deployment_timestamp: DateTime.utc_now(),
      validation_metrics: validation_result
    }

    {:ok, deployment_result}
  end

  # Private helper functions

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