defmodule Singularity.Tools.PackageSearch do
  @moduledoc """
  Package Search Tool - Search for packages across ecosystems via NATS
  
  This tool provides package search functionality that communicates with the
  Rust package registry service via NATS to get real package data from the
  dependency_catalog database.
  """

  require Logger
  alias Singularity.Search.PackageAndCodebaseSearch

  @doc """
  Search for packages across different ecosystems
  
  ## Parameters
  - query: Search query string
  - ecosystem: Package ecosystem (:npm, :cargo, :hex, :pypi, or :all)
  - limit: Maximum number of results (default: 10)
  
  ## Returns
  List of package search results with metadata
  """
  def search_packages(query, ecosystem \\ :all, limit \\ 10) do
    Logger.info("🔍 Searching packages: '#{query}' in #{ecosystem} ecosystem")
    
    try do
      case PackageAndCodebaseSearch.hybrid_search(query, %{
        ecosystem: ecosystem,
        limit: limit
      }) do
        {:ok, results} ->
          Logger.info("✅ Found #{length(results.packages)} packages")
          format_results(results)
        
        {:error, reason} ->
          Logger.error("❌ Package search failed: #{inspect(reason)}")
          {:error, "Package search failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        Logger.error("❌ Package search error: #{inspect(error)}")
        {:error, "Package search error: #{inspect(error)}"}
    end
  end

  @doc """
  Search for packages in a specific ecosystem
  
  ## Parameters
  - query: Search query string
  - ecosystem: Specific ecosystem (:npm, :cargo, :hex, :pypi)
  - limit: Maximum number of results (default: 10)
  """
  def search_ecosystem_packages(query, ecosystem, limit \\ 10) do
    Logger.info("🔍 Searching #{ecosystem} packages: '#{query}'")
    
    try do
      case PackageAndCodebaseSearch.search_packages(query, ecosystem, limit) do
        {:ok, packages} ->
          Logger.info("✅ Found #{length(packages)} #{ecosystem} packages")
          format_packages(packages, ecosystem)
        
        {:error, reason} ->
          Logger.error("❌ #{ecosystem} package search failed: #{inspect(reason)}")
          {:error, "#{ecosystem} package search failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        Logger.error("❌ #{ecosystem} package search error: #{inspect(error)}")
        {:error, "#{ecosystem} package search error: #{inspect(error)}"}
    end
  end

  @doc """
  Get package recommendations based on a codebase context
  
  ## Parameters
  - context: Codebase context or description
  - language: Programming language
  - limit: Maximum number of recommendations (default: 5)
  """
  def get_package_recommendations(context, language, limit \\ 5) do
    Logger.info("💡 Getting package recommendations for #{language}: '#{context}'")
    
    try do
      case PackageAndCodebaseSearch.get_package_recommendations(context, language, limit) do
        {:ok, recommendations} ->
          Logger.info("✅ Found #{length(recommendations)} recommendations")
          format_recommendations(recommendations, language)
        
        {:error, reason} ->
          Logger.error("❌ Package recommendations failed: #{inspect(reason)}")
          {:error, "Package recommendations failed: #{inspect(reason)}"}
      end
    rescue
      error ->
        Logger.error("❌ Package recommendations error: #{inspect(error)}")
        {:error, "Package recommendations error: #{inspect(error)}"}
    end
  end

  @doc """
  Test the package search service connectivity
  
  ## Returns
  Service status and basic connectivity test
  """
  def test_service_connectivity do
    Logger.info("🔧 Testing package search service connectivity")
    
    try do
      # Test with a simple query
      case search_packages("test", :all, 1) do
        {:ok, _results} ->
          Logger.info("✅ Package search service is working")
          {:ok, "Package search service is operational"}
        
        {:error, reason} ->
          Logger.warning("⚠️ Package search service issue: #{inspect(reason)}")
          {:error, "Package search service issue: #{inspect(reason)}"}
      end
    rescue
      error ->
        Logger.error("❌ Service connectivity test failed: #{inspect(error)}")
        {:error, "Service connectivity test failed: #{inspect(error)}"}
    end
  end

  # Private helper functions

  defp format_results(results) do
    packages = results.packages || []
    your_code = results.your_code || []
    
    formatted_packages = format_packages(packages, "all")
    formatted_code = format_code_results(your_code)
    
    %{
      packages: formatted_packages,
      your_code: formatted_code,
      total_packages: length(packages),
      total_code_results: length(your_code)
    }
  end

  defp format_packages(packages, ecosystem) do
    packages
    |> Enum.map(fn package ->
      %{
        name: package.package_name,
        version: package.version,
        description: package.description,
        ecosystem: package.ecosystem || ecosystem,
        downloads: package.downloads,
        stars: package.stars,
        similarity: package.similarity,
        tags: package.tags || []
      }
    end)
  end

  defp format_code_results(code_results) do
    code_results
    |> Enum.map(fn result ->
      %{
        path: result.path,
        similarity: result.similarity,
        snippet: result.snippet || "No snippet available"
      }
    end)
  end

  defp format_recommendations(recommendations, language) do
    recommendations
    |> Enum.map(fn rec ->
      %{
        package: rec.package_name,
        version: rec.version,
        description: rec.description,
        ecosystem: rec.ecosystem,
        reason: rec.reason || "Recommended for #{language} development",
        similarity: rec.similarity,
        downloads: rec.downloads,
        stars: rec.stars
      }
    end)
  end
end