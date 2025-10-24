defmodule Centralcloud.Jobs.PackageSyncJob do
  @moduledoc """
  Oban job for external package registry synchronization.

  Syncs package metadata from external registries:
  - npm (JavaScript ecosystem)
  - cargo (Rust ecosystem)
  - hex (Elixir ecosystem)
  - pypi (Python ecosystem)

  Runs daily at 2 AM via Oban Cron.

  ## Purpose

  Keep Centralcloud's knowledge of external packages current:
  - New package releases
  - Updated dependency information
  - Security advisories
  - Download statistics
  - Quality scores

  This enables:
  - "What packages in npm do similar work?"
  - "Has this package been updated recently?"
  - "What are security advisories for this version?"
  - "What do other teams use for this task?"
  """

  use Oban.Worker,
    queue: :sync,
    max_attempts: 3,
    unique: [period: 86_400]  # Only one job per day

  require Logger
  import Ecto.Query
  alias Centralcloud.{Repo, NatsClient}
  alias Centralcloud.Schemas.Package

  # Registry API endpoints
  @npm_registry "https://registry.npmjs.org"
  @cargo_registry "https://crates.io/api/v1"
  @hex_registry "https://hex.pm/api"
  @pypi_registry "https://pypi.org/pypi"

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Oban: Running package sync")

    case sync_packages() do
      count when is_integer(count) ->
        Logger.info("Package sync completed: #{count} packages synced")
        :ok
      :ok ->
        :ok
      {:error, reason} ->
        Logger.error("Package sync failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Sync external package registries based on actual usage from Singularity instances.

  Called once daily (at 2 AM) via Oban Cron.
  """
  def sync_packages do
    Logger.debug("📦 Starting intelligent package registry sync...")

    try do
      # Get packages that are actually being used by Singularity instances
      requested_packages = get_requested_packages()
      
      # Sync only the packages that are actually needed
      npm_synced = sync_requested_npm_packages(requested_packages.npm)
      cargo_synced = sync_requested_cargo_packages(requested_packages.cargo)
      hex_synced = sync_requested_hex_packages(requested_packages.hex)
      pypi_synced = sync_requested_pypi_packages(requested_packages.pypi)

      total_synced = npm_synced + cargo_synced + hex_synced + pypi_synced

      # Generate quality metrics for synced packages
      generate_quality_metrics()

      # Cross-reference with instance learning
      cross_reference_with_learning()

      # Clean up old packages based on usage patterns
      cleanup_old_packages()

      Logger.info("📦 Intelligent package sync complete",
        total: total_synced,
        requested: map_size(requested_packages),
        npm: npm_synced,
        cargo: cargo_synced,
        hex: hex_synced,
        pypi: pypi_synced
      )

      total_synced
    rescue
      e in Exception ->
        Logger.error("❌ Package sync failed", error: inspect(e), stacktrace: __STACKTRACE__)
        :ok  # Don't crash - will retry tomorrow
    end
  end

  defp get_requested_packages do
    # Get packages from two sources:
    # 1. Dependencies reported by Singularity instances via NATS
    # 2. Packages that instances have specifically requested
    
    instance_dependencies = get_instance_dependencies()
    requested_packages = get_specifically_requested_packages()
    
    # Merge both sources
    %{
      "npm" => (instance_dependencies["npm"] || []) ++ (requested_packages["npm"] || []),
      "cargo" => (instance_dependencies["cargo"] || []) ++ (requested_packages["cargo"] || []),
      "hex" => (instance_dependencies["hex"] || []) ++ (requested_packages["hex"] || []),
      "pypi" => (instance_dependencies["pypi"] || []) ++ (requested_packages["pypi"] || [])
    }
    |> Enum.map(fn {ecosystem, packages} -> 
      {ecosystem, Enum.uniq(packages)}
    end)
    |> Enum.into(%{})
  end

  defp get_instance_dependencies do
    # Get dependencies that instances have reported via NATS
    # These are stored in the database when instances send dependency reports
    
    query = """
    SELECT DISTINCT ecosystem, package_name
    FROM instance_dependencies 
    WHERE reported_at > NOW() - INTERVAL '7 days'
    ORDER BY reported_at DESC
    """
    
    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.group_by(fn [ecosystem, _] -> ecosystem end)
        |> Enum.map(fn {ecosystem, packages} -> 
          {ecosystem, Enum.map(packages, fn [_, name] -> name end)}
        end)
        |> Enum.into(%{})
      
      _ -> %{}
    end
  end

  defp get_specifically_requested_packages do
    # Get packages that instances have specifically requested via NATS
    # These are stored when instances ask for package information
    
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)
    
    query = """
    SELECT DISTINCT 
      CASE 
        WHEN package_name LIKE '%.js' OR package_name LIKE '%.ts' THEN 'npm'
        WHEN package_name LIKE '%.rs' OR package_name LIKE '%.toml' THEN 'cargo'
        WHEN package_name LIKE '%.ex' OR package_name LIKE '%.exs' THEN 'hex'
        WHEN package_name LIKE '%.py' THEN 'pypi'
        ELSE 'unknown'
      END as ecosystem,
      package_name
    FROM usage_analytics 
    WHERE created_at > $1 
      AND event_type IN ('package_search', 'package_view', 'package_install')
      AND package_name IS NOT NULL
    """
    
    case Repo.query(query, [seven_days_ago]) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.group_by(fn [ecosystem, package_name] -> ecosystem end)
        |> Enum.map(fn {ecosystem, packages} -> 
          {ecosystem, Enum.map(packages, fn [_, name] -> name end)}
        end)
        |> Enum.into(%{})
      
      _ -> %{}
    end
  end

  # ===========================
  # Private Sync Functions
  # ===========================

  defp sync_requested_npm_packages(requested_packages) do
    Logger.debug("📦 Syncing requested npm packages: #{length(requested_packages)}")

    if Enum.empty?(requested_packages) do
      Logger.debug("No npm packages requested, skipping")
      0
    else
      try do
        # Fetch only the packages that are actually requested
        synced_count = 
          requested_packages
          |> Enum.map(&fetch_and_process_npm_package/1)
          |> Enum.count(&(&1 != :error))

        Logger.debug("npm sync: Processed #{synced_count} requested packages from #{@npm_registry}")
        synced_count
      rescue
        e in Exception ->
          Logger.error("npm sync failed: #{inspect(e)}")
          0
      end
    end
  end

  defp fetch_and_process_npm_package(package_name) do
    # Fetch specific package from npm registry
    url = "#{@npm_registry}/#{package_name}"
    
    case Req.get(url, receive_timeout: 10_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, package_data} ->
            process_npm_package(package_data)
          
          {:error, reason} ->
            Logger.error("Failed to parse npm package #{package_name}: #{inspect(reason)}")
            :error
        end
      
      {:ok, %Req.Response{status: 404}} ->
        Logger.debug("npm package not found: #{package_name}")
        :not_found
      
      {:ok, %Req.Response{status: status}} ->
        Logger.error("npm API returned status #{status} for #{package_name}")
        :error
      
      {:error, reason} ->
        Logger.error("npm API request failed for #{package_name}: #{inspect(reason)}")
        :error
    end
  end

  defp fetch_npm_popular_packages(limit: limit) do
    # Fetch popular packages from npm registry
    # Using the npm search API to get trending packages
    url = "#{@npm_registry}/-/v1/search?text=*&size=#{limit}&popularity=1.0"
    
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"objects" => objects}} ->
            objects
            |> Enum.map(fn %{"package" => pkg} -> pkg end)
            |> Enum.take(limit)
          
          {:error, reason} ->
            Logger.error("Failed to parse npm response: #{inspect(reason)}")
            []
        end
      
      {:ok, %Req.Response{status: status}} ->
        Logger.error("npm API returned status #{status}")
        []
      
      {:error, reason} ->
        Logger.error("npm API request failed: #{inspect(reason)}")
        []
    end
  end

  defp process_npm_package(package_data) do
    # Extract package details and upsert to database
    attrs = %{
      name: package_data["name"],
      ecosystem: "npm",
      version: package_data["version"],
      description: package_data["description"],
      homepage: package_data["homepage"],
      repository: get_in(package_data, ["repository", "url"]),
      license: get_in(package_data, ["license"]),
      keywords: package_data["keywords"] || [],
      dependencies: extract_npm_dependencies(package_data),
      tags: extract_npm_tags(package_data),
      source: "npm_registry",
      last_updated: DateTime.utc_now()
    }

    upsert_package(attrs, "npm")
  end

  defp extract_npm_dependencies(package_data) do
    # Extract dependencies from package.json structure
    case package_data do
      %{"dependencies" => deps} when is_map(deps) -> Map.keys(deps)
      %{"peerDependencies" => deps} when is_map(deps) -> Map.keys(deps)
      _ -> []
    end
  end

  defp extract_npm_tags(package_data) do
    # Extract tags from keywords and other metadata
    keywords = package_data["keywords"] || []
    categories = package_data["categories"] || []
    
    (keywords ++ categories)
    |> Enum.uniq()
    |> Enum.take(10)
  end

  defp sync_requested_cargo_packages(requested_packages) do
    Logger.debug("📦 Syncing requested cargo packages: #{length(requested_packages)}")

    if Enum.empty?(requested_packages) do
      Logger.debug("No cargo packages requested, skipping")
      0
    else
      try do
        # Fetch only the crates that are actually requested
        synced_count = 
          requested_packages
          |> Enum.map(&fetch_and_process_cargo_crate/1)
          |> Enum.count(&(&1 != :error))

        Logger.debug("cargo sync: Processed #{synced_count} requested crates from #{@cargo_registry}")
        synced_count
      rescue
        e in Exception ->
          Logger.error("cargo sync failed: #{inspect(e)}")
          0
      end
    end
  end

  defp fetch_and_process_cargo_crate(crate_name) do
    # Fetch specific crate from crates.io
    url = "#{@cargo_registry}/crates/#{crate_name}"
    
    case Req.get(url, receive_timeout: 10_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"crate" => crate_data}} ->
            process_cargo_crate(crate_data)
          
          {:ok, crate_data} ->
            process_cargo_crate(crate_data)
          
          {:error, reason} ->
            Logger.error("Failed to parse cargo crate #{crate_name}: #{inspect(reason)}")
            :error
        end
      
      {:ok, %Req.Response{status: 404}} ->
        Logger.debug("cargo crate not found: #{crate_name}")
        :not_found
      
      {:ok, %Req.Response{status: status}} ->
        Logger.error("cargo API returned status #{status} for #{crate_name}")
        :error
      
      {:error, reason} ->
        Logger.error("cargo API request failed for #{crate_name}: #{inspect(reason)}")
        :error
    end
  end

  defp fetch_cargo_popular_crates(limit: limit) do
    # Fetch popular crates from crates.io API
    url = "#{@cargo_registry}/crates?sort=downloads&per_page=#{limit}"
    
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"crates" => crates}} ->
            crates
            |> Enum.take(limit)
          
          {:error, reason} ->
            Logger.error("Failed to parse cargo response: #{inspect(reason)}")
            []
        end
      
      {:ok, %Req.Response{status: status}} ->
        Logger.error("cargo API returned status #{status}")
        []
      
      {:error, reason} ->
        Logger.error("cargo API request failed: #{inspect(reason)}")
        []
    end
  end

  defp process_cargo_crate(crate_data) do
    # Extract crate details and upsert to database
    attrs = %{
      name: crate_data["name"],
      ecosystem: "cargo",
      version: crate_data["newest_version"],
      description: crate_data["description"],
      homepage: crate_data["homepage"],
      repository: crate_data["repository"],
      license: crate_data["license"],
      keywords: crate_data["keywords"] || [],
      dependencies: [], # Would need separate API call to get dependencies
      tags: extract_cargo_tags(crate_data),
      source: "cargo_registry",
      last_updated: DateTime.utc_now()
    }

    upsert_package(attrs, "cargo")
  end

  defp extract_cargo_tags(crate_data) do
    # Extract tags from keywords and categories
    keywords = crate_data["keywords"] || []
    categories = crate_data["categories"] || []
    
    (keywords ++ categories)
    |> Enum.uniq()
    |> Enum.take(10)
  end

  defp sync_requested_hex_packages(requested_packages) do
    Logger.debug("📦 Syncing requested hex packages: #{length(requested_packages)}")

    if Enum.empty?(requested_packages) do
      Logger.debug("No hex packages requested, skipping")
      0
    else
      try do
        # Fetch only the packages that are actually requested
        synced_count = 
          requested_packages
          |> Enum.map(&fetch_and_process_hex_package/1)
          |> Enum.count(&(&1 != :error))

        Logger.debug("hex sync: Processed #{synced_count} requested packages from #{@hex_registry}")
        synced_count
      rescue
        e in Exception ->
          Logger.error("hex sync failed: #{inspect(e)}")
          0
      end
    end
  end

  defp fetch_and_process_hex_package(package_name) do
    # Fetch specific package from hex.pm
    url = "#{@hex_registry}/packages/#{package_name}"
    
    case Req.get(url, receive_timeout: 10_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, package_data} ->
            process_hex_package(package_data)
          
          {:error, reason} ->
            Logger.error("Failed to parse hex package #{package_name}: #{inspect(reason)}")
            :error
        end
      
      {:ok, %Req.Response{status: 404}} ->
        Logger.debug("hex package not found: #{package_name}")
        :not_found
      
      {:ok, %Req.Response{status: status}} ->
        Logger.error("hex API returned status #{status} for #{package_name}")
        :error
      
      {:error, reason} ->
        Logger.error("hex API request failed for #{package_name}: #{inspect(reason)}")
        :error
    end
  end

  defp fetch_hex_popular_packages(limit: limit) do
    # Fetch popular packages from hex.pm API
    url = "#{@hex_registry}/packages?sort=downloads&limit=#{limit}"
    
    case Req.get(url, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, packages} when is_list(packages) ->
            packages
            |> Enum.take(limit)
          
          {:error, reason} ->
            Logger.error("Failed to parse hex response: #{inspect(reason)}")
            []
        end
      
      {:ok, %Req.Response{status: status}} ->
        Logger.error("hex API returned status #{status}")
        []
      
      {:error, reason} ->
        Logger.error("hex API request failed: #{inspect(reason)}")
        []
    end
  end

  defp process_hex_package(package_data) do
    # Extract package details and upsert to database
    attrs = %{
      name: package_data["name"],
      ecosystem: "hex",
      version: package_data["latest_version"],
      description: package_data["meta"]["description"],
      homepage: package_data["meta"]["links"]["homepage"],
      repository: package_data["meta"]["links"]["github"],
      license: package_data["meta"]["licenses"] |> List.first(),
      keywords: package_data["meta"]["tags"] || [],
      dependencies: [], # Would need separate API call to get dependencies
      tags: package_data["meta"]["tags"] || [],
      source: "hex_registry",
      last_updated: DateTime.utc_now()
    }

    upsert_package(attrs, "hex")
  end

  defp sync_requested_pypi_packages(requested_packages) do
    Logger.debug("📦 Syncing requested pypi packages: #{length(requested_packages)}")

    if Enum.empty?(requested_packages) do
      Logger.debug("No pypi packages requested, skipping")
      0
    else
      try do
        # Fetch only the packages that are actually requested
        synced_count = 
          requested_packages
          |> Enum.map(&fetch_and_process_pypi_package/1)
          |> Enum.count(&(&1 != :error))

        Logger.debug("pypi sync: Processed #{synced_count} requested packages from #{@pypi_registry}")
        synced_count
      rescue
        e in Exception ->
          Logger.error("pypi sync failed: #{inspect(e)}")
          0
      end
    end
  end

  defp fetch_and_process_pypi_package(package_name) do
    # Fetch specific package from PyPI
    url = "#{@pypi_registry}/#{package_name}/json"
    
    case Req.get(url, receive_timeout: 10_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, package_data} ->
            process_pypi_package(package_data)
          
          {:error, reason} ->
            Logger.error("Failed to parse pypi package #{package_name}: #{inspect(reason)}")
            :error
        end
      
      {:ok, %Req.Response{status: 404}} ->
        Logger.debug("pypi package not found: #{package_name}")
        :not_found
      
      {:ok, %Req.Response{status: status}} ->
        Logger.error("pypi API returned status #{status} for #{package_name}")
        :error
      
      {:error, reason} ->
        Logger.error("pypi API request failed for #{package_name}: #{inspect(reason)}")
        :error
    end
  end

  defp fetch_pypi_popular_packages(limit: limit) do
    # Fetch popular packages from PyPI using the simple API
    # Note: PyPI doesn't have a direct "popular packages" endpoint
    # We'll use a list of known popular packages for now
    popular_package_names = [
      "requests", "numpy", "pandas", "matplotlib", "scikit-learn", "tensorflow",
      "torch", "flask", "django", "fastapi", "pytest", "jupyter", "beautifulsoup4",
      "pillow", "opencv-python", "scipy", "seaborn", "plotly", "streamlit",
      "boto3", "psycopg2", "sqlalchemy", "celery", "redis", "pydantic"
    ]
    
    # Fetch details for each package
    popular_package_names
    |> Enum.take(limit)
    |> Enum.map(&fetch_pypi_package_details/1)
    |> Enum.filter(&(&1 != nil))
  end

  defp fetch_pypi_package_details(package_name) do
    url = "#{@pypi_registry}/#{package_name}/json"
    
    case Req.get(url, receive_timeout: 10_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, package_data} -> package_data
          {:error, _} -> nil
        end
      
      _ -> nil
    end
  end

  defp process_pypi_package(package_data) do
    # Extract package details and upsert to database
    info = package_data["info"] || %{}
    
    attrs = %{
      name: info["name"],
      ecosystem: "pypi",
      version: info["version"],
      description: info["summary"],
      homepage: info["home_page"],
      repository: info["project_urls"]["Source"] || info["project_urls"]["Repository"],
      license: info["license"],
      keywords: String.split(info["keywords"] || "", ",") |> Enum.map(&String.trim/1),
      dependencies: extract_pypi_dependencies(package_data),
      tags: extract_pypi_tags(info),
      source: "pypi_registry",
      last_updated: DateTime.utc_now()
    }

    upsert_package(attrs, "pypi")
  end

  defp extract_pypi_dependencies(package_data) do
    # Extract dependencies from requires_dist
    case package_data["info"]["requires_dist"] do
      nil -> []
      deps when is_list(deps) -> 
        deps
        |> Enum.map(fn dep -> 
          dep
          |> String.split(" ")
          |> List.first()
          |> String.replace(~r/[>=<!=].*/, "")
        end)
      _ -> []
    end
  end

  defp extract_pypi_tags(info) do
    # Extract tags from classifiers
    classifiers = info["classifiers"] || []
    
    classifiers
    |> Enum.filter(&String.starts_with?(&1, "Topic :: "))
    |> Enum.map(&String.replace(&1, "Topic :: ", ""))
    |> Enum.take(10)
  end

  # Helper function that would be used for actual package upsert
  defp upsert_package(package_data, ecosystem) do
    attrs = %{
      name: package_data["name"],
      ecosystem: ecosystem,
      version: package_data["version"],
      description: package_data["description"],
      homepage: package_data["homepage"],
      repository: package_data["repository"],
      license: package_data["license"],
      keywords: package_data["keywords"] || [],
      dependencies: extract_dependencies(package_data),
      tags: extract_tags(package_data),
      source: "registry",
      last_updated: DateTime.utc_now()
    }

    case Repo.get_by(Package, name: attrs.name, ecosystem: ecosystem, version: attrs.version) do
      nil ->
        # Insert new package
        %Package{}
        |> Package.changeset(attrs)
        |> Repo.insert()

      existing ->
        # Update existing package
        existing
        |> Package.changeset(attrs)
        |> Repo.update()
    end
  end

  defp extract_dependencies(package_data) do
    # Extract dependencies from package metadata
    # Format depends on ecosystem (package.json vs Cargo.toml vs mix.exs)
    case package_data["dependencies"] do
      deps when is_map(deps) -> Map.keys(deps)
      deps when is_list(deps) -> deps
      _ -> []
    end
  end

  defp extract_tags(package_data) do
    # Extract relevant tags for categorization
    keywords = package_data["keywords"] || []
    categories = package_data["categories"] || []

    (keywords ++ categories)
    |> Enum.uniq()
    |> Enum.take(10)  # Limit to 10 tags
  end

  defp generate_quality_metrics do
    # Generate quality scores for all packages
    # Based on: recency, dependencies, security, documentation

    Logger.debug("📊 Generating quality metrics for packages...")

    # Query all packages that need quality metrics
    query = from p in Package,
      where: is_nil(p.security_score) or p.last_updated > ago(7, "day"),
      select: p

    packages = Repo.all(query)

    Enum.each(packages, fn package ->
      quality_score = calculate_quality_score(package)

      package
      |> Ecto.Changeset.change(%{security_score: quality_score})
      |> Repo.update()
    end)

    Logger.debug("Generated quality metrics for #{length(packages)} packages")
  end

  @doc """
  Clean up old package data based on usage patterns.
  - Packages in active dependencies: Keep for 30 days
  - Packages only requested (not in deps): Keep for 14 days
  - Unused packages: Keep for 7 days
  """
  def cleanup_old_packages do
    Logger.debug("🧹 Starting package cleanup based on usage patterns...")

    # Get packages that are in active dependencies (keep for 30 days)
    active_dependency_packages = get_active_dependency_packages()
    
    # Get packages that were only requested (keep for 14 days)
    requested_only_packages = get_requested_only_packages()
    
    # Clean up old packages based on their usage status
    cleanup_packages_by_usage(active_dependency_packages, requested_only_packages)
    
    Logger.debug("🧹 Package cleanup complete")
  end

  defp get_active_dependency_packages do
    # Get packages that are currently in someone's dependencies
    query = """
    SELECT DISTINCT p.name, p.ecosystem
    FROM packages p
    INNER JOIN instance_dependencies id ON p.name = id.package_name AND p.ecosystem = id.ecosystem
    WHERE id.reported_at > NOW() - INTERVAL '30 days'
    """
    
    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [name, ecosystem] -> {name, ecosystem} end)
        |> MapSet.new()
      
      _ -> MapSet.new()
    end
  end

  defp get_requested_only_packages do
    # Get packages that were requested but not in dependencies
    query = """
    SELECT DISTINCT p.name, p.ecosystem
    FROM packages p
    INNER JOIN usage_analytics ua ON p.name = ua.package_name
    WHERE ua.event_type IN ('package_search', 'package_view')
      AND ua.created_at > NOW() - INTERVAL '14 days'
      AND NOT EXISTS (
        SELECT 1 FROM instance_dependencies id 
        WHERE id.package_name = p.name AND id.ecosystem = p.ecosystem
        AND id.reported_at > NOW() - INTERVAL '30 days'
      )
    """
    
    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [name, ecosystem] -> {name, ecosystem} end)
        |> MapSet.new()
      
      _ -> MapSet.new()
    end
  end

  defp cleanup_packages_by_usage(active_deps, requested_only) do
    # Delete packages that are not in active dependencies and are older than their retention period
    
    # Delete packages older than 7 days that are not in any category
    delete_old_unused_packages()
    
    # Delete packages older than 14 days that were only requested
    delete_old_requested_packages(requested_only)
    
    # Keep active dependency packages for 30 days (no deletion needed)
    Logger.debug("Active dependency packages: #{MapSet.size(active_deps)}")
    Logger.debug("Requested-only packages: #{MapSet.size(requested_only)}")
  end

  defp delete_old_unused_packages do
    # Delete packages older than 7 days that are not in any usage category
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)
    
    query = """
    DELETE FROM packages 
    WHERE last_updated < $1
      AND NOT EXISTS (
        SELECT 1 FROM instance_dependencies id 
        WHERE id.package_name = packages.name AND id.ecosystem = packages.ecosystem
        AND id.reported_at > NOW() - INTERVAL '30 days'
      )
      AND NOT EXISTS (
        SELECT 1 FROM usage_analytics ua 
        WHERE ua.package_name = packages.name
        AND ua.created_at > NOW() - INTERVAL '14 days'
      )
    """
    
    case Repo.query(query, [seven_days_ago]) do
      {:ok, %{num_rows: count}} ->
        Logger.debug("Deleted #{count} old unused packages")
      
      _ -> :ok
    end
  end

  defp delete_old_requested_packages(requested_only) do
    # Delete packages older than 14 days that were only requested
    fourteen_days_ago = DateTime.utc_now() |> DateTime.add(-14, :day)
    
    if MapSet.size(requested_only) > 0 do
      package_conditions = 
        requested_only
        |> Enum.map(fn {name, ecosystem} -> 
          "(name = '#{name}' AND ecosystem = '#{ecosystem}')"
        end)
        |> Enum.join(" OR ")
      
      query = """
      DELETE FROM packages 
      WHERE last_updated < $1
        AND (#{package_conditions})
      """
      
      case Repo.query(query, [fourteen_days_ago]) do
        {:ok, %{num_rows: count}} ->
          Logger.debug("Deleted #{count} old requested-only packages")
        
        _ -> :ok
      end
    end
  end

  defp calculate_quality_score(package) do
    # Simple quality scoring algorithm
    # In production, would use more sophisticated analysis

    base_score = 50.0

    # Bonus for recent updates (up to +20)
    recency_bonus = if package.last_updated do
      days_old = DateTime.diff(DateTime.utc_now(), package.last_updated, :day)
      max(0, 20 - (days_old / 30))
    else
      0
    end

    # Bonus for documentation (up to +15)
    docs_bonus = if package.description && String.length(package.description) > 50, do: 15, else: 0

    # Bonus for keywords/tags (up to +10)
    tags_bonus = min(length(package.keywords || []) * 2, 10)

    # Penalty for too many dependencies (up to -10)
    deps_penalty = min(length(package.dependencies || []) * 0.5, 10)

    # Bonus for having homepage/repo (up to +5)
    links_bonus = 0
    links_bonus = if package.homepage, do: links_bonus + 2.5, else: links_bonus
    links_bonus = if package.repository, do: links_bonus + 2.5, else: links_bonus

    total = base_score + recency_bonus + docs_bonus + tags_bonus - deps_penalty + links_bonus

    # Clamp between 0 and 100
    total
    |> max(0.0)
    |> min(100.0)
    |> Float.round(2)
  end

  defp cross_reference_with_learning do
    # Cross-reference with instance learning
    # This would analyze actual dependency files from Singularity instances
    # and ensure we have metadata for packages they're actually using
    
    Logger.debug("🔍 Cross-referencing with instance learning...")
    
    # Query for packages that instances are actually using
    # This could come from:
    # 1. Analysis of package.json files in singularity/ directory
    # 2. Analysis of mix.exs files for Elixir dependencies
    # 3. Analysis of Cargo.toml files for Rust dependencies
    # 4. Analysis of requirements.txt or pyproject.toml for Python dependencies
    
    # For now, we'll query the database for packages that have been used
    # In the future, this could be more sophisticated
    :ok
  end

  @doc """
  Handle dependency reports from Singularity instances.
  This is called via NATS when instances report their dependencies.
  """
  def handle_dependency_report(instance_id, dependencies) do
    Logger.info("📦 Received dependency report from instance #{instance_id}: #{length(dependencies)} packages")
    
    # Store dependencies in database
    store_instance_dependencies(instance_id, dependencies)
    
    # Trigger immediate sync for new dependencies
    spawn(fn -> sync_new_dependencies(dependencies) end)
    
    :ok
  end

  defp store_instance_dependencies(instance_id, dependencies) do
    # Store dependencies reported by instances
    timestamp = DateTime.utc_now()
    
    dependency_records = 
      dependencies
      |> Enum.map(fn {package_name, ecosystem, version} ->
        %{
          instance_id: instance_id,
          package_name: package_name,
          ecosystem: ecosystem,
          version: version,
          reported_at: timestamp
        }
      end)
    
    # Insert or update dependencies
    # This would use a proper Ecto schema in production
    Enum.each(dependency_records, fn record ->
      query = """
      INSERT INTO instance_dependencies (instance_id, package_name, ecosystem, version, reported_at)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (instance_id, package_name, ecosystem)
      DO UPDATE SET version = EXCLUDED.version, reported_at = EXCLUDED.reported_at
      """
      
      Repo.query(query, [
        record.instance_id,
        record.package_name,
        record.ecosystem,
        record.version,
        record.reported_at
      ])
    end)
  end

  defp sync_new_dependencies(dependencies) do
    # Immediately sync new dependencies that instances have reported
    dependencies
    |> Enum.group_by(fn {_, ecosystem, _} -> ecosystem end)
    |> Enum.each(fn {ecosystem, deps} ->
      package_names = Enum.map(deps, fn {name, _, _} -> name end)
      
      case ecosystem do
        "npm" -> sync_requested_npm_packages(package_names)
        "cargo" -> sync_requested_cargo_packages(package_names)
        "hex" -> sync_requested_hex_packages(package_names)
        "pypi" -> sync_requested_pypi_packages(package_names)
        _ -> :ok
      end
    end)
  end

  defp parse_dependency_files_from_instances do
    # Parse actual dependency files from Singularity instances
    # This would be called by instances via NATS to report their dependencies
    
    # Example: Parse package.json from singularity/ directory
    package_json_path = Path.join([File.cwd!(), "..", "singularity", "package.json"])
    
    if File.exists?(package_json_path) do
      case File.read(package_json_path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"dependencies" => deps}} ->
              # Extract npm dependencies
              deps
              |> Map.keys()
              |> Enum.map(fn dep -> {dep, "npm"} end)
            
            _ -> []
          end
        
        _ -> []
      end
    else
      []
    end
  end
end
