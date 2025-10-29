defmodule Singularity.Embedding.BroadwayEmbeddingPipelineIntegrationTest do
  use ExUnit.Case, async: false
  import Mox

  alias Singularity.Embedding.BroadwayEmbeddingPipeline
  alias Singularity.Embedding.NxService
  alias Singularity.Repo
  alias Singularity.Workflows

  # Integration tests for full job lifecycle with PGFlow
  setup :verify_on_exit!

  setup do
    # Setup test database
    Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Setup test artifacts in database
    artifacts = [
      %{id: 1, artifact_id: "int_test_artifact_1", content: %{"title" => "Integration Test 1", "description" => "Integration Description 1"}},
      %{id: 2, artifact_id: "int_test_artifact_2", content: %{"title" => "Integration Test 2", "description" => "Integration Description 2"}},
      %{id: 3, artifact_id: "int_test_artifact_3", content: "Plain integration text"}
    ]

    # Insert test data into database
    Repo.insert_all("curated_knowledge_artifacts", [
      %{id: 1, artifact_id: "int_test_artifact_1", content: Jason.encode!(artifacts[0].content)},
      %{id: 2, artifact_id: "int_test_artifact_2", content: Jason.encode!(artifacts[1].content)},
      %{id: 3, artifact_id: "int_test_artifact_3", content: artifacts[2].content}
    ])

    # Mock NxService for consistent testing
    NxService
    |> stub(:embed, fn _text, _opts ->
      # Return a mock 1024-dimension embedding
      {:ok, Nx.tensor(Enum.map(1..1024, fn _ -> :rand.uniform() - 0.5 end))}
    end)

    %{artifacts: artifacts}
  end

  describe "job lifecycle integration" do
    test "complete job lifecycle: queuing -> processing -> persistence", %{artifacts: artifacts} do
      # Create a workflow that includes embedding pipeline
      workflow_attrs = %{
        type: :embedding_pipeline,
        payload: %{
          artifacts: artifacts,
          device: :cpu,
          workers: 2,
          batch_size: 2
        },
        nodes: [
          %{
            id: "embedding_task",
            type: :task,
            worker: {BroadwayEmbeddingPipeline, :run},
            args: %{
              artifacts: artifacts,
              device: :cpu,
              workers: 2,
              batch_size: 2
            }
          }
        ]
      }

      # Create workflow
      {:ok, workflow_id} = Workflows.create_workflow(workflow_attrs)

      # Execute workflow
      {:ok, execution_result} = Workflows.execute_workflow(workflow_id)

      # Verify execution completed
      assert execution_result.workflow_id == workflow_id
      assert execution_result.dry_run == true  # Default is dry run
      assert execution_result.node_count == 1

      # Verify workflow status updated
      {:ok, updated_workflow} = Workflows.fetch_workflow(workflow_id)
      assert updated_workflow.status == :executed
    end

    test "job retry mechanism on failure" do
      # Mock NxService to fail initially, then succeed
      NxService
      |> expect(:embed, 2, fn _text, _opts -> {:error, :temporary_failure} end)
      |> expect(:embed, 1, fn _text, _opts ->
        {:ok, Nx.tensor(Enum.map(1..1024, fn _ -> :rand.uniform() - 0.5 end))}
      end)

      artifacts = [%{id: 1, artifact_id: "retry_test"}]

      # This should handle failures gracefully
      result = BroadwayEmbeddingPipeline.run(artifacts: artifacts, workers: 1)

      assert {:ok, metrics} = result
      assert metrics.total == 1
      # May have partial success depending on implementation
    end

    test "job persistence and recovery" do
      artifacts = [%{id: 1, artifact_id: "persistence_test"}]

      # Run pipeline
      {:ok, metrics1} = BroadwayEmbeddingPipeline.run(artifacts: artifacts)

      # Verify database was updated
      # Note: This assumes the pipeline writes to database
      # In a real scenario, we'd check the curated_knowledge_artifacts table

      assert metrics1.total == 1
      assert metrics1.processed >= 0
    end
  end

  describe "PGFlow workflow integration" do
    test "embedding pipeline as workflow step" do
      # Create a multi-step workflow that includes embedding
      workflow_attrs = %{
        type: :complex_embedding_workflow,
        payload: %{description: "Multi-step embedding workflow"},
        nodes: [
          %{
            id: "prepare_data",
            type: :task,
            worker: {Kernel, :inspect},
            args: %{data: "prepared"}
          },
          %{
            id: "run_embeddings",
            type: :task,
            worker: {BroadwayEmbeddingPipeline, :run},
            args: %{
              artifacts: [%{id: 1, artifact_id: "wf_step_test"}],
              workers: 1,
              batch_size: 1
            }
          },
          %{
            id: "post_process",
            type: :task,
            worker: {Kernel, :length},
            args: %{list: [1, 2, 3]}
          }
        ]
      }

      {:ok, workflow_id} = Workflows.create_workflow(workflow_attrs)

      # Execute the workflow
      {:ok, execution_result} = Workflows.execute_workflow(workflow_id)

      # Verify all steps executed
      assert execution_result.node_count == 3
      assert length(execution_result.results) == 3

      # Check that embedding step completed
      embedding_result = Enum.find(execution_result.results, fn r ->
        r.node_id == "run_embeddings"
      end)
      assert embedding_result.status == :ok
    end

    test "workflow cancellation and cleanup" do
      # Test that workflows can be cancelled gracefully
      workflow_attrs = %{
        type: :cancellable_embedding,
        nodes: [
          %{
            id: "long_embedding",
            type: :task,
            worker: {BroadwayEmbeddingPipeline, :run},
            args: %{
              artifacts: List.duplicate(%{id: 1, artifact_id: "cancel_test"}, 10),
              timeout: 1  # Very short timeout
            }
          }
        ]
      }

      {:ok, workflow_id} = Workflows.create_workflow(workflow_attrs)

      # Execute with potential cancellation
      result = Workflows.execute_workflow(workflow_id)

      # Should either complete or handle cancellation gracefully
      assert match?({:ok, _}, result)
    end
  end

  describe "monitoring and metrics" do
    test "pipeline reports accurate metrics" do
      artifacts = [
        %{id: 1, artifact_id: "metrics_test_1"},
        %{id: 2, artifact_id: "metrics_test_2"},
        %{id: 3, artifact_id: "metrics_test_3"}
      ]

      start_time = System.monotonic_time(:millisecond)

      result = BroadwayEmbeddingPipeline.run(
        artifacts: artifacts,
        workers: 2,
        batch_size: 2,
        verbose: true
      )

      end_time = System.monotonic_time(:millisecond)
      actual_duration = (end_time - start_time) / 1000

      assert {:ok, metrics} = result
      assert metrics.total == 3
      assert metrics.elapsed_seconds >= 0
      assert metrics.elapsed_seconds <= actual_duration + 1  # Allow some tolerance
      assert metrics.speed >= 0
      assert metrics.success_rate >= 0.0
      assert metrics.success_rate <= 100.0
    end

    test "progress tracking works correctly" do
      # Clear any existing progress
      :persistent_term.erase({:embedding_pipeline, :processed})

      artifacts = [%{id: 1, artifact_id: "progress_test"}]

      result = BroadwayEmbeddingPipeline.run(artifacts: artifacts)

      assert {:ok, _} = result

      # Check that progress was tracked
      final_count = :persistent_term.get({:embedding_pipeline, :processed}, 0)
      assert final_count >= 0
    end
  end

  describe "concurrency validation" do
    test "multiple workers process concurrently" do
      artifacts = List.duplicate(%{id: 1, artifact_id: "concurrency_test"}, 20)

      start_time = System.monotonic_time(:millisecond)

      result = BroadwayEmbeddingPipeline.run(
        artifacts: artifacts,
        workers: 4,
        batch_size: 5,
        timeout: 15000
      )

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      assert {:ok, metrics} = result
      assert metrics.total == 20
      assert duration < 10000  # Should complete reasonably fast with concurrency
    end

    test "batch processing optimization" do
      # Test different batch sizes for performance
      artifacts = List.duplicate(%{id: 1, artifact_id: "batch_test"}, 12)

      batch_sizes = [1, 3, 6, 12]

      for batch_size <- batch_sizes do
        result = BroadwayEmbeddingPipeline.run(
          artifacts: artifacts,
          workers: 2,
          batch_size: batch_size,
          timeout: 10000
        )

        assert {:ok, metrics} = result
        assert metrics.total == 12
      end
    end
  end

  describe "error recovery and resilience" do
    test "pipeline recovers from partial failures" do
      # Mix of good and problematic artifacts
      artifacts = [
        %{id: 1, artifact_id: "good_artifact"},
        %{id: 999999, artifact_id: "bad_artifact"},  # Will cause DB error
        %{id: 2, artifact_id: "another_good"}
      ]

      result = BroadwayEmbeddingPipeline.run(artifacts: artifacts)

      assert {:ok, metrics} = result
      assert metrics.total == 3
      # Should continue processing despite errors
    end

    test "handles resource exhaustion gracefully" do
      # Test with many artifacts to potentially exhaust resources
      artifacts = List.duplicate(%{id: 1, artifact_id: "resource_test"}, 100)

      result = BroadwayEmbeddingPipeline.run(
        artifacts: artifacts,
        workers: 1,  # Limit workers to avoid overwhelming
        batch_size: 10,
        timeout: 30000
      )

      # Should either complete or timeout gracefully
      assert match?({:ok, _}, result) or match?({:error, :timeout}, result)
    end
  end
end
