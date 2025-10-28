defmodule CentralCloud.ML.Pipelines.ComplexityTrainingPipelinePGFlowIntegrationTest do
  use ExUnit.Case, async: false
  import Mox

  alias CentralCloud.ML.Pipelines.ComplexityTrainingPipeline
  alias CentralCloud.Workflows.ComplexityTrainingWorkflow

  setup :verify_on_exit!

  describe "PGFlow mode integration" do
    setup do
      # Set up PGFlow mode in application config
      original_config = Application.get_env(:centralcloud, :complexity_training_pipeline, %{})
      Application.put_env(:centralcloud, :complexity_training_pipeline,
        Map.put(original_config, :pgflow_enabled, true))

      on_exit(fn ->
        Application.put_env(:centralcloud, :complexity_training_pipeline, original_config)
      end)

      :ok
    end

    test "starts PGFlow workflow supervisor when enabled" do
      # Mock PGFlow.WorkflowSupervisor
      expect(PGFlow.WorkflowSupervisor.Mock, :start_workflow, fn
        ^ComplexityTrainingWorkflow, [name: ComplexityTrainingWorkflowSupervisor] ->
          {:ok, self()}
      end)

      assert {:ok, _pid} = ComplexityTrainingPipeline.start_link()
    end

    test "workflow executes complete pipeline successfully" do
      # Mock all the dependencies
      expect(CentralCloud.Models.TrainingDataCollector.Mock, :get_training_data, fn [days_back: 30] ->
        [%{task_id: "task_1", success: true, model_specs: %{context_length: 4096}}]
      end)

      expect(CentralCloud.Models.MLComplexityTrainer.Mock, :train_complexity_model, fn _features ->
        {:ok, %{model: "trained_model"}, %{accuracy: 0.85}}
      end)

      expect(CentralCloud.Repo.Mock, :all, fn CentralCloud.Models.ModelCache -> [] end)

      # Execute workflow
      workflow_input = %{days_back: 30}

      assert {:ok, execution_id} = PGFlow.Workflow.execute(ComplexityTrainingWorkflow, workflow_input)

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
      assert "Feature Engineering" in step_names
      assert "Model Training" in step_names
      assert "Model Evaluation" in step_names
      assert "Model Deployment" in step_names
    end

    test "workflow handles step failures gracefully" do
      # Mock training failure
      expect(CentralCloud.Models.TrainingDataCollector.Mock, :get_training_data, fn [days_back: 30] ->
        [%{task_id: "task_1", success: true}]
      end)

      expect(CentralCloud.Models.MLComplexityTrainer.Mock, :train_complexity_model, fn _features ->
        {:error, "GPU memory exhausted"}
      end)

      workflow_input = %{days_back: 30}

      assert {:ok, execution_id} = PGFlow.Workflow.execute(ComplexityTrainingWorkflow, workflow_input)

      # Wait for completion
      Process.sleep(100)

      # Verify workflow failed at training step
      assert {:ok, status} = PGFlow.Workflow.status(execution_id)
      assert status.state == :failed

      # Check that training step failed
      training_step = Enum.find(status.steps, &(&1.name == "Model Training"))
      assert training_step.status == :failed
      assert training_step.error == "GPU memory exhausted"
    end

    test "workflow respects concurrency limits" do
      # Mock dependencies
      expect(CentralCloud.Models.TrainingDataCollector.Mock, :get_training_data, 2, fn [days_back: 30] ->
        [%{task_id: "task_1", success: true}]
      end)

      expect(CentralCloud.Models.MLComplexityTrainer.Mock, :train_complexity_model, 2, fn _features ->
        {:ok, %{model: "trained_model"}, %{accuracy: 0.85}}
      end)

      expect(CentralCloud.Repo.Mock, :all, 2, fn CentralCloud.Models.ModelCache -> [] end)

      # Start multiple workflows
      workflow_input = %{days_back: 30}

      assert {:ok, execution_id1} = PGFlow.Workflow.execute(ComplexityTrainingWorkflow, workflow_input)
      assert {:ok, execution_id2} = PGFlow.Workflow.execute(ComplexityTrainingWorkflow, workflow_input)

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
      expect(CentralCloud.Models.TrainingDataCollector.Mock, :get_training_data, fn [days_back: 30] ->
        [%{task_id: "task_1", success: true}]
      end)

      expect(CentralCloud.Models.MLComplexityTrainer.Mock, :train_complexity_model, fn _features ->
        {:ok, %{model: "trained_model"}, %{accuracy: 0.85}}
      end)

      expect(CentralCloud.Repo.Mock, :all, fn CentralCloud.Models.ModelCache -> [] end)

      workflow_input = %{days_back: 30}

      assert {:ok, execution_id} = PGFlow.Workflow.execute(ComplexityTrainingWorkflow, workflow_input)

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
      original_config = Application.get_env(:centralcloud, :complexity_training_pipeline, %{})
      Application.put_env(:centralcloud, :complexity_training_pipeline,
        Map.put(original_config, :pgflow_enabled, false))

      on_exit(fn ->
        Application.put_env(:centralcloud, :complexity_training_pipeline, original_config)
      end)

      :ok
    end

    test "starts Broadway pipeline when PGFlow disabled" do
      # Mock Broadway.start_link
      expect(Broadway.Mock, :start_link, fn
        ComplexityTrainingPipeline,
        [
          name: ComplexityTrainingPipeline,
          producer: [
            module: {BroadwayPGMQ.Producer, _},
            _
          ],
          processors: _,
          batchers: _
        ] ->
          {:ok, self()}
      end)

      assert {:ok, _pid} = ComplexityTrainingPipeline.start_link()
    end

    test "Broadway pipeline processes messages correctly" do
      # This would test the Broadway message handling
      # In a real test, we'd set up Broadway test helpers
      message = %Broadway.Message{
        data: %{task_id: "test_task", days_back: 30},
        acknowledger: {Broadway.NoopAcknowledger, nil, nil}
      }

      # Test data collection handler
      result = ComplexityTrainingPipeline.handle_message(:data_collection, message, %{})
      assert %Broadway.Message{} = result
      assert result.data.stage == :data_collected
    end
  end

  describe "canary rollout support" do
    test "respects canary percentage configuration" do
      # Test canary rollout logic would go here
      # This would verify that only X% of requests use PGFlow mode

      config = Application.get_env(:centralcloud, :complexity_training_pipeline, %{})
      assert Map.has_key?(config, :canary_percentage)
      assert is_integer(config.canary_percentage)
      assert config.canary_percentage >= 0
      assert config.canary_percentage <= 100
    end
  end
end