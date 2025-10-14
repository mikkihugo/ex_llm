#!/usr/bin/env elixir

# Test script for PostgreSQL migration functionality
# Run with: elixir test_postgres_migration.exs

# Set up the environment
System.put_env("MIX_ENV", "dev")

# Add the project to the code path
Code.prepend_path("_build/dev/lib/singularity/ebin")

# Test PostgreSQL vector search functions
defmodule TestPostgresMigration do
  alias Singularity.Repo

  def test_vector_functions do
    IO.puts("🧪 Testing PostgreSQL Vector Functions...")
    
    # Test if the function exists
    case Repo.query("SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_name = 'find_similar_code_vectors'") do
      {:ok, result} ->
        if length(result.rows) > 0 do
          IO.puts("✅ find_similar_code_vectors function exists")
        else
          IO.puts("❌ find_similar_code_vectors function not found")
        end
      
      {:error, reason} ->
        IO.puts("❌ Error checking functions: #{inspect(reason)}")
    end
  end

  def test_timescaledb do
    IO.puts("🧪 Testing TimescaleDB...")
    
    # Check if TimescaleDB is available
    case Repo.query("SELECT extname FROM pg_extension WHERE extname = 'timescaledb'") do
      {:ok, result} ->
        if length(result.rows) > 0 do
          IO.puts("✅ TimescaleDB extension is installed")
          
          # Check for hypertables
          case Repo.query("SELECT hypertable_name FROM timescaledb_information.hypertables WHERE hypertable_schema = 'public'") do
            {:ok, hypertables} ->
              IO.puts("📊 Hypertables: #{inspect(Enum.map(hypertables.rows, &List.first/1))}")
            {:error, reason} ->
              IO.puts("⚠️  Could not check hypertables: #{inspect(reason)}")
          end
        else
          IO.puts("❌ TimescaleDB extension not found")
        end
      
      {:error, reason} ->
        IO.puts("❌ Error checking TimescaleDB: #{inspect(reason)}")
    end
  end

  def test_apache_age do
    IO.puts("🧪 Testing Apache AGE...")
    
    # Check if Apache AGE is available
    case Repo.query("SELECT extname FROM pg_extension WHERE extname = 'age'") do
      {:ok, result} ->
        if length(result.rows) > 0 do
          IO.puts("✅ Apache AGE extension is installed")
          
          # Test creating a simple graph
          case Repo.query("SELECT * FROM ag_catalog.create_graph('test_graph')") do
            {:ok, _} ->
              IO.puts("✅ Successfully created test graph")
              
              # Clean up
              Repo.query("SELECT * FROM ag_catalog.drop_graph('test_graph', true)")
              IO.puts("✅ Successfully cleaned up test graph")
            {:error, reason} ->
              IO.puts("⚠️  Could not create test graph: #{inspect(reason)}")
          end
        else
          IO.puts("❌ Apache AGE extension not found")
        end
      
      {:error, reason} ->
        IO.puts("❌ Error checking Apache AGE: #{inspect(reason)}")
    end
  end

  def test_pg_cron do
    IO.puts("🧪 Testing pg_cron...")
    
    # Check if pg_cron is available
    case Repo.query("SELECT extname FROM pg_extension WHERE extname = 'pg_cron'") do
      {:ok, result} ->
        if length(result.rows) > 0 do
          IO.puts("✅ pg_cron extension is installed")
          
          # Check for existing jobs
          case Repo.query("SELECT jobname FROM cron.job WHERE jobname LIKE 'singularity-%'") do
            {:ok, jobs} ->
              IO.puts("📅 Scheduled jobs: #{inspect(Enum.map(jobs.rows, &List.first/1))}")
            {:error, reason} ->
              IO.puts("⚠️  Could not check jobs: #{inspect(reason)}")
          end
        else
          IO.puts("❌ pg_cron extension not found")
        end
      
      {:error, reason} ->
        IO.puts("❌ Error checking pg_cron: #{inspect(reason)}")
    end
  end

  def test_all_extensions do
    IO.puts("🧪 Testing All Extensions...")
    
    case Repo.query("SELECT extname, extversion FROM pg_extension ORDER BY extname") do
      {:ok, result} ->
        IO.puts("📦 Installed extensions:")
        Enum.each(result.rows, fn [name, version] ->
          IO.puts("   #{name}: #{version}")
        end)
      
      {:error, reason} ->
        IO.puts("❌ Error checking extensions: #{inspect(reason)}")
    end
  end

  def run_all_tests do
    IO.puts("🚀 Starting PostgreSQL Migration Tests...")
    IO.puts("=" <> String.duplicate("=", 50))
    
    test_all_extensions()
    IO.puts("")
    
    test_vector_functions()
    IO.puts("")
    
    test_timescaledb()
    IO.puts("")
    
    test_apache_age()
    IO.puts("")
    
    test_pg_cron()
    IO.puts("")
    
    IO.puts("=" <> String.duplicate("=", 50))
    IO.puts("✅ All tests completed!")
  end
end

# Run the tests
TestPostgresMigration.run_all_tests()