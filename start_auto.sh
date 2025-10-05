#!/bin/bash
# Auto-start script for Singularity with all optimizations

echo "🚀 Starting Singularity with AUTO mode..."

# Navigate to app directory
cd singularity_app

# 1. Run database migrations (includes PG cache setup)
echo "📦 Running database migrations..."
mix ecto.migrate

# 2. Start the application with auto-warmup
echo "🔥 Starting application with auto-warmup..."
iex -S mix --eval "
  # Wait for startup
  Process.sleep(3000)

  # Show cache stats
  IO.puts('\\n📊 Cache Statistics:')
  Singularity.MemoryCache.stats() |> IO.inspect()

  # Show template optimizer status
  IO.puts('\\n🎯 Template Optimizer:')
  case Singularity.TemplateOptimizer.analyze_performance() do
    {:ok, analysis} ->
      IO.puts('Top performers loaded: #{length(analysis.top_performers)}')
    _ ->
      IO.puts('No performance history yet')
  end

  # Test the system
  IO.puts('\\n✅ System Ready!')
  IO.puts('Try: Singularity.ExecutionCoordinator.execute(%{description: \\\"Create a GenServer\\\"}, language: \\\"elixir\\\")')
"