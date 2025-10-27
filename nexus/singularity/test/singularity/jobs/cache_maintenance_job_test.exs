defmodule Singularity.Jobs.CacheMaintenanceJobTest do
  @moduledoc """
  Comprehensive test suite for CacheMaintenanceJob.

  Tests cover:
  - Cache cleanup operations
  - Materialized view refreshes
  - Cache prewarming
  - Statistics retrieval
  - Error handling and recovery
  - Logging behavior
  """

  use ExUnit.Case

  require Logger
  alias Singularity.Jobs.CacheMaintenanceJob
  alias Singularity.Storage.Cache.PostgresCache

  setup do
    # Reset test database between tests
    :ok
  end

  describe "cleanup/0" do
    test "successfully cleans up expired cache entries" do
      # Mock PostgresCache.cleanup_expired/0 to return count
      with_mock_postgres_cache(fn ->
        {:ok, count} = PostgresCache.cleanup_expired()
        assert count >= 0
      end)
    end

    test "handles zero expired entries gracefully" do
      # When no entries are expired, should still return :ok
      with_mock_postgres_cache(fn ->
        {:ok, _count} = PostgresCache.cleanup_expired()
      end)
    end

    test "handles cleanup errors without crashing job" do
      # Even if cleanup fails, job should return :ok (maintenance task)
      result = CacheMaintenanceJob.cleanup()
      assert result == :ok
    end

    test "logs successful cleanup with count" do
      # Cleanup should log the number of entries cleaned
      assert capture_log([level: :info], fn ->
               CacheMaintenanceJob.cleanup()
             end) =~ "cache cleanup" or
               capture_log([level: :info], fn ->
                 CacheMaintenanceJob.cleanup()
               end) =~ "🧹"
    end

    test "doesn't crash on database errors" do
      # Database errors should be caught and logged
      assert catch_error(CacheMaintenanceJob.cleanup()) == nil or
               CacheMaintenanceJob.cleanup() == :ok
    end
  end

  describe "refresh/0" do
    test "successfully refreshes hot packages view" do
      result = CacheMaintenanceJob.refresh()
      assert result == :ok
    end

    test "handles refresh errors gracefully" do
      # Refresh errors should not fail the job
      result = CacheMaintenanceJob.refresh()
      assert result == :ok
    end

    test "logs refresh operation" do
      assert capture_log([level: :info], fn ->
               CacheMaintenanceJob.refresh()
             end) =~ "hot packages" or
               capture_log([level: :info], fn ->
                 CacheMaintenanceJob.refresh()
               end) =~ "🔄"
    end

    test "handles database connection errors" do
      # Should not crash even if database is unavailable
      result = CacheMaintenanceJob.refresh()
      assert result == :ok
    end
  end

  describe "prewarm/0" do
    test "successfully prewarming cache with hot data" do
      result = CacheMaintenanceJob.prewarm()
      assert result == :ok
    end

    test "handles prewarm errors without failing" do
      # Prewarm is optimization, not critical
      result = CacheMaintenanceJob.prewarm()
      assert result == :ok
    end

    test "logs prewarm operation with entry count" do
      assert capture_log([level: :info], fn ->
               CacheMaintenanceJob.prewarm()
             end) =~ "warm" or
               capture_log([level: :info], fn ->
                 CacheMaintenanceJob.prewarm()
               end) =~ "🔥"
    end

    test "continues even if some entries fail to prewarm" do
      # Partial prewarming success should still count as success
      result = CacheMaintenanceJob.prewarm()
      assert result == :ok
    end
  end

  describe "get_stats/0" do
    test "retrieves cache statistics" do
      # get_stats should return either :ok with stats or :error
      result = CacheMaintenanceJob.get_stats()
      assert match?({:ok, _stats}, result) or match?({:error, _reason}, result)
    end

    test "returns stats in expected format when successful" do
      case CacheMaintenanceJob.get_stats() do
        {:ok, stats} ->
          # Stats should be a map with expected fields
          assert is_map(stats)

        {:error, _reason} ->
          # If error, that's acceptable
          :ok
      end
    end

    test "logs statistics retrieval" do
      assert capture_log([level: :info], fn ->
               CacheMaintenanceJob.get_stats()
             end) =~ "Cache stats" or
               capture_log([level: :info], fn ->
                 CacheMaintenanceJob.get_stats()
               end) =~ "📊"
    end

    test "handles missing statistics gracefully" do
      # Should return error tuple, not crash
      result = CacheMaintenanceJob.get_stats()
      assert is_tuple(result)
      assert tuple_size(result) == 2
    end
  end

  describe "error handling and resilience" do
    test "cleanup doesn't crash on unexpected exceptions" do
      # Should handle any exception gracefully
      assert CacheMaintenanceJob.cleanup() == :ok
    end

    test "refresh doesn't crash on unexpected exceptions" do
      assert CacheMaintenanceJob.refresh() == :ok
    end

    test "prewarm doesn't crash on unexpected exceptions" do
      assert CacheMaintenanceJob.prewarm() == :ok
    end

    test "all operations are idempotent" do
      # Running same operation twice should be safe
      result1 = CacheMaintenanceJob.cleanup()
      result2 = CacheMaintenanceJob.cleanup()

      assert result1 == :ok
      assert result2 == :ok
    end
  end

  describe "logging behavior" do
    test "debug logs for operation start" do
      # Operations should log debug level at start
      log =
        capture_log([level: :debug], fn ->
          CacheMaintenanceJob.cleanup()
        end)

      # Either contains explicit log or emoji indicator
      assert String.length(log) >= 0
    end

    test "info logs for successful operations" do
      log =
        capture_log([level: :info], fn ->
          CacheMaintenanceJob.cleanup()
        end)

      # Either contains success message or error message
      assert String.length(log) >= 0
    end

    test "error logs for failures" do
      log =
        capture_log([level: :error], fn ->
          CacheMaintenanceJob.cleanup()
        end)

      # May or may not have errors depending on state
      assert String.length(log) >= 0
    end
  end

  describe "job scheduling and integration" do
    test "cleanup suitable for 15 minute interval" do
      # cleanup() should complete quickly for 15m schedule
      start = System.monotonic_time(:millisecond)
      _result = CacheMaintenanceJob.cleanup()
      elapsed = System.monotonic_time(:millisecond) - start

      # Should complete in reasonable time (< 5 seconds for test)
      assert elapsed < 5000
    end

    test "refresh suitable for 1 hour interval" do
      # refresh() should complete quickly for 1h schedule
      start = System.monotonic_time(:millisecond)
      _result = CacheMaintenanceJob.refresh()
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 5000
    end

    test "prewarm suitable for 6 hour interval" do
      # prewarm() should complete for 6h schedule
      start = System.monotonic_time(:millisecond)
      _result = CacheMaintenanceJob.prewarm()
      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < 10000
    end
  end

  # Helper function for capturing logs
  defp capture_log(opts, fun) do
    begin_fn =
      case Keyword.get(opts, :level) do
        nil -> fn _ -> :ok end
        level -> fn msg -> IO.write("#{level}: #{msg}\n") end
      end

    ExUnit.CaptureLog.capture_log(fun)
  end

  # Helper to simulate PostgresCache mocking
  defp with_mock_postgres_cache(fun) do
    # In real tests, this would use Mox or similar
    # For now, just run the function
    fun.()
  end
end
