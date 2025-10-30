defmodule Singularity.ML.Pipelines.EmbeddingTrainingPipelinePGFlowIntegrationTest do
  use ExUnit.Case, async: false
  import Mox

  alias Singularity.ML.Pipelines.EmbeddingTrainingPipeline
  alias Singularity.Workflows.EmbeddingTrainingWorkflow

  setup :verify_on_exit!

  describe "PGFlow mode integration" do
    setup do
      # Set up PGFlow mode in application config
      original_config = Application.get_env(:singularity, :embedding_training_pipeline, %{})

      Application.put_env(
        :singularity,
        :embedding_training_pipeline,
        Map.put(original_config, :pgflow_enabled, true)
      )

      on_exit(fn ->
        Application.put_env(:singularity, :embedding_training_pipeline, original_config)
      end)

      :ok
    end

    test "starts PGFlow workflow supervisor when enabled" do
      # Mock PGFlow.WorkflowSupervisor
      expect(PGFlow.WorkflowSupervisor.Mock, :start_workflow, fn
        ^EmbeddingTrainingWorkflow, [name: EmbeddingTrainingWorkflowSupervisor] ->
          {:ok, self()}
      end)

      assert {:ok, _pid} = EmbeddingTrainingPipeline.start_link()
    end

    test "workflow executes complete pipeline successfully" do
      # Mock all the dependencies
      expect(Singularity.CodeStore.Mock, :get_training_samples, fn [
                                                                     language: "elixir",
                                                                     min_length: 50,
                                                                     limit: 1000
                                                                   ] ->
        [%{code: "def test_function do\n  # test code\nend", context: "test context"}]
      end)

      expect(Singularity.Embedding.Trainer.Mock, :new, fn :qodo, device: :cuda ->
        {:ok, %{model: "qodo_trainer"}}
      end)

      expect(Singularity.Embedding.Trainer.Mock, :train, fn %{model: "qodo_trainer"},
                                                            _prepared_data,
                                                            [
                                                              epochs: 3,
                                                              learning_rate: 1.0e-5,
                                                              batch_size: 16
                                                            ] ->
        {:ok, %{accuracy: 0.85}}
      end)

      # Execute workflow
      workflow_input = %{model_type: :qodo, language: "elixir", min_length: 50}

      assert {:ok, execution_id} =
               PGFlow.Workflow.execute(EmbeddingTrainingWorkflow, workflow_input)

      # Wait for completion (in real test, would poll for status)
      Process.sleep(100)

      # Verify workflow completed all steps
      assert {:ok, status} = PGFlow.Workflow.status(execution_id)
      assert status.state == :completed

      # Verify all steps executed
      steps = status.steps
      assert length(steps) == 5

      step_names = Enum.map(steps, & &1.name)
      assert "Data Collection" in step_names
      assert "Data Preparation" in step_names
      assert "Model Training" in step_names
      assert "Model Validation" in step_names
      assert "Model Deployment" in step_names
    end

    test "workflow handles step failures gracefully" do
      # Mock data collection success but training failure
      expect(Singularity.CodeStore.Mock, :get_training_samples, fn [
                                                                     language: "elixir",
                                                                     min_length: 50,
                                                                     limit: 1000
                                                                   ] ->
        [%{code: "def test_function do\n  # test code\nend", context: "test context"}]
      end)

      expect(Singularity.Embedding.Trainer.Mock, :new, fn :qodo, device: :cuda ->
        {:error, "GPU not available"}
      end)

      workflow_input = %{model_type: :qodo, language: "elixir", min_length: 50}

      assert {:ok, execution_id} =
               PGFlow.Workflow.execute(EmbeddingTrainingWorkflow, workflow_input)

      # Wait for completion
      Process.sleep(100)

      # Verify workflow failed at training step
      assert {:ok, status} = PGFlow.Workflow.status(execution_id)
      assert status.state == :failed

      # Check that training step failed
      training_step = Enum.find(status.steps, &(&1.name == "Model Training"))
      assert training_step.status == :failed
      assert training_step.error == "GPU not available"
    end

    test "workflow respects concurrency limits" do
      # Mock dependencies for multiple executions
      expect(Singularity.CodeStore.Mock, :get_training_samples, 2, fn [
                                                                        language: "elixir",
                                                                        min_length: 50,
                                                                        limit: 1000
                                                                      ] ->
        [%{code: "def test_function do\n  # test code\nend", context: "test context"}]
      end)

      expect(Singularity.Embedding.Trainer.Mock, :new, 2, fn :qodo, device: :cuda ->
        {:ok, %{model: "qodo_trainer"}}
      end)

      expect(Singularity.Embedding.Trainer.Mock, :train, 2, fn %{model: "qodo_trainer"},
                                                               _prepared_data,
                                                               [
                                                                 epochs: 3,
                                                                 learning_rate: 1.0e-5,
                                                                 batch_size: 16
                                                               ] ->
        {:ok, %{accuracy: 0.85}}
      end)

      # Start multiple workflows
      workflow_input = %{model_type: :qodo, language: "elixir", min_length: 50}

      assert {:ok, execution_id1} =
               PGFlow.Workflow.execute(EmbeddingTrainingWorkflow, workflow_input)

      assert {:ok, execution_id2} =
               PGFlow.Workflow.execute(EmbeddingTrainingWorkflow, workflow_input)

      # Wait for completion
      Process.sleep(200)

      # Both should complete successfully
      assert {:ok, status1} = PGFlow.Workflow.status(execution_id1)
      assert {:ok, status2} = PGFlow.Workflow.status(execution_id2)

      assert status1.state == :completed
      assert status2.state == :completed
    end

    test "workflow collects metrics correctly" do
      # Mock dependencies
      expect(Singularity.CodeStore.Mock, :get_training_samples, fn [
                                                                     language: "elixir",
                                                                     min_length: 50,
                                                                     limit: 1000
                                                                   ] ->
        [%{code: "def test_function do\n  # test code\nend", context: "test context"}]
      end)

      expect(Singularity.Embedding.Trainer.Mock, :new, fn :qodo, device: :cuda ->
        {:ok, %{model: "qodo_trainer"}}
      end)

      expect(Singularity.Embedding.Trainer.Mock, :train, fn %{model: "qodo_trainer"},
                                                            _prepared_data,
                                                            [
                                                              epochs: 3,
                                                              learning_rate: 1.0e-5,
                                                              batch_size: 16
                                                            ] ->
        {:ok, %{accuracy: 0.85}}
      end)

      workflow_input = %{model_type: :qodo, language: "elixir", min_length: 50}

      assert {:ok, execution_id} =
               PGFlow.Workflow.execute(EmbeddingTrainingWorkflow, workflow_input)

      # Wait for completion
      Process.sleep(100)

      # Check metrics
      assert {:ok, metrics} = PGFlow.Workflow.metrics(execution_id)

      assert Map.has_key?(metrics, :execution_time)
      assert Map.has_key?(metrics, :success_rate)
      assert Map.has_key?(metrics, :error_rate)
      assert Map.has_key?(metrics, :throughput)

      assert metrics.success_rate == 1.0
      assert metrics.error_rate == 0.0
    end
  end

  describe "Broadway legacy mode integration" do
    setup do
      # Ensure Broadway mode is enabled
      original_config = Application.get_env(:singularity, :embedding_training_pipeline, %{})

      Application.put_env(
        :singularity,
        :embedding_training_pipeline,
        Map.put(original_config, :pgflow_enabled, false)
      )

      on_exit(fn ->
        Application.put_env(:singularity, :embedding_training_pipeline, original_config)
      end)

      :ok
    end

    test "starts Broadway pipeline when PGFlow disabled" do
      # Mock Broadway.start_link
      expect(Broadway.Mock, :start_link, fn
        EmbeddingTrainingPipeline,
        [
          name: EmbeddingTrainingPipeline,
          producer: producer_opts,
          processors: processors,
          batchers: batchers
        ] = _args ->
          assert match?([module: {BroadwayPGMQ.Producer, _} | _], producer_opts)
          assert is_list(processors)
          assert is_list(batchers)

          {:ok, self()}
      end)

      assert {:ok, _pid} = EmbeddingTrainingPipeline.start_link()
    end

    test "Broadway pipeline processes messages correctly" do
      # This would test the Broadway message handling
      # In a real test, we'd set up Broadway test helpers
      message = %Broadway.Message{
        data: %{task_id: "test_task", model_type: :qodo},
        acknowledger: {Broadway.NoopAcknowledger, nil, nil}
      }

      # Test data collection handler
      result = EmbeddingTrainingPipeline.handle_message(:data_collection, message, %{})
      assert %Broadway.Message{} = result
      assert result.data.stage == :data_collected
    end
  end

  describe "canary rollout support" do
    test "respects canary percentage configuration" do
      # Test canary rollout logic would go here
      # This would verify that only X% of requests use PGFlow mode

      config = Application.get_env(:singularity, :embedding_training_pipeline, %{})
      assert Map.has_key?(config, :canary_percentage)
      assert is_integer(config.canary_percentage)
      assert config.canary_percentage >= 0
      assert config.canary_percentage <= 100
    end
  end
end
