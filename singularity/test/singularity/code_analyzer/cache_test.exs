defmodule Singularity.CodeAnalyzer.CacheTest do
  use ExUnit.Case, async: false
  alias Singularity.CodeAnalyzer.Cache

  setup do
    # Start a test cache instance
    {:ok, pid} = start_supervised({Cache, [max_size: 10, ttl: 1]})

    on_exit(fn ->
      if Process.alive?(pid) do
        Cache.clear()
      end
    end)

    %{cache_pid: pid}
  end

  describe "start_link/1" do
    test "starts cache with default options" do
      {:ok, pid} = start_supervised({Cache, []}, id: :cache_test_1)
      assert Process.alive?(pid)
    end

    test "starts cache with custom options" do
      {:ok, pid} = start_supervised({Cache, [max_size: 100, ttl: 60]}, id: :cache_test_2)
      assert Process.alive?(pid)
    end
  end

  describe "get_or_analyze/3" do
    test "returns cached result on subsequent calls" do
      code = "def hello, do: :world"
      call_count = :counters.new(1, [])

      analyzer_fun = fn ->
        :counters.add(call_count, 1, 1)
        {:ok, %{result: "analysis"}}
      end

      # First call - should execute analyzer
      {:ok, result1} = Cache.get_or_analyze(code, "elixir", analyzer_fun)
      assert result1 == %{result: "analysis"}
      assert :counters.get(call_count, 1) == 1

      # Second call - should use cache
      {:ok, result2} = Cache.get_or_analyze(code, "elixir", analyzer_fun)
      assert result2 == %{result: "analysis"}
      assert :counters.get(call_count, 1) == 1  # Analyzer not called again
    end

    test "caches different results for different languages" do
      code = "def test: pass"

      {:ok, result_python} = Cache.get_or_analyze(code, "python", fn ->
        {:ok, %{language: "python"}}
      end)

      {:ok, result_elixir} = Cache.get_or_analyze(code, "elixir", fn ->
        {:ok, %{language: "elixir"}}
      end)

      assert result_python.language == "python"
      assert result_elixir.language == "elixir"
    end

    test "caches different results for different code" do
      code1 = "def hello, do: :world"
      code2 = "def goodbye, do: :world"

      {:ok, result1} = Cache.get_or_analyze(code1, "elixir", fn ->
        {:ok, %{code: "code1"}}
      end)

      {:ok, result2} = Cache.get_or_analyze(code2, "elixir", fn ->
        {:ok, %{code: "code2"}}
      end)

      assert result1.code == "code1"
      assert result2.code == "code2"
    end

    test "does not cache errors" do
      code = "invalid code"
      call_count = :counters.new(1, [])

      analyzer_fun = fn ->
        :counters.add(call_count, 1, 1)
        {:error, "analysis failed"}
      end

      # First call - should fail
      {:error, _} = Cache.get_or_analyze(code, "elixir", analyzer_fun)
      assert :counters.get(call_count, 1) == 1

      # Second call - should try again (errors not cached)
      {:error, _} = Cache.get_or_analyze(code, "elixir", analyzer_fun)
      assert :counters.get(call_count, 1) == 2  # Called again
    end
  end

  describe "stats/0" do
    test "tracks hits and misses" do
      code = "def test, do: :ok"

      # First call - miss
      Cache.get_or_analyze(code, "elixir", fn -> {:ok, %{}} end)
      stats = Cache.stats()
      assert stats.misses == 1
      assert stats.hits == 0

      # Second call - hit
      Cache.get_or_analyze(code, "elixir", fn -> {:ok, %{}} end)
      stats = Cache.stats()
      assert stats.misses == 1
      assert stats.hits == 1
    end

    test "calculates hit rate correctly" do
      code = "def test, do: :ok"

      # 1 miss, 3 hits = 75% hit rate
      Cache.get_or_analyze(code, "elixir", fn -> {:ok, %{}} end)
      Cache.get_or_analyze(code, "elixir", fn -> {:ok, %{}} end)
      Cache.get_or_analyze(code, "elixir", fn -> {:ok, %{}} end)
      Cache.get_or_analyze(code, "elixir", fn -> {:ok, %{}} end)

      stats = Cache.stats()
      assert stats.hit_rate == 0.75
    end

    test "returns cache size" do
      # Add 3 entries
      Enum.each(1..3, fn i ->
        code = "def test#{i}, do: :ok"
        Cache.get_or_analyze(code, "elixir", fn -> {:ok, %{}} end)
      end)

      stats = Cache.stats()
      assert stats.size == 3
      assert stats.max_size == 10  # From setup
    end

    test "returns memory usage" do
      Cache.get_or_analyze("code", "elixir", fn -> {:ok, %{}} end)

      stats = Cache.stats()
      assert stats.memory_bytes > 0
    end
  end

  describe "clear/0" do
    test "removes all cached entries" do
      # Add entries
      Enum.each(1..5, fn i ->
        Cache.get_or_analyze("code#{i}", "elixir", fn -> {:ok, %{}} end)
      end)

      stats_before = Cache.stats()
      assert stats_before.size == 5

      # Clear
      :ok = Cache.clear()

      stats_after = Cache.stats()
      assert stats_after.size == 0
      assert stats_after.hits == 0
      assert stats_after.misses == 0
    end
  end

  describe "LRU eviction" do
    test "evicts least recently used entry when full", %{cache_pid: _pid} do
      # Cache has max_size: 10 from setup

      # Fill cache to capacity
      Enum.each(1..10, fn i ->
        Cache.get_or_analyze("code#{i}", "elixir", fn -> {:ok, %{index: i}} end)
      end)

      stats = Cache.stats()
      assert stats.size == 10

      # Add one more - should evict first entry
      Cache.get_or_analyze("code11", "elixir", fn -> {:ok, %{index: 11}} end)

      stats = Cache.stats()
      # Size should still be at max (one evicted, one added)
      assert stats.size <= 10
    end
  end

  describe "TTL expiration" do
    test "expires entries after TTL" do
      # Cache has ttl: 1 second from setup
      code = "def test, do: :ok"

      # Add entry
      {:ok, result1} = Cache.get_or_analyze(code, "elixir", fn ->
        {:ok, %{timestamp: DateTime.utc_now()}}
      end)

      # Wait for TTL to expire
      Process.sleep(1100)

      # Should miss cache and re-analyze
      call_count = :counters.new(1, [])
      {:ok, result2} = Cache.get_or_analyze(code, "elixir", fn ->
        :counters.add(call_count, 1, 1)
        {:ok, %{timestamp: DateTime.utc_now()}}
      end)

      # Analyzer should have been called (cache expired)
      assert :counters.get(call_count, 1) == 1

      # Results should be different (different timestamps)
      assert result1.timestamp != result2.timestamp
    end
  end

  describe "concurrent access" do
    test "handles concurrent reads and writes" do
      code = "def test, do: :ok"

      # Spawn multiple processes doing cache operations
      tasks =
        Enum.map(1..50, fn i ->
          Task.async(fn ->
            Cache.get_or_analyze("code#{rem(i, 10)}", "elixir", fn ->
              {:ok, %{index: i}}
            end)
          end)
        end)

      # Wait for all tasks
      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      # Cache should have entries
      stats = Cache.stats()
      assert stats.size > 0
    end
  end

  describe "memory pressure" do
    test "handles large analysis results" do
      code = "def test, do: :ok"

      # Create a large result (1MB of data)
      large_data = :crypto.strong_rand_bytes(1024 * 1024) |> Base.encode64()

      {:ok, result} = Cache.get_or_analyze(code, "elixir", fn ->
        {:ok, %{large_field: large_data}}
      end)

      assert byte_size(result.large_field) > 1_000_000

      # Check memory usage increased
      stats = Cache.stats()
      assert stats.memory_bytes > 1_000_000
    end

    test "limits total cache size via max_size" do
      # Try to add more than max_size entries
      Enum.each(1..20, fn i ->
        Cache.get_or_analyze("code#{i}", "elixir", fn -> {:ok, %{index: i}} end)
      end)

      stats = Cache.stats()
      # Size should not exceed max_size (10 from setup)
      assert stats.size <= 10
    end
  end
end
