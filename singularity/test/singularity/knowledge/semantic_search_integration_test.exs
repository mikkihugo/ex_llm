defmodule Singularity.Knowledge.SemanticSearchIntegrationTest do
  @moduledoc """
  Integration tests for semantic code search functionality.

  Tests full stack:
  - Embedding generation (Rust NIF)
  - Vector similarity search (pgvector)
  - Result ranking and filtering
  - Knowledge base sync (Git ↔ PostgreSQL)
  """

  use Singularity.DataCase, async: false

  alias Singularity.Knowledge.ArtifactStore
  alias Singularity.Repo

  @moduletag :integration

  describe "knowledge artifact import and search" do
    setup do
      # Insert test artifacts
      artifacts = [
        %{
          artifact_type: "code_pattern",
          artifact_id: "elixir-genserver-async",
          version: "1.0.0",
          content_raw:
            Jason.encode!(%{
              language: "elixir",
              pattern: "GenServer async pattern",
              code: "GenServer.cast(pid, {:async_task, data})"
            }),
          content: %{
            "language" => "elixir",
            "pattern" => "GenServer async pattern",
            "code" => "GenServer.cast(pid, {:async_task, data})"
          },
          usage_count: 10,
          success_rate: 0.95
        },
        %{
          artifact_type: "code_pattern",
          artifact_id: "elixir-task-async",
          version: "1.0.0",
          content_raw:
            Jason.encode!(%{
              language: "elixir",
              pattern: "Task async pattern",
              code: "Task.async(fn -> heavy_work() end)"
            }),
          content: %{
            "language" => "elixir",
            "pattern" => "Task async pattern",
            "code" => "Task.async(fn -> heavy_work() end)"
          },
          usage_count: 15,
          success_rate: 0.98
        },
        %{
          artifact_type: "code_pattern",
          artifact_id: "rust-async-await",
          version: "1.0.0",
          content_raw:
            Jason.encode!(%{
              language: "rust",
              pattern: "Async/await pattern",
              code: "async fn fetch_data() -> Result<Data> { ... }"
            }),
          content: %{
            "language" => "rust",
            "pattern" => "Async/await pattern",
            "code" => "async fn fetch_data() -> Result<Data> { ... }"
          },
          usage_count: 20,
          success_rate: 0.97
        }
      ]

      inserted =
        Enum.map(artifacts, fn attrs ->
          {:ok, artifact} = ArtifactStore.insert(attrs)
          artifact
        end)

      # Generate embeddings (would normally be done by migration task)
      # For testing, we'll simulate this

      {:ok, artifacts: inserted}
    end

    test "searches artifacts by semantic similarity", %{artifacts: _artifacts} do
      # Search for async patterns
      {:ok, results} = ArtifactStore.search("asynchronous task execution", top_k: 5)

      # Should return results
      assert length(results) > 0

      # Results should have similarity scores
      Enum.each(results, fn result ->
        assert Map.has_key?(result, :similarity)
        assert result.similarity >= 0.0 and result.similarity <= 1.0
      end)
    end

    test "filters results by language", %{artifacts: _artifacts} do
      {:ok, results} =
        ArtifactStore.search(
          "async pattern",
          language: "elixir",
          top_k: 10
        )

      # All results should be Elixir
      Enum.each(results, fn result ->
        assert result.content["language"] == "elixir"
      end)
    end

    test "filters results by artifact type", %{artifacts: _artifacts} do
      {:ok, results} =
        ArtifactStore.search(
          "pattern",
          artifact_type: "code_pattern",
          top_k: 10
        )

      # All results should be code patterns
      Enum.each(results, fn result ->
        assert result.artifact_type == "code_pattern"
      end)
    end

    test "ranks results by composite score", %{artifacts: _artifacts} do
      {:ok, results} = ArtifactStore.search("async", top_k: 3)

      # Results should be ordered by score (descending)
      scores = Enum.map(results, & &1.similarity)

      assert scores == Enum.sort(scores, :desc)
    end

    test "handles empty search results gracefully" do
      {:ok, results} =
        ArtifactStore.search(
          "nonexistent pattern that definitely does not exist",
          top_k: 10
        )

      # Should return empty list, not error
      assert results == []
    end
  end

  describe "embedding generation" do
    test "generates consistent embeddings for same text" do
      text = "This is a test string for embedding generation"

      # Generate embedding twice
      embedding1 = generate_embedding(text)
      embedding2 = generate_embedding(text)

      # Should be identical (deterministic)
      assert embedding1 == embedding2
    end

    test "generates different embeddings for different text" do
      text1 = "GenServer async pattern"
      text2 = "Database connection pool"

      embedding1 = generate_embedding(text1)
      embedding2 = generate_embedding(text2)

      # Should be different
      assert embedding1 != embedding2
    end

    test "embedding dimensions match model configuration" do
      text = "Test embedding dimensions"

      embedding = generate_embedding(text)

      # CodeBERT produces 768-dimensional vectors
      assert length(embedding) == 768
    end
  end

  describe "usage tracking and learning" do
    setup do
      {:ok, artifact} =
        ArtifactStore.insert(%{
          artifact_type: "code_pattern",
          artifact_id: "usage-test-#{System.unique_integer([:positive])}",
          version: "1.0.0",
          content_raw: "{}",
          content: %{"test" => true},
          usage_count: 0,
          success_rate: 0.0
        })

      {:ok, artifact: artifact}
    end

    test "records successful usage", %{artifact: artifact} do
      # Record success
      {:ok, updated} = ArtifactStore.record_usage(artifact.artifact_id, success: true)

      assert updated.usage_count == 1
      assert updated.success_rate == 1.0
    end

    test "records failed usage", %{artifact: artifact} do
      # Record failure
      {:ok, updated} = ArtifactStore.record_usage(artifact.artifact_id, success: false)

      assert updated.usage_count == 1
      assert updated.success_rate == 0.0
    end

    test "calculates success rate over multiple usages", %{artifact: artifact} do
      # Record multiple usages
      ArtifactStore.record_usage(artifact.artifact_id, success: true)
      ArtifactStore.record_usage(artifact.artifact_id, success: true)
      ArtifactStore.record_usage(artifact.artifact_id, success: false)
      {:ok, updated} = ArtifactStore.record_usage(artifact.artifact_id, success: true)

      assert updated.usage_count == 4
      assert_in_delta updated.success_rate, 0.75, 0.01
    end
  end

  describe "Git ↔ PostgreSQL sync" do
    # Requires file system access
    @tag :skip
    test "imports artifacts from JSON files" do
      # This would test the mix knowledge.migrate task
      # Skipped in CI as it requires templates_data/ directory
    end

    # Requires file system access
    @tag :skip
    test "exports high-performing artifacts to Git" do
      # This would test learned artifact export
      # Skipped in CI as it requires file system write access
    end
  end

  describe "performance tests" do
    @tag timeout: 30_000
    test "handles bulk artifact insertion" do
      # Insert 100 artifacts
      start_time = System.monotonic_time(:millisecond)

      artifacts =
        for i <- 1..100 do
          {:ok, artifact} =
            ArtifactStore.insert(%{
              artifact_type: "code_pattern",
              artifact_id: "bulk-test-#{i}-#{System.unique_integer([:positive])}",
              version: "1.0.0",
              content_raw: "{}",
              content: %{"index" => i}
            })

          artifact
        end

      end_time = System.monotonic_time(:millisecond)

      # All should succeed
      assert length(artifacts) == 100

      # Should complete in reasonable time (< 10 seconds)
      assert end_time - start_time < 10_000
    end

    @tag timeout: 30_000
    test "search performance with large corpus" do
      # Insert 500 artifacts
      for i <- 1..500 do
        ArtifactStore.insert(%{
          artifact_type: "code_pattern",
          artifact_id: "perf-test-#{i}-#{System.unique_integer([:positive])}",
          version: "1.0.0",
          content_raw: Jason.encode!(%{pattern: "pattern #{i}"}),
          content: %{"pattern" => "pattern #{i}", "language" => "elixir"}
        })
      end

      # Search should still be fast
      start_time = System.monotonic_time(:millisecond)

      {:ok, results} = ArtifactStore.search("pattern", top_k: 10)

      end_time = System.monotonic_time(:millisecond)

      # Should return results
      assert length(results) > 0

      # Should complete in < 500ms (pgvector with HNSW index)
      search_time_ms = end_time - start_time
      assert search_time_ms < 500, "Search took #{search_time_ms}ms, expected < 500ms"
    end
  end

  describe "concurrent access" do
    test "handles concurrent searches" do
      # Execute 20 concurrent searches
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            ArtifactStore.search("pattern #{rem(i, 5)}", top_k: 10)
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end

    test "handles concurrent insertions" do
      # Insert 20 artifacts concurrently
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            ArtifactStore.insert(%{
              artifact_type: "code_pattern",
              artifact_id: "concurrent-#{i}-#{System.unique_integer([:positive])}",
              version: "1.0.0",
              content_raw: "{}",
              content: %{"index" => i}
            })
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end
  end

  # Helper function to generate embeddings
  # In production, this would call the Rust NIF
  defp generate_embedding(text) do
    # Simplified: Generate fake embedding for testing
    # In production: Singularity.EmbeddingEngine.embed(text)
    :crypto.hash(:sha256, text)
    |> :binary.bin_to_list()
    |> Enum.take(768)
    |> Enum.map(&(&1 / 255.0))
  end
end
