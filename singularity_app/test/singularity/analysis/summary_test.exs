defmodule Singularity.Analysis.SummaryTest do
  use Singularity.DataCase, async: true

  alias Singularity.Analysis.{Summary, FileReport, Metadata}

  describe "new/1" do
    test "builds summary from map with files" do
      attrs = %{
        "total_files" => 10,
        "total_lines" => 1000,
        "files" => %{
          "lib/test.ex" => %{
            "path" => "lib/test.ex",
            "metadata" => %{
              "cyclomatic_complexity" => 5.0,
              "quality_score" => 85.0
            }
          }
        },
        "languages" => %{"elixir" => 10}
      }

      summary = Summary.new(attrs)

      assert summary.total_files == 10
      assert summary.total_lines == 1000
      assert Map.has_key?(summary.files, "lib/test.ex")
      assert summary.files["lib/test.ex"].metadata.cyclomatic_complexity == 5.0
    end

    test "handles empty attributes" do
      summary = Summary.new()

      assert summary.total_files == 0
      assert summary.files == %{}
    end
  end

  describe "store/2" do
    test "stores summary with codebase_id" do
      summary_data = build_test_summary()

      assert {:ok, stored} = Summary.store(summary_data, codebase_id: "test-project")
      assert stored.codebase_id == "test-project"
      assert stored.total_files == 2
      assert stored.quality_score > 0
    end

    test "calculates aggregate metrics from files" do
      summary_data = build_test_summary()

      assert {:ok, stored} = Summary.store(summary_data, codebase_id: "metrics-test")

      # Should calculate averages from file metadata
      assert stored.quality_score > 0
      assert stored.technical_debt_ratio >= 0
      assert stored.average_complexity > 0
      assert stored.average_maintainability > 0
    end

    test "validates required fields" do
      invalid_data = %{total_files: 10}

      # Should fail validation - needs codebase_id and analyzed_at
      assert {:error, changeset} = Summary.store(invalid_data, [])
      assert changeset.errors[:codebase_id] || changeset.errors[:analyzed_at]
    end
  end

  describe "fetch_latest/1" do
    test "returns most recent analysis for codebase" do
      # Store two analyses
      {:ok, _first} =
        Summary.store(
          build_test_summary(),
          codebase_id: "fetch-test",
          analyzed_at: ~U[2024-10-01 10:00:00Z]
        )

      {:ok, second} =
        Summary.store(
          build_test_summary(),
          codebase_id: "fetch-test",
          analyzed_at: ~U[2024-10-05 15:00:00Z]
        )

      # Fetch latest
      latest = Summary.fetch_latest(codebase_id: "fetch-test")

      assert latest.id == second.id
      assert latest.analyzed_at == ~U[2024-10-05 15:00:00Z]
    end

    test "returns nil when no analysis exists" do
      assert nil == Summary.fetch_latest(codebase_id: "nonexistent")
    end

    test "hydrates files from analysis_data" do
      {:ok, stored} =
        Summary.store(
          build_test_summary(),
          codebase_id: "hydrate-test"
        )

      fetched = Summary.fetch_latest(codebase_id: "hydrate-test")

      # Files should be hydrated from JSONB
      assert map_size(fetched.files) == 2
      assert fetched.files["lib/module_a.ex"]
      assert fetched.files["lib/module_a.ex"].metadata.cyclomatic_complexity == 8.5
    end
  end

  describe "fetch_history/1" do
    test "returns paginated history ordered by analyzed_at desc" do
      codebase_id = "history-test"

      # Store 5 analyses
      for i <- 1..5 do
        Summary.store(
          build_test_summary(),
          codebase_id: codebase_id,
          analyzed_at: DateTime.add(~U[2024-10-01 10:00:00Z], i * 3600, :second)
        )
      end

      # Fetch with limit
      history = Summary.fetch_history(codebase_id: codebase_id, limit: 3)

      assert length(history) == 3
      # Should be newest first
      assert Enum.at(history, 0).analyzed_at > Enum.at(history, 1).analyzed_at
    end

    test "supports offset for pagination" do
      codebase_id = "pagination-test"

      for i <- 1..10 do
        Summary.store(
          build_test_summary(),
          codebase_id: codebase_id,
          analyzed_at: DateTime.add(~U[2024-10-01 10:00:00Z], i * 3600, :second)
        )
      end

      first_page = Summary.fetch_history(codebase_id: codebase_id, limit: 3, offset: 0)
      second_page = Summary.fetch_history(codebase_id: codebase_id, limit: 3, offset: 3)

      assert length(first_page) == 3
      assert length(second_page) == 3
      # Pages should not overlap
      refute Enum.at(first_page, 0).id == Enum.at(second_page, 0).id
    end
  end

  describe "cleanup_old/1" do
    test "deletes analyses older than retention period" do
      codebase_id = "cleanup-test"

      # Store old analysis (40 days ago)
      old_date = DateTime.add(DateTime.utc_now(), -40, :day)

      {:ok, _old} =
        Summary.store(
          build_test_summary(),
          codebase_id: codebase_id,
          analyzed_at: old_date
        )

      # Store recent analysis (10 days ago)
      recent_date = DateTime.add(DateTime.utc_now(), -10, :day)

      {:ok, recent} =
        Summary.store(
          build_test_summary(),
          codebase_id: codebase_id,
          analyzed_at: recent_date
        )

      # Cleanup with 30 day retention
      {deleted_count, _} = Summary.cleanup_old(days_to_keep: 30, codebase_id: codebase_id)

      assert deleted_count == 1

      # Recent should still exist
      latest = Summary.fetch_latest(codebase_id: codebase_id)
      assert latest.id == recent.id
    end

    test "supports cleanup across all codebases" do
      # Store old analyses for multiple codebases
      old_date = DateTime.add(DateTime.utc_now(), -40, :day)

      Summary.store(build_test_summary(), codebase_id: "project-a", analyzed_at: old_date)
      Summary.store(build_test_summary(), codebase_id: "project-b", analyzed_at: old_date)

      {deleted_count, _} = Summary.cleanup_old(days_to_keep: 30)

      assert deleted_count == 2
    end
  end

  describe "get_stats/1" do
    test "returns aggregate statistics for codebase" do
      codebase_id = "stats-test"

      # Store 3 analyses with varying quality
      for quality <- [70.0, 80.0, 90.0] do
        summary = build_test_summary_with_quality(quality)

        Summary.store(
          summary,
          codebase_id: codebase_id,
          analyzed_at: DateTime.add(DateTime.utc_now(), :rand.uniform(100), :second)
        )
      end

      stats = Summary.get_stats(codebase_id: codebase_id)

      assert stats.total_analyses == 3
      assert stats.avg_quality_score != nil
      assert stats.first_analysis != nil
      assert stats.last_analysis != nil
    end

    test "returns empty stats when no analyses exist" do
      stats = Summary.get_stats(codebase_id: "no-analyses")

      assert stats.total_analyses == 0
      assert stats.avg_quality_score == nil
    end
  end

  # Test Helpers

  defp build_test_summary do
    %{
      total_files: 2,
      total_lines: 500,
      total_functions: 20,
      total_classes: 3,
      files: %{
        "lib/module_a.ex" => build_file_report("lib/module_a.ex", 8.5, 75.0),
        "lib/module_b.ex" => build_file_report("lib/module_b.ex", 12.0, 65.0)
      },
      languages: %{"elixir" => 2},
      analyzed_at: DateTime.to_unix(DateTime.utc_now())
    }
  end

  defp build_test_summary_with_quality(quality_score) do
    %{
      total_files: 1,
      total_lines: 100,
      files: %{
        "lib/test.ex" => build_file_report("lib/test.ex", 5.0, quality_score)
      },
      languages: %{"elixir" => 1},
      analyzed_at: DateTime.to_unix(DateTime.utc_now())
    }
  end

  defp build_file_report(path, complexity, quality_score) do
    %FileReport{
      path: path,
      metadata: %Metadata{
        path: path,
        cyclomatic_complexity: complexity,
        quality_score: quality_score,
        technical_debt_ratio: 0.15,
        maintainability_index: quality_score,
        duplication_percentage: 5.0
      },
      analyzed_at: DateTime.to_unix(DateTime.utc_now()),
      content_hash: "test_hash_#{path}"
    }
  end
end
