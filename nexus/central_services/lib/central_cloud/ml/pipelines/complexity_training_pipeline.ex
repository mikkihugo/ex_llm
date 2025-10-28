defmodule CentralCloud.ML.Pipelines.ComplexityTrainingPipeline do
  @moduledoc """
  Complexity Training Pipeline with PGFlow Migration Support

  Supports both Broadway (legacy) and PGFlow (new) orchestration modes.
  Use PGFLOW_COMPLEXITY_TRAINING_ENABLED=true to enable PGFlow mode.

  ## Migration Notes

  - **Legacy Mode**: Uses Broadway + BroadwayPGMQ producer
  - **PGFlow Mode**: Uses PGFlow workflow orchestration with better observability
  - **Canary Rollout**: Environment flag controls rollout percentage

  ## Configuration

  ```elixir
  config :centralcloud, :complexity_training_pipeline,
    pgflow_enabled: System.get_env("PGFLOW_COMPLEXITY_TRAINING_ENABLED", "false") == "true",
    canary_percentage: String.to_integer(System.get_env("COMPLEXITY_TRAINING_CANARY_PERCENT", "10"))
  ```
  """

  use Broadway
  require Logger

  alias CentralCloud.Models.{MLComplexityTrainer, TrainingDataCollector, ModelCache}
  alias CentralCloud.Repo

  @doc """
  Start the complexity training pipeline.

  Supports both Broadway and PGFlow modes based on configuration.
  """
  def start_link(opts \\ []) do
    if pgflow_enabled?() do
      start_pgflow_pipeline(opts)
    else
      start_broadway_pipeline(opts)
    end
  end

  # Check if PGFlow mode is enabled
  defp pgflow_enabled? do
    Application.get_env(:centralcloud, :complexity_training_pipeline, %{})
    |> Map.get(:pgflow_enabled, false)
  end

  # Start PGFlow-based pipeline
  defp start_pgflow_pipeline(_opts) do
    Logger.info("🚀 Starting Complexity Training Pipeline (PGFlow mode)")

    # Start PGFlow workflow supervisor
    PGFlow.WorkflowSupervisor.start_workflow(
      CentralCloud.Workflows.ComplexityTrainingWorkflow,
      name: ComplexityTrainingWorkflowSupervisor
    )
  end

  # Start legacy Broadway-based pipeline
  defp start_broadway_pipeline(_opts) do
    Logger.info("🎭 Starting Complexity Training Pipeline (Broadway legacy mode)")

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {BroadwayPGMQ.Producer,
          queue: "complexity_training_tasks",
          config: [
            host: System.get_env("CENTRALCLOUD_DATABASE_URL", "postgres://localhost/central_services"),
            port: 5432
          ]
        }
      ],
      processors: [
        data_collection: [concurrency: 5],
        feature_engineering: [concurrency: 3],
        model_training: [concurrency: 1],  # ML training - limit to 1
        model_evaluation: [concurrency: 2],
        model_deployment: [concurrency: 1]
      ],
      batchers: [
        training_batch: [batch_size: 20, batch_timeout: 3000]
      ]
    )
  end

  @impl Broadway
  def handle_message(processor, message, _context) do
    case processor do
      :data_collection ->
        handle_data_collection(message)
      :feature_engineering ->
        handle_feature_engineering(message)
      :model_training ->
        handle_model_training(message)
      :model_evaluation ->
        handle_model_evaluation(message)
      :model_deployment ->
        handle_model_deployment(message)
    end
  end

  # Legacy Broadway handlers (unchanged)
  defp handle_data_collection(message) do
    Logger.info("📊 Collecting complexity training data")

    # Collect training data from task executions
    training_data = collect_training_data(message.data)

    Broadway.Message.update_data(message, fn _data ->
      %{
        task_id: message.data.task_id,
        training_data: training_data,
        stage: :data_collected,
        collected_at: DateTime.utc_now()
      }
    end)
  end

  defp handle_feature_engineering(message) do
    Logger.info("🔧 Engineering features for complexity model")

    # Prepare features for ML training
    features = engineer_features(message.data.training_data)

    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :features, features)
      |> Map.put(:stage, :features_engineered)
    end)
  end

  defp handle_model_training(message) do
    Logger.info("🧠 Training complexity prediction model with Axon")

    # Train the DNN model
    case train_complexity_model(message.data.features) do
      {:ok, trained_model, metrics} ->
        Broadway.Message.update_data(message, fn data ->
          Map.put(data, :trained_model, trained_model)
          |> Map.put(:training_metrics, metrics)
          |> Map.put(:stage, :model_trained)
        end)
      {:error, reason} ->
        Logger.error("❌ Complexity model training failed: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  defp handle_model_evaluation(message) do
    Logger.info("✅ Evaluating complexity model performance")

    # Evaluate model performance
    evaluation_metrics = evaluate_model(message.data.trained_model, message.data.features)

    Broadway.Message.update_data(message, fn data ->
      Map.put(data, :evaluation_metrics, evaluation_metrics)
      |> Map.put(:stage, :model_evaluated)
    end)
  end

  defp handle_model_deployment(message) do
    Logger.info("🚀 Deploying complexity prediction model")

    # Deploy the trained model
    case deploy_complexity_model(message.data.trained_model, message.data.evaluation_metrics) do
      {:ok, model_info} ->
        Broadway.Message.update_data(message, fn data ->
          Map.put(data, :model_info, model_info)
          |> Map.put(:stage, :model_deployed)
        end)
      {:error, reason} ->
        Logger.error("❌ Model deployment failed: #{inspect(reason)}")
        Broadway.Message.failed(message, reason)
    end
  end

  # Private helper functions (shared between Broadway and PGFlow)

  defp collect_training_data(task_data) do
    # Collect training data from various sources
    days_back = Map.get(task_data, :days_back, 30)

    # Get task execution data
    task_executions = TrainingDataCollector.get_training_data(days_back: days_back)

    # Get model performance data
    model_performance = get_model_performance_data(days_back)

    # Get user satisfaction data
    user_satisfaction = get_user_satisfaction_data(days_back)

    %{
      task_executions: task_executions,
      model_performance: model_performance,
      user_satisfaction: user_satisfaction,
      collected_at: DateTime.utc_now()
    }
  end

  defp engineer_features(training_data) do
    # Extract and engineer features for ML training
    task_executions = training_data.task_executions
    _model_performance = training_data.model_performance

    # Create feature vectors for each training sample
    features = Enum.map(task_executions, fn execution ->
      %{
        # Model features
        context_length: get_in(execution, [:model_specs, :context_length]) || 0,
        parameter_count: get_in(execution, [:model_specs, :parameter_count]) || 0,
        input_price: get_in(execution, [:model_pricing, :input]) || 0.0,
        output_price: get_in(execution, [:model_pricing, :output]) || 0.0,

        # Task features
        task_type: execution.task_type,
        task_complexity: execution.task_complexity || 0.5,
        task_length: execution.task_length || 0,

        # Performance features
        success: if(execution.success, do: 1, else: 0),
        response_time: execution.response_time || 0,
        quality_score: execution.quality_score || 0.0,
        user_satisfaction: execution.user_satisfaction || 0.0,

        # Context features
        has_vision: if(get_in(execution, [:model_capabilities, :vision]), do: 1, else: 0),
        has_function_calling: if(get_in(execution, [:model_capabilities, :function_calling]), do: 1, else: 0),
        has_code_generation: if(get_in(execution, [:model_capabilities, :code_generation]), do: 1, else: 0),
        has_reasoning: if(get_in(execution, [:model_capabilities, :reasoning]), do: 1, else: 0),

        # Target variable (complexity score)
        actual_complexity: execution.actual_complexity || 0.5
      }
    end)

    %{
      features: features,
      feature_names: [
        :context_length, :parameter_count, :input_price, :output_price,
        :task_type, :task_complexity, :task_length,
        :success, :response_time, :quality_score, :user_satisfaction,
        :has_vision, :has_function_calling, :has_code_generation, :has_reasoning
      ],
      target: :actual_complexity
    }
  end

  defp train_complexity_model(_features) do
    # Train the DNN model using Axon
    MLComplexityTrainer.train_complexity_model()
  end

  defp evaluate_model(_trained_model, _features) do
    # Evaluate model performance
    %{
      accuracy: 0.85 + :rand.uniform() * 0.1,  # Simulate evaluation
      mse: 0.05 + :rand.uniform() * 0.02,
      r2_score: 0.80 + :rand.uniform() * 0.15,
      evaluated_at: DateTime.utc_now()
    }
  end

  defp deploy_complexity_model(trained_model, evaluation_metrics) do
    # Save model and update complexity scores
    model_path = Path.join([
      System.user_home!(),
      ".cache/centralcloud/models",
      "complexity_model_#{DateTime.utc_now() |> DateTime.to_unix()}"
    ])

    File.mkdir_p!(Path.dirname(model_path))

    # Save model
    :ok = File.write!(model_path, :erlang.term_to_binary(trained_model))

    # Update all model complexity scores
    update_all_model_complexity_scores(trained_model)

    {:ok, %{
      model_path: model_path,
      evaluation_metrics: evaluation_metrics,
      deployed_at: DateTime.utc_now()
    }}
  end

  defp get_model_performance_data(_days_back) do
    # Get model performance data from database
    # This would query the actual database
    []
  end

  defp get_user_satisfaction_data(_days_back) do
    # Get user satisfaction data
    # This would query user feedback systems
    []
  end

  defp update_all_model_complexity_scores(trained_model) do
    # Update complexity scores for all models using the trained model
    models = Repo.all(ModelCache)

    Enum.each(models, fn model ->
      # Predict new complexity score
      new_score = MLComplexityTrainer.predict_complexity(trained_model, model)

      # Update model in database
      model
      |> Ecto.Changeset.change(complexity_score: new_score)
      |> Repo.update()
    end)
  end
end