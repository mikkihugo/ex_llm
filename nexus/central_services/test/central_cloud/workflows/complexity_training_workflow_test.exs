defmodule CentralCloud.Workflows.ComplexityTrainingWorkflowTest do
  use ExUnit.Case, async: true
  import Mox

  alias CentralCloud.Workflows.ComplexityTrainingWorkflow

  setup :verify_on_exit!

  describe "workflow_definition/0" do
    test "returns valid workflow definition" do
      definition = ComplexityTrainingWorkflow.workflow_definition()

      assert definition.name == "complexity_training"
      assert definition.version == "1.0.0"
      assert length(definition.steps) == 5

      # Check step IDs
      step_ids = Enum.map(definition.steps, & &1.id)
      assert :data_collection in step_ids
      assert :feature_engineering in step_ids
      assert :model_training in step_ids
      assert :model_evaluation in step_ids
      assert :model_deployment in step_ids
    end

    test "includes proper configuration" do
      definition = ComplexityTrainingWorkflow.workflow_definition()

      assert definition.config.timeout_ms == 300_000
      assert definition.config.retries == 3
      assert definition.config.retry_delay_ms == 5000
      assert definition.config.concurrency == 1
    end

    test "defines correct step dependencies" do
      definition = ComplexityTrainingWorkflow.workflow_definition()
      steps = Map.new(definition.steps, &{&1.id, &1})

      # Data collection has no dependencies
      assert steps[:data_collection].depends_on == nil

      # Feature engineering depends on data collection
      assert steps[:feature_engineering].depends_on == [:data_collection]

      # Model training depends on feature engineering
      assert steps[:model_training].depends_on == [:feature_engineering]

      # Model evaluation depends on model training
      assert steps[:model_evaluation].depends_on == [:model_training]

      # Model deployment depends on model evaluation
      assert steps[:model_deployment].depends_on == [:model_evaluation]
    end
  end

  describe "collect_training_data/1" do
    test "collects training data successfully" do
      # Mock the TrainingDataCollector
      expect(CentralCloud.Models.TrainingDataCollector.Mock, :get_training_data, fn [days_back: 30] ->
        [%{task_id: "task_1", success: true}]
      end)

      context = %{input: %{days_back: 30}}

      assert {:ok, result} = ComplexityTrainingWorkflow.collect_training_data(context)

      assert Map.has_key?(result, :task_executions)
      assert Map.has_key?(result, :model_performance)
      assert Map.has_key?(result, :user_satisfaction)
      assert Map.has_key?(result, :collected_at)
      assert %DateTime{} = result.collected_at
    end
  end

  describe "engineer_features/1" do
    test "engineers features from training data" do
      training_data = %{
        task_executions: [
          %{
            model_specs: %{context_length: 4096, parameter_count: 7_000_000_000},
            model_pricing: %{input: 0.0015, output: 0.002},
            task_type: "analysis",
            task_complexity: 0.8,
            task_length: 1000,
            success: true,
            response_time: 2500,
            quality_score: 0.9,
            user_satisfaction: 0.85,
            model_capabilities: %{vision: true, function_calling: false, code_generation: true, reasoning: true},
            actual_complexity: 0.75
          }
        ]
      }

      context = %{data_collection: %{result: training_data}}

      assert {:ok, result} = ComplexityTrainingWorkflow.engineer_features(context)

      assert Map.has_key?(result, :features)
      assert Map.has_key?(result, :feature_names)
      assert Map.has_key?(result, :target)

      assert length(result.features) == 1
      feature = hd(result.features)

      # Check feature values
      assert feature.context_length == 4096
      assert feature.parameter_count == 7_000_000_000
      assert feature.input_price == 0.0015
      assert feature.output_price == 0.002
      assert feature.task_type == "analysis"
      assert feature.success == 1
      assert feature.has_vision == 1
      assert feature.has_function_calling == 0
      assert feature.actual_complexity == 0.75
    end
  end

  describe "train_complexity_model/1" do
    test "trains model successfully" do
      features = %{features: [], feature_names: [], target: :actual_complexity}

      # Mock the MLComplexityTrainer
      expect(CentralCloud.Models.MLComplexityTrainer.Mock, :train_complexity_model, fn ^features ->
        {:ok, %{model: "trained_model"}, %{accuracy: 0.85}}
      end)

      context = %{feature_engineering: %{result: features}}

      assert {:ok, result} = ComplexityTrainingWorkflow.train_complexity_model(context)

      assert Map.has_key?(result, :trained_model)
      assert Map.has_key?(result, :training_metrics)
    end

    test "handles training failure" do
      features = %{features: [], feature_names: [], target: :actual_complexity}

      # Mock training failure
      expect(CentralCloud.Models.MLComplexityTrainer.Mock, :train_complexity_model, fn ^features ->
        {:error, "GPU memory exhausted"}
      end)

      context = %{feature_engineering: %{result: features}}

      assert {:error, "GPU memory exhausted"} = ComplexityTrainingWorkflow.train_complexity_model(context)
    end
  end

  describe "evaluate_model/1" do
    test "evaluates model performance" do
      trained_model = %{model: "trained_model"}
      features = %{features: []}

      context = %{
        model_training: %{result: trained_model},
        feature_engineering: %{result: features}
      }

      assert {:ok, result} = ComplexityTrainingWorkflow.evaluate_model(context)

      assert Map.has_key?(result, :accuracy)
      assert Map.has_key?(result, :mse)
      assert Map.has_key?(result, :r2_score)
      assert Map.has_key?(result, :evaluated_at)

      assert result.accuracy >= 0.75
      assert result.accuracy <= 0.95
      assert %DateTime{} = result.evaluated_at
    end
  end

  describe "deploy_complexity_model/1" do
    test "deploys model successfully" do
      trained_model = %{model: "trained_model"}
      evaluation_metrics = %{accuracy: 0.85}

      context = %{
        model_training: %{result: trained_model},
        model_evaluation: %{result: evaluation_metrics}
      }

      # Mock the Repo operations
      expect(CentralCloud.Repo.Mock, :all, fn CentralCloud.Models.ModelCache -> [] end)

      assert {:ok, result} = ComplexityTrainingWorkflow.deploy_complexity_model(context)

      assert Map.has_key?(result, :model_path)
      assert Map.has_key?(result, :evaluation_metrics)
      assert Map.has_key?(result, :deployed_at)

      assert String.contains?(result.model_path, "complexity_model_")
      assert %DateTime{} = result.deployed_at
    end
  end
end