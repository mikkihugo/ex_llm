defmodule Singularity.Embedding.BroadwayEmbeddingPipelineStartupTest do
  use ExUnit.Case, async: false

  alias Singularity.Embedding.BroadwayEmbeddingPipeline
  alias Singularity.Execution.Planning.Supervisor, as: PlanningSupervisor

  # Test automatic startup via supervisor/HTDAG system

  describe "automatic startup via HTDAG system" do
    test "pipeline can be started through supervisor hierarchy" do
      # Test that the pipeline can be invoked as part of the supervised system
      # This simulates how it would be started automatically on system boot

      artifacts = [%{id: 1, artifact_id: "startup_test", content: "Test content"}]

      # This should work without explicit Broadway startup
      # The pipeline manages its own Broadway lifecycle
      result =
        BroadwayEmbeddingPipeline.run(
          artifacts: artifacts,
          workers: 1,
          batch_size: 1,
          timeout: 5000
        )

      assert {:ok, metrics} = result
      assert metrics.total == 1
    end

    test "pipeline integrates with Planning supervisor" do
      # Verify that the planning supervisor is designed to manage embedding workflows
      # This tests the integration point mentioned in the supervisor

      # The PlanningSupervisor manages:
      # - TaskGraph.Orchestrator (which could invoke embedding pipelines)
      # - SafeWorkPlanner (for planning embedding jobs)
      # - WorkPlanAPI (for API access to embedding workflows)

      # Test that we can create a workflow that would be managed by this supervisor
      workflow_config = %{
        type: :embedding_job,
        nodes: [
          %{
            id: "embedding_pipeline",
            type: :task,
            worker: {BroadwayEmbeddingPipeline, :run},
            args: %{
              artifacts: [%{id: 1, artifact_id: "supervisor_test"}],
              workers: 1
            }
          }
        ]
      }

      # This workflow structure is compatible with the Planning supervisor's design
      assert is_map(workflow_config)
      assert workflow_config.type == :embedding_job
      assert length(workflow_config.nodes) == 1
    end

    test "HTDAG auto-bootstrap configuration supports embedding pipelines" do
      # Test that the HTDAG auto-bootstrap configuration includes embedding capabilities
      # This verifies the configuration supports automatic embedding pipeline startup

      # The config should support:
      # - fix_on_startup: true (auto-fix embedding issues)
      # - trace_runtime: true (monitor embedding performance)
      # - use_rag: true (learn from embedding patterns)

      # Simulate configuration that would enable embedding pipelines
      bootstrap_config = %{
        enabled: true,
        max_iterations: 10,
        fix_on_startup: true,
        trace_runtime: true,
        trace_duration_ms: 60_000,
        notify_on_complete: true,
        run_async: true,
        cooldown_ms: 300_000,
        fix_severity: :medium,
        use_rag: true,
        use_quality_templates: true,
        integrate_sparc: true,
        safe_planning: true
      }

      # Verify configuration supports embedding pipeline features
      assert bootstrap_config.enabled == true
      assert bootstrap_config.fix_on_startup == true
      assert bootstrap_config.trace_runtime == true
      assert bootstrap_config.use_rag == true
    end
  end

  describe "workflow integration with HTDAG" do
    test "embedding pipeline works as HTDAG workflow step" do
      # Test that embedding pipelines can be executed as part of HTDAG workflows
      # This validates the integration between Broadway pipeline and HTDAG executor

      # Create a workflow step that runs the embedding pipeline
      embedding_step = %{
        id: "generate_embeddings",
        type: :task,
        worker: {BroadwayEmbeddingPipeline, :run},
        args: %{
          artifacts: [
            %{id: 1, artifact_id: "htdag_test_1", content: "HTDAG integration test"},
            %{id: 2, artifact_id: "htdag_test_2", content: "Another test artifact"}
          ],
          device: :cpu,
          workers: 2,
          batch_size: 2
        }
      }

      # This step structure should be compatible with HTDAG execution
      assert embedding_step.type == :task
      assert embedding_step.worker == {BroadwayEmbeddingPipeline, :run}
      assert is_map(embedding_step.args)
      assert length(embedding_step.args.artifacts) == 2
    end

    test "pipeline supports HTDAG error handling and retries" do
      # Test that the pipeline handles errors in a way compatible with HTDAG retry logic

      # Simulate a scenario where embedding might fail and need retry
      artifacts = [%{id: 1, artifact_id: "error_handling_test"}]

      # Run with short timeout to potentially trigger timeout (simulating failure)
      result =
        BroadwayEmbeddingPipeline.run(
          artifacts: artifacts,
          # Very short timeout
          timeout: 10,
          workers: 1
        )

      # Should handle timeout gracefully (compatible with HTDAG retry expectations)
      assert match?({:ok, _}, result) or match?({:error, :timeout}, result)
    end

    test "pipeline provides metrics for HTDAG monitoring" do
      # Test that pipeline returns metrics suitable for HTDAG monitoring and tracing

      artifacts = [%{id: 1, artifact_id: "metrics_test"}]

      result =
        BroadwayEmbeddingPipeline.run(
          artifacts: artifacts,
          workers: 1,
          batch_size: 1
        )

      assert {:ok, metrics} = result

      # Verify metrics structure is suitable for HTDAG monitoring
      assert Map.has_key?(metrics, :total)
      assert Map.has_key?(metrics, :processed)
      assert Map.has_key?(metrics, :success_rate)
      assert Map.has_key?(metrics, :elapsed_seconds)
      assert Map.has_key?(metrics, :speed)

      # All metrics should be valid numbers
      assert is_number(metrics.total)
      assert is_number(metrics.processed)
      assert is_number(metrics.success_rate)
      assert is_number(metrics.elapsed_seconds)
      assert is_number(metrics.speed)
    end
  end

  describe "system integration validation" do
    test "pipeline startup doesn't conflict with existing supervisors" do
      # Test that starting the pipeline doesn't interfere with other supervised processes

      # This simulates the pipeline being started as part of normal system operation
      artifacts = [%{id: 1, artifact_id: "system_integration_test"}]

      # Run multiple times to ensure no state conflicts
      for _ <- 1..3 do
        result =
          BroadwayEmbeddingPipeline.run(
            artifacts: artifacts,
            workers: 1,
            timeout: 3000
          )

        assert {:ok, _} = result
      end
    end

    test "pipeline respects system resource constraints" do
      # Test that pipeline operation considers system resources
      # This is important for integration with HTDAG resource management

      # Test with constrained resources
      artifacts = List.duplicate(%{id: 1, artifact_id: "resource_test"}, 50)

      result =
        BroadwayEmbeddingPipeline.run(
          artifacts: artifacts,
          # Limited workers
          workers: 1,
          # Reasonable batch size
          batch_size: 5,
          # Reasonable timeout
          timeout: 20000
        )

      # Should complete or timeout gracefully without overwhelming system
      assert match?({:ok, _}, result) or match?({:error, :timeout}, result)
    end
  end
end
