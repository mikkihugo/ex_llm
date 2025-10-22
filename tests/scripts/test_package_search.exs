#!/usr/bin/env elixir

# Test script for package search tool
# Run with: elixir test_package_search.exs

# Add the lib directory to the path
Code.prepend_path("singularity/lib")

# Test the package search tool
IO.puts("🧪 Testing Package Search Tool")
IO.puts("=" |> String.duplicate(50))

# Test 1: Search for async packages
IO.puts("\n1. Testing async package search...")
case Singularity.Tools.PackageSearch.search_packages("async", :all, 5) do
  {:ok, results} ->
    IO.puts("✅ Found #{results.total_packages} packages")
    IO.puts("Packages:")
    Enum.each(results.packages, fn pkg ->
      IO.puts("  - #{pkg.name} v#{pkg.version} (#{pkg.ecosystem}) - #{pkg.description}")
    end)
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
end

# Test 2: Search for Rust packages specifically
IO.puts("\n2. Testing Rust package search...")
case Singularity.Tools.PackageSearch.search_ecosystem_packages("web framework", :cargo, 3) do
  {:ok, packages} ->
    IO.puts("✅ Found #{length(packages)} Rust packages")
    Enum.each(packages, fn pkg ->
      IO.puts("  - #{pkg.name} v#{pkg.version} - #{pkg.description}")
    end)
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
end

# Test 3: Test service connectivity
IO.puts("\n3. Testing service connectivity...")
case Singularity.Tools.PackageSearch.test_service_connectivity do
  {:ok, message} ->
    IO.puts("✅ #{message}")
  {:error, reason} ->
    IO.puts("❌ Error: #{inspect(reason)}")
end

IO.puts("\n🏁 Test completed!")