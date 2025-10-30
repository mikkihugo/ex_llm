defmodule Singularity.Workflows.EmbeddingTrainingWorkflowTest do
  use ExUnit.Case, async: true
  # import Mox  # TODO: Set up Mox mocks

  alias Singularity.Workflows.EmbeddingTrainingWorkflow

   # setup :verify_on_exit!  # TODO: Enable after Mox setup

  describe "workflow_definition/0" do
    test "returns valid workflow definition" do
      definition = EmbeddingTrainingWorkflow.workflow_definition()

      assert definition.name == "embedding_training"
      assert definition.version == "1.0.0"
      assert length(definition.steps) == 5

      # Check step IDs
      step_ids = Enum.map(definition.steps, & &1.id)
      assert :data_collection in step_ids
      assert :data_preparation in step_ids
      assert :model_training in step_ids
      assert :model_validation in step_ids
      assert :model_deployment in step_ids
    end

    test "includes proper configuration" do
      definition = EmbeddingTrainingWorkflow.workflow_definition()

      assert definition.config.timeout_ms == 300_000
      assert definition.config.retries == 3
      assert definition.config.retry_delay_ms == 5000
      assert definition.config.concurrency == 1
    end

    test "defines correct step dependencies" do
      definition = EmbeddingTrainingWorkflow.workflow_definition()
      steps = Map.new(definition.steps, &{&1.id, &1})

      # Data collection has no dependencies
      assert steps[:data_collection].depends_on == nil

      # Data preparation depends on data collection
      assert steps[:data_preparation].depends_on == [:data_collection]

      # Model training depends on data preparation
      assert steps[:model_training].depends_on == [:data_preparation]

      # Model validation depends on model training
      assert steps[:model_validation].depends_on == [:model_training]

      # Model deployment depends on model validation
      assert steps[:model_deployment].depends_on == [:model_validation]
    end
  end

  describe "collect_training_data/1" do
    test "collects training data successfully" do
      # Mock the CodeStore
      expect(Singularity.CodeStore.Mock, :get_training_samples, fn [
                                                                     language: "elixir",
                                                                     min_length: 50,
                                                                     limit: 1000
                                                                   ] ->
        [%{code: "def test_function do\n  # test code\nend", context: "test context"}]
      end)

      context = %{input: %{language: "elixir", min_length: 50}}

      assert {:ok, result} = EmbeddingTrainingWorkflow.collect_training_data(context)

      assert is_list(result)
      assert length(result) == 1
      sample = hd(result)
      assert Map.has_key?(sample, :code)
      assert Map.has_key?(sample, :context)
    end
  end

  describe "prepare_training_data/1" do
    test "prepares Qodo training data" do
      raw_data = [
        %{code: "def test_function do\n  # test code\nend", context: "test context"}
      ]

      context = %{
        data_collection: %{result: raw_data},
        input: %{model_type: :qodo}
      }

      assert {:ok, result} = EmbeddingTrainingWorkflow.prepare_training_data(context)

      assert Map.has_key?(result, :anchor)
      assert Map.has_key?(result, :positive)
      assert Map.has_key?(result, :negative)
    end

    test "prepares Jina training data" do
      raw_data = [
        %{
          code: "def test_function do\n  # test code\nend",
          context: "test context",
          metadata: %{}
        }
      ]

      context = %{
        data_collection: %{result: raw_data},
        input: %{model_type: :jina}
      }

      assert {:ok, result} = EmbeddingTrainingWorkflow.prepare_training_data(context)

      assert Map.has_key?(result, :text)
      assert Map.has_key?(result, :context)
      assert Map.has_key?(result, :metadata)
    end

    test "prepares both models training data" do
      raw_data = [
        %{
          code: "def test_function do\n  # test code\nend",
          context: "test context",
          metadata: %{}
        }
      ]

      context = %{
        data_collection: %{result: raw_data},
        input: %{model_type: :both}
      }

      assert {:ok, result} = EmbeddingTrainingWorkflow.prepare_training_data(context)

      assert Map.has_key?(result, :qodo)
      assert Map.has_key?(result, :jina)
    end
  end

  describe "train_embedding_model/1" do
    test "trains Qodo model successfully" do
      prepared_data = [
        %{anchor: "code1", positive: "code1_mod", negative: "different_code"}
      ]

      # Mock the Trainer
      expect(Singularity.Embedding.Trainer.Mock, :new, fn :qodo, device: :cuda ->
        {:ok, %{model: "qodo_trainer"}}
      end)

      expect(Singularity.Embedding.Trainer.Mock, :train, fn %{model: "qodo_trainer"},
                                                            ^prepared_data,
                                                            [
                                                              epochs: 3,
                                                              learning_rate: 1.0e-5,
                                                              batch_size: 16
                                                            ] ->
        {:ok, %{accuracy: 0.85}}
      end)

      context = %{
        data_preparation: %{result: prepared_data},
        input: %{model_type: :qodo}
      }

      assert {:ok, result} = EmbeddingTrainingWorkflow.train_embedding_model(context)

      assert Map.has_key?(result, :trained_model)
      assert Map.has_key?(result, :training_metrics)
    end

    test "trains Jina model successfully" do
      prepared_data = [
        %{text: "code text", context: "context", metadata: %{}}
      ]

      # Mock the Trainer
      expect(Singularity.Embedding.Trainer.Mock, :new, fn :jina_v3, device: :cuda ->
        {:ok, %{model: "jina_trainer"}}
      end)

      expect(Singularity.Embedding.Trainer.Mock, :train, fn %{model: "jina_trainer"},
                                                            ^prepared_data,
                                                            [
                                                              epochs: 2,
                                                              learning_rate: 5.0e-6,
                                                              batch_size: 32
                                                            ] ->
        {:ok, %{accuracy: 0.80}}
      end)

      context = %{
        data_preparation: %{result: prepared_data},
        input: %{model_type: :jina}
      }

      assert {:ok, result} = EmbeddingTrainingWorkflow.train_embedding_model(context)

      assert Map.has_key?(result, :trained_model)
      assert Map.has_key?(result, :training_metrics)
    end

    test "handles training failure" do
      prepared_data = []

      # Mock training failure
      expect(Singularity.Embedding.Trainer.Mock, :new, fn :qodo, device: :cuda ->
        {:error, "GPU not available"}
      end)

      context = %{
        data_preparation: %{result: prepared_data},
        input: %{model_type: :qodo}
      }

      assert {:error, "GPU not available"} =
               EmbeddingTrainingWorkflow.train_embedding_model(context)
    end
  end

  describe "validate_model/1" do
    test "validates model performance" do
      trained_model = %{model: "trained_model"}

      context = %{
        model_training: %{result: %{trained_model: trained_model}},
        input: %{model_type: :qodo}
      }

      assert {:ok, result} = EmbeddingTrainingWorkflow.validate_model(context)

      assert Map.has_key?(result, :accuracy)
      assert Map.has_key?(result, :loss)
      assert Map.has_key?(result, :model_type)
      assert Map.has_key?(result, :model_size)
      assert Map.has_key?(result, :has_embeddings)
      assert Map.has_key?(result, :validated_at)

      assert result.accuracy >= 0.75
      assert result.accuracy <= 0.95
      assert result.model_type == :qodo
      assert %DateTime{} = result.validated_at
    end
  end

  describe "deploy_model/1" do
    test "deploys model successfully" do
      trained_model = %{model: "trained_model"}

      context = %{
        model_training: %{result: %{trained_model: trained_model}},
        input: %{model_type: :qodo}
      }

      assert {:ok, result} = EmbeddingTrainingWorkflow.deploy_model(context)

      assert Map.has_key?(result, :model_path)
      assert Map.has_key?(result, :deployed_at)

      assert String.contains?(result.model_path, "qodo_")
      assert String.ends_with?(result.model_path, ".bin")
      assert %DateTime{} = result.deployed_at
    end
  end
end
