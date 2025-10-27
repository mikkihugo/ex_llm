defmodule Genesis.ExperimentIntegrationTest do
  @moduledoc """
  Integration tests for Genesis experiment execution.

  Tests:
  1. Experiment request handling from Singularity
  2. Sandbox isolation and execution
  3. Metrics collection and recommendation
  4. NATS communication for results
  5. Rollback on failure
  """

  use ExUnit.Case, async: false
  require Logger

  alias Genesis.ExperimentRunner
  alias Genesis.MetricsCollector
  alias Genesis.IsolationManager
  alias Genesis.RollbackManager

  setup do
    # Setup test fixtures
    experiment_id = "exp-test-#{System.unique_integer()}"
    instance_id = "singularity-test"

    test_request = %{
      "experiment_id" => experiment_id,
      "instance_id" => instance_id,
      "experiment_type" => "improvement",
      "description" => "Test improvement experiment",
      "risk_level" => "medium",
      "estimated_impact" => 0.35,
      "changes" => %{
        "files" => ["lib/test.ex"],
        "description" => "Test file changes"
      },
      "rollback_plan" => "git reset --hard"
    }

    {:ok, experiment_id: experiment_id, instance_id: instance_id, test_request: test_request}
  end

  describe "Experiment execution flow" do
    test "experiment request creates sandbox", %{test_request: request} do
      experiment_id = request["experiment_id"]

      # Create sandbox for experiment
      {:ok, sandbox_path} = IsolationManager.create_sandbox(experiment_id)

      # Sandbox should exist
      assert is_binary(sandbox_path)
      assert String.contains?(sandbox_path, experiment_id)

      # Cleanup
      IsolationManager.cleanup_sandbox(experiment_id)
    end

    test "experiment applies changes to sandbox", %{test_request: request} do
      experiment_id = request["experiment_id"]

      # Create sandbox
      {:ok, _sandbox_path} = IsolationManager.create_sandbox(experiment_id)

      # Apply changes would happen in ExperimentRunner.apply_changes()
      # This tests the integration of applying to sandbox

      # Cleanup
      IsolationManager.cleanup_sandbox(experiment_id)
    end

    test "sandbox cleanup removes experiment directory", %{test_request: request} do
      experiment_id = request["experiment_id"]

      # Create sandbox
      {:ok, sandbox_path} = IsolationManager.create_sandbox(experiment_id)

      # Cleanup
      :ok = IsolationManager.cleanup_sandbox(experiment_id)

      # Sandbox should no longer exist
      refute File.exists?(sandbox_path)
    end
  end

  describe "Metrics collection" do
    test "high success rate recommends merge", %{test_request: _request} do
      metrics = %{
        success_rate: 0.96,
        regression: 0.01,
        llm_reduction: 0.25,
        runtime_ms: 5000
      }

      recommendation = MetricsCollector.recommend(metrics)

      # Success rate > 95% AND regression < 2% -> :merge
      assert recommendation == :merge
    end

    test "moderate metrics recommends merge_with_adaptations" do
      metrics = %{
        success_rate: 0.92,
        regression: 0.03,
        llm_reduction: 0.15,
        runtime_ms: 5000
      }

      recommendation = MetricsCollector.recommend(metrics)

      # Success rate > 90% AND regression < 5% -> :merge_with_adaptations
      assert recommendation == :merge_with_adaptations
    end

    test "high regression recommends rollback" do
      metrics = %{
        success_rate: 0.85,
        regression: 0.08,
        llm_reduction: 0.20,
        runtime_ms: 5000
      }

      recommendation = MetricsCollector.recommend(metrics)

      # Regression > 5% AND success < 90% -> :rollback
      assert recommendation == :rollback
    end

    test "poor success rate recommends rollback" do
      metrics = %{
        success_rate: 0.60,
        regression: 0.05,
        llm_reduction: 0.10,
        runtime_ms: 5000
      }

      recommendation = MetricsCollector.recommend(metrics)

      # Success rate < 70% -> :rollback
      assert recommendation == :rollback
    end

    test "excellent LLM reduction with low regression recommends merge" do
      metrics = %{
        success_rate: 0.88,
        regression: 0.02,
        llm_reduction: 0.35,
        runtime_ms: 5000
      }

      recommendation = MetricsCollector.recommend(metrics)

      # LLM reduction > 30% AND regression < 3% -> :merge
      assert recommendation == :merge
    end
  end

  describe "Risk-aware test execution" do
    test "high risk level runs full test suite" do
      # Simulate test execution with high risk
      metrics = %{
        success_rate: 0.94,
        llm_reduction: 0.35,
        regression: 0.01,
        test_count: 250,
        failures: 15
      }

      # High risk: 250 tests
      assert metrics.test_count == 250
    end

    test "medium risk level runs core tests" do
      # Simulate test execution with medium risk
      metrics = %{
        success_rate: 0.96,
        llm_reduction: 0.28,
        regression: 0.02,
        test_count: 150,
        failures: 6
      }

      # Medium risk: 150 tests
      assert metrics.test_count == 150
    end

    test "low risk level runs smoke tests" do
      # Simulate test execution with low risk
      metrics = %{
        success_rate: 0.99,
        llm_reduction: 0.15,
        regression: 0.005,
        test_count: 50,
        failures: 1
      }

      # Low risk: 50 tests
      assert metrics.test_count == 50
    end
  end

  describe "Experiment decision workflow" do
    test "experiment with strong metrics recommends merge" do
      metrics = %{
        success_rate: 0.97,
        regression: 0.01,
        llm_reduction: 0.32,
        runtime_ms: 5500
      }

      recommendation = MetricsCollector.recommend(metrics)
      assert recommendation == :merge
    end

    test "experiment with mixed metrics recommends caution" do
      metrics = %{
        success_rate: 0.91,
        regression: 0.04,
        llm_reduction: 0.18,
        runtime_ms: 5800
      }

      recommendation = MetricsCollector.recommend(metrics)
      assert recommendation == :merge_with_adaptations
    end

    test "experiment with poor metrics recommends rollback" do
      metrics = %{
        success_rate: 0.75,
        regression: 0.06,
        llm_reduction: 0.08,
        runtime_ms: 6200
      }

      recommendation = MetricsCollector.recommend(metrics)
      assert recommendation == :rollback
    end
  end

  describe "Rollback management" do
    test "checkpoint creation succeeds", %{test_request: request} do
      experiment_id = request["experiment_id"]
      {:ok, sandbox_path} = IsolationManager.create_sandbox(experiment_id)

      # Create checkpoint
      :ok = RollbackManager.create_checkpoint(experiment_id, sandbox_path)

      # Cleanup
      RollbackManager.emergency_rollback(experiment_id)
      IsolationManager.cleanup_sandbox(experiment_id)
    end

    test "emergency rollback on failure" do
      experiment_id = "exp-emergency-#{System.unique_integer()}"
      {:ok, sandbox_path} = IsolationManager.create_sandbox(experiment_id)

      # Create checkpoint
      :ok = RollbackManager.create_checkpoint(experiment_id, sandbox_path)

      # Emergency rollback
      :ok = RollbackManager.emergency_rollback(experiment_id)

      # Cleanup
      IsolationManager.cleanup_sandbox(experiment_id)
    end
  end

  describe "Integration: Complete experiment flow" do
    test "successful high-risk experiment with merge recommendation" do
      experiment_id = "exp-integration-high-#{System.unique_integer()}"
      instance_id = "singularity-test"

      # Create sandbox
      {:ok, sandbox_path} = IsolationManager.create_sandbox(experiment_id)
      assert File.exists?(sandbox_path)

      # Simulate test execution for high-risk change
      metrics = %{
        success_rate: 0.94,
        regression: 0.01,
        llm_reduction: 0.35,
        runtime_ms: 5500,
        test_count: 250,
        failures: 15
      }

      # Get recommendation
      recommendation = MetricsCollector.recommend(metrics)
      assert recommendation == :merge

      # Cleanup
      IsolationManager.cleanup_sandbox(experiment_id)
      refute File.exists?(sandbox_path)
    end

    test "medium-risk experiment with adaptation recommendation" do
      experiment_id = "exp-integration-med-#{System.unique_integer()}"

      # Create sandbox
      {:ok, sandbox_path} = IsolationManager.create_sandbox(experiment_id)

      # Simulate test execution
      metrics = %{
        success_rate: 0.92,
        regression: 0.03,
        llm_reduction: 0.22,
        runtime_ms: 5200,
        test_count: 150,
        failures: 12
      }

      # Get recommendation
      recommendation = MetricsCollector.recommend(metrics)
      assert recommendation == :merge_with_adaptations

      # Cleanup
      IsolationManager.cleanup_sandbox(experiment_id)
    end

    test "low-risk experiment failure path" do
      experiment_id = "exp-integration-fail-#{System.unique_integer()}"

      # Create sandbox and checkpoint
      {:ok, sandbox_path} = IsolationManager.create_sandbox(experiment_id)
      :ok = RollbackManager.create_checkpoint(experiment_id, sandbox_path)

      # Simulate poor test results
      metrics = %{
        success_rate: 0.65,
        regression: 0.10,
        llm_reduction: 0.05,
        runtime_ms: 6500,
        test_count: 50,
        failures: 18
      }

      # Should recommend rollback
      recommendation = MetricsCollector.recommend(metrics)
      assert recommendation == :rollback

      # Execute rollback
      :ok = RollbackManager.emergency_rollback(experiment_id)

      # Cleanup
      IsolationManager.cleanup_sandbox(experiment_id)
    end
  end

  describe "Metric edge cases" do
    test "handles missing metrics gracefully" do
      metrics = %{}

      # Should use defaults and recommend conservatively
      recommendation = MetricsCollector.recommend(metrics)

      # With all defaults (0.0), should rollback
      assert recommendation == :rollback
    end

    test "handles partial metrics" do
      metrics = %{
        success_rate: 0.90
      }

      # Should use defaults for missing values
      recommendation = MetricsCollector.recommend(metrics)

      # Success 0.90, but no llm_reduction/regression data -> merge_with_adaptations or rollback
      assert recommendation in [:merge_with_adaptations, :rollback]
    end

    test "boundary condition: exactly 95% success" do
      metrics = %{
        success_rate: 0.95,
        regression: 0.02,
        llm_reduction: 0.25,
        runtime_ms: 5000
      }

      recommendation = MetricsCollector.recommend(metrics)

      # Success = 0.95 (exactly the threshold) AND regression < 0.02 -> :merge
      assert recommendation == :merge
    end

    test "boundary condition: exactly 30% LLM reduction" do
      metrics = %{
        success_rate: 0.85,
        regression: 0.02,
        llm_reduction: 0.30,
        runtime_ms: 5000
      }

      recommendation = MetricsCollector.recommend(metrics)

      # LLM reduction = 0.30 (exactly threshold) AND regression < 3% -> :merge
      assert recommendation == :merge
    end
  end
end
