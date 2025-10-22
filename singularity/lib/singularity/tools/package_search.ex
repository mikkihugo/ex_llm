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
  Get specific package version details

  ## Parameters
  - package_spec: Package specification in format "name@version" (e.g., "react@18", "tokio@1.35")
  - ecosystem: Package ecosystem (:npm, :cargo, :hex, :pypi)

  ## Returns
  Package details with dependencies, examples, and metadata

  ## Examples
      iex> get_package("react@18", :npm)
      {:ok, %{name: "react", version: "18.2.0", ...}}

      iex> get_package("tokio@latest", :cargo)
      {:ok, %{name: "tokio", version: "1.35.1", ...}}
  """
  def get_package(package_spec, ecosystem) do
    {package_name, version} = parse_package_spec(package_spec)

    Logger.info("📦 Fetching #{ecosystem}/#{package_name}@#{version || "latest"}")

    request = %{
      "package_name" => package_name,
      "version" => version,
      "ecosystem" => to_string(ecosystem)
    }

    subject = "packages.registry.collect.#{ecosystem}"

    case call_nats(subject, request) do
      {:ok, result} ->
        Logger.info("✅ Got #{package_name} details")
        {:ok, result}

      {:error, reason} ->
        Logger.error("❌ Failed to get #{package_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Search for packages across different ecosystems

  ## Parameters
  - query: Search query string or "package@version" format
  - ecosystem: Package ecosystem (:npm, :cargo, :hex, :pypi, or :all)
  - limit: Maximum number of results (default: 10)

  ## Returns
  List of package search results with metadata

  ## Examples
      iex> search_packages("react", :npm)
      {:ok, [%{name: "react", ...}, %{name: "react-dom", ...}]}

      iex> search_packages("react@18", :npm)
      {:ok, %{name: "react", version: "18.2.0", ...}}  # Specific version
  """
  def search_packages(query, ecosystem \\ :all, limit \\ 10) when is_binary(query) do
    # Parse optional ecosystem prefix (e.g., "npm react", "cargo tokio")
    {parsed_ecosystem, clean_query} = parse_query_prefix(query, ecosystem)

    # If query contains @version, fetch specific package
    if String.contains?(clean_query, "@") do
      get_package(clean_query, parsed_ecosystem)
    else
      Logger.info("🔍 Searching packages: '#{clean_query}' in #{parsed_ecosystem} ecosystem")

      try do
        case PackageAndCodebaseSearch.hybrid_search(clean_query, %{
          ecosystem: parsed_ecosystem,
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
  end

  @doc """
  Parse optional ecosystem prefix from query

  ## Examples
      iex> parse_query_prefix("npm react", :all)
      {:npm, "react"}

      iex> parse_query_prefix("cargo tokio@1.35", :all)
      {:cargo, "tokio@1.35"}

      iex> parse_query_prefix("react", :npm)
      {:npm, "react"}

      iex> parse_query_prefix("github vercel/next.js", :all)
      {:github, "vercel/next.js"}
  """
  def parse_query_prefix(query, default_ecosystem) when is_binary(query) do
    query
    |> String.trim()
    |> String.split(" ", parts: 2)
    |> case do
      [prefix, rest] when prefix in ["npm", "cargo", "hex", "pypi", "github"] ->
        {String.to_atom(prefix), rest}

      _ ->
        {default_ecosystem, query}
    end
  end

  defp parse_package_spec(spec) when is_binary(spec) do
    case String.split(spec, "@", parts: 2) do
      [name, version] -> {name, version}
      [name] -> {name, nil}
    end
  end

  defp call_nats(subject, request) do
    case Singularity.NatsOrchestrator.request(subject, request, timeout: 15_000) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  rescue
    error ->
      Logger.error("NATS call exception: #{inspect(error)}")
      {:error, :exception}
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
