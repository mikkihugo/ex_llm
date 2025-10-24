defmodule Mix.Tasks.Analyze.Cache do
  @shortdoc "Manage the CodeAnalysis.Analyzer cache"

  @moduledoc """
  Manage the CodeAnalysis.Analyzer cache for analysis results.

  ## Usage

      # Show cache statistics
      mix analyze.cache stats

      # Clear the cache
      mix analyze.cache clear

      # Show cache help
      mix analyze.cache

  ## Commands

    * `stats` - Display cache statistics (hits, misses, size, memory)
    * `clear` - Clear all cached entries

  ## Examples

      # Check performance
      mix analyze.cache stats
      # => Hits: 150, Misses: 50, Hit Rate: 75.0%, Size: 200/1000

      # Clear cache after major codebase changes
      mix analyze.cache clear
  """

  use Mix.Task
  alias Singularity.CodeAnalysis.Analyzer.Cache

  @requirements ["app.start"]

  @impl Mix.Task
  def run([]) do
    print_help()
  end

  def run(["stats"]) do
    case Process.whereis(Cache) do
      nil ->
        Mix.shell().error("Cache is not running. Start the application first.")
        System.halt(1)

      _pid ->
        stats = Cache.stats()
        print_stats(stats)
    end
  end

  def run(["clear"]) do
    case Process.whereis(Cache) do
      nil ->
        Mix.shell().error("Cache is not running. Start the application first.")
        System.halt(1)

      _pid ->
        Mix.shell().info("Clearing CodeAnalysis.Analyzer cache...")
        :ok = Cache.clear()
        Mix.shell().info("✓ Cache cleared successfully")
    end
  end

  def run([command | _]) do
    Mix.shell().error("Unknown command: #{command}")
    Mix.shell().info("")
    print_help()
    System.halt(1)
  end

  defp print_help do
    Mix.shell().info("")
    Mix.shell().info("CodeAnalysis.Analyzer Cache Management")
    Mix.shell().info("")
    Mix.shell().info("Usage:")
    Mix.shell().info("  mix analyze.cache stats   # Show cache statistics")
    Mix.shell().info("  mix analyze.cache clear   # Clear all cached entries")
    Mix.shell().info("")
  end

  defp print_stats(stats) do
    Mix.shell().info("")
    Mix.shell().info("=" <> String.duplicate("=", 60))
    Mix.shell().info("CODE ANALYZER CACHE STATISTICS")
    Mix.shell().info("=" <> String.duplicate("=", 60))
    Mix.shell().info("")

    Mix.shell().info("Performance:")
    Mix.shell().info("  Hits:      #{stats.hits}")
    Mix.shell().info("  Misses:    #{stats.misses}")
    Mix.shell().info("  Hit Rate:  #{Float.round(stats.hit_rate * 100, 1)}%")
    Mix.shell().info("")

    Mix.shell().info("Storage:")
    Mix.shell().info("  Size:      #{stats.size}/#{stats.max_size} entries")
    Mix.shell().info("  Memory:    #{format_bytes(stats.memory_bytes)}")
    Mix.shell().info("")

    # Recommendations
    if stats.hit_rate < 0.5 and stats.hits + stats.misses > 20 do
      Mix.shell().info("⚠️  Low hit rate detected. Consider:")
      Mix.shell().info("   - Increasing cache size")
      Mix.shell().info("   - Increasing TTL")
      Mix.shell().info("   - Analyzing code change patterns")
      Mix.shell().info("")
    end

    if stats.size >= stats.max_size * 0.9 do
      Mix.shell().info("⚠️  Cache nearly full. Consider:")
      Mix.shell().info("   - Increasing max_size in application.ex")
      Mix.shell().info("   - Clearing old entries")
      Mix.shell().info("")
    end

    Mix.shell().info("=" <> String.duplicate("=", 60))
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"
end
