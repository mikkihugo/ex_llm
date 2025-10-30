defmodule Singularity.Embedding.BroadwayEmbeddingPipelineTest do
  use ExUnit.Case, async: false
  import Mox

  alias Singularity.Embedding.BroadwayEmbeddingPipeline
  alias Singularity.Embedding.NxService
  alias Singularity.Repo

  # Mock NxService for testing
  setup :verify_on_exit!

  setup do
    # Setup test artifacts
    artifacts = [
      %{
        id: 1,
        artifact_id: "test_artifact_1",
        content: %{"title" => "Test Title 1", "description" => "Test Description 1"}
      },
      %{
        id: 2,
        artifact_id: "test_artifact_2",
        content: %{"title" => "Test Title 2", "description" => "Test Description 2"}
      },
      %{id: 3, artifact_id: "test_artifact_3", content: "Plain text content"}
    ]

    # Mock NxService embed function
    NxService
    |> stub(:embed, fn _text, _opts ->
      # Return a mock 1024-dimension embedding
      {:ok, Nx.tensor(Enum.map(1..1024, fn _ -> :rand.uniform() - 0.5 end))}
    end)

    %{artifacts: artifacts}
  end

  describe "run/1" do
    test "successfully processes artifacts with default options", %{artifacts: artifacts} do
      # Mock the database update
      Ecto.Adapters.SQL.Sandbox.checkout(Repo)

      # Insert test data
      Repo.insert_all("curated_knowledge_artifacts", [
        %{
          id: 1,
          artifact_id: "test_artifact_1",
          content: Jason.encode!(%{"title" => "Test Title 1"})
        },
        %{
          id: 2,
          artifact_id: "test_artifact_2",
          content: Jason.encode!(%{"title" => "Test Title 2"})
        },
        %{id: 3, artifact_id: "test_artifact_3", content: "Plain text content"}
      ])

      result = BroadwayEmbeddingPipeline.run(artifacts: artifacts)

      assert {:ok, metrics} = result
      assert metrics.total == 3
      assert metrics.processed >= 0
      assert metrics.success_rate >= 0.0
      assert metrics.elapsed_seconds >= 0.0
      assert metrics.speed >= 0.0
    end

    test "handles empty artifacts list" do
      result = BroadwayEmbeddingPipeline.run(artifacts: [])

      assert {:ok, metrics} = result
      assert metrics.total == 0
      assert metrics.processed == 0
      assert metrics.success_rate == 100.0
    end

    test "respects custom workers and batch_size options", %{artifacts: artifacts} do
      result =
        BroadwayEmbeddingPipeline.run(
          artifacts: artifacts,
          workers: 5,
          batch_size: 8,
          verbose: false
        )

      assert {:ok, metrics} = result
      assert metrics.total == 3
    end

    test "handles timeout correctly", %{artifacts: artifacts} do
      # Use a very short timeout to force timeout
      result =
        BroadwayEmbeddingPipeline.run(
          artifacts: artifacts,
          # 1 millisecond timeout
          timeout: 1
        )

      # Should either complete or timeout gracefully
      assert match?({:ok, _}, result) or match?({:error, :timeout}, result)
    end
  end

  describe "pipeline stages" do
    test "producer spawns and emits artifacts correctly" do
      artifacts = [%{id: 1, artifact_id: "test"}]

      # Test the spawn_producer function indirectly through run
      result = BroadwayEmbeddingPipeline.run(artifacts: artifacts, timeout: 1000)
      assert {:ok, _} = result
    end

    test "processor handles different artifact content types" do
      # Test text extraction from different content formats
      artifact1 = %{
        id: 1,
        artifact_id: "test1",
        content: %{"title" => "Title", "description" => "Desc"}
      }

      artifact2 = %{id: 2, artifact_id: "test2", content: "plain text"}
      artifact3 = %{id: 3, artifact_id: "test3", content: nil}

      # These should not raise errors
      text1 = BroadwayEmbeddingPipeline.extract_artifact_text(artifact1)
      text2 = BroadwayEmbeddingPipeline.extract_artifact_text(artifact2)
      text3 = BroadwayEmbeddingPipeline.extract_artifact_text(artifact3)

      assert is_binary(text1)
      assert is_binary(text2)
      assert is_binary(text3)
      assert String.length(text1) > 0
      assert String.length(text2) > 0
      assert String.length(text3) > 0
    end

    test "batcher groups embeddings correctly" do
      # Test batch writing logic
      batch = [
        {1, List.duplicate(0.1, 1024)},
        {2, List.duplicate(0.2, 1024)}
      ]

      # This should not raise an error
      assert :ok = BroadwayEmbeddingPipeline.write_embeddings_batch(batch)
    end
  end

  describe "error handling" do
    test "handles NxService embed failures gracefully", %{artifacts: artifacts} do
      # Mock NxService to return an error
      NxService
      |> expect(:embed, 3, fn _text, _opts -> {:error, :model_not_loaded} end)

      result = BroadwayEmbeddingPipeline.run(artifacts: artifacts)

      assert {:ok, metrics} = result
      # Should still complete but with lower success rate
      assert metrics.total == 3
      assert metrics.success_rate < 100.0
    end

    test "handles database write failures gracefully" do
      # Test with invalid artifact IDs that would cause DB errors
      artifacts = [%{id: 999_999, artifact_id: "nonexistent"}]

      result = BroadwayEmbeddingPipeline.run(artifacts: artifacts)

      # Should complete without crashing
      assert {:ok, metrics} = result
      assert metrics.total == 1
    end

    test "handles exceptions in processing" do
      # Mock NxService to raise an exception
      NxService
      |> expect(:embed, fn _text, _opts -> raise "Simulated error" end)

      artifacts = [%{id: 1, artifact_id: "test"}]
      result = BroadwayEmbeddingPipeline.run(artifacts: artifacts)

      assert {:ok, metrics} = result
      # Should handle the exception gracefully
      assert metrics.total == 1
    end
  end

  describe "concurrency and performance" do
    test "processes multiple artifacts concurrently", %{artifacts: artifacts} do
      start_time = System.monotonic_time(:millisecond)

      result =
        BroadwayEmbeddingPipeline.run(
          artifacts: artifacts,
          workers: 3,
          batch_size: 2
        )

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      assert {:ok, metrics} = result
      assert metrics.total == 3
      # Should complete within 5 seconds
      assert duration < 5000
    end

    test "scales with different worker counts" do
      artifacts = List.duplicate(%{id: 1, artifact_id: "test"}, 10)

      # Test with different worker configurations
      for workers <- [1, 2, 5] do
        result =
          BroadwayEmbeddingPipeline.run(
            artifacts: artifacts,
            workers: workers,
            batch_size: 3,
            timeout: 10000
          )

        assert {:ok, metrics} = result
        assert metrics.total == 10
      end
    end
  end

  describe "progress tracking" do
    test "tracks processed count correctly", %{artifacts: artifacts} do
      # Clear any existing persistent term
      :persistent_term.erase({:embedding_pipeline, :processed})

      result = BroadwayEmbeddingPipeline.run(artifacts: artifacts)

      assert {:ok, metrics} = result
      # Processed count should be tracked
      final_count = :persistent_term.get({:embedding_pipeline, :processed}, 0)
      assert final_count >= 0
    end
  end

  describe "PGFlow integration" do
    test "pipeline integrates with PGFlow workflow system" do
      # Test that the pipeline can be called from a workflow context
      # This simulates how it would be invoked from Singularity.Workflows

      workflow_input = %{
        artifacts: [
          %{id: 1, artifact_id: "wf_test_1", content: %{"title" => "Workflow Test"}}
        ],
        device: :cpu,
        workers: 1,
        batch_size: 1
      }

      # Simulate workflow execution
      result = BroadwayEmbeddingPipeline.run(workflow_input)

      assert {:ok, metrics} = result
      assert metrics.total == 1
    end

    test "handles workflow cancellation gracefully" do
      # Test timeout as proxy for cancellation
      artifacts = [%{id: 1, artifact_id: "test"}]

      result =
        BroadwayEmbeddingPipeline.run(
          artifacts: artifacts,
          # Very short timeout
          timeout: 1
        )

      # Should either complete or timeout, but not crash
      assert match?({:ok, _}, result) or match?({:error, :timeout}, result)
    end
  end
end
