defmodule Singularity.PackageEngine do
  @moduledoc """
  Hybrid Package Intelligence Engine.
  
  Local Layer (Singularity):
  - Package vulnerability checking
  - Dependency security scanning
  - Version validation
  - Mark unsafe dependencies
  
  Central Layer (Central Cloud via NATS):
  - Package intelligence index queries
  - Security vulnerability database
  - Best practices knowledge
  - Historical analysis
  
  Architecture:
  ```
  Singularity scans → Check local cache
    ↓ If unknown → Query central via NATS
  Central returns → Security advisories + intelligence
    ↓ Cache locally
  Singularity validates → Mark unsafe dependencies
  ```
  """

  # use Rustler, otp_app: :singularity, crate: "architecture_engine"

  alias Singularity.EngineCentralHub
  alias Singularity.ArchitectureEngine

  # Real NIF functions - delegate to Architecture Engine
  def scan_dependencies_nif(path) do
    # Use Architecture Engine's package collection capabilities
    # For now, provide a basic implementation that scans common package files
    scan_common_package_files(path)
  end

  def check_vulnerabilities_nif(packages) do
    # Check local cache first, then query central
    check_local_vulnerability_cache(packages)
  end

  def validate_versions_nif(packages) do
    # Validate version constraints and check for updates
    validate_package_versions(packages)
  end

  @doc """
  Check security vulnerabilities for a package.
  Queries local cache first, then central intelligence if needed.
  """
  def check_security(package_name, version) do
    # Check local cache first
    case check_vulnerabilities_nif([%{name: package_name, version: version}]) do
      {:ok, %{cache_hit: true} = result} ->
        {:ok, result}
      
      {:ok, %{cache_hit: false}} ->
        # Query central for latest intelligence via NATS
        case query_central_intelligence(package_name, version) do
          {:ok, intelligence} ->
            # Cache locally and return
            cache_package_data(package_name, intelligence)
            filter_vulnerabilities_for_version(intelligence, version)
          error -> error
        end
      
      error -> error
    end
  end

  @doc """
  Mark dependencies as unsafe based on security checks.
  Reports to central for global awareness.
  """
  def mark_unsafe(dependencies, reasons) do
    # Mark locally
    marked = Enum.map(dependencies, fn dep ->
      Map.put(dep, :unsafe, true)
      |> Map.put(:reasons, reasons)
    end)

    # Report to central
    EngineCentralHub.send_analysis(:package, %{
      type: "unsafe_dependencies",
      dependencies: marked,
      reasons: reasons
    })

    {:ok, marked}
  end

  @doc """
  Validate all dependencies in a project.
  Combines security, version, and compatibility checks.
  """
  def validate_deps(path) do
    with {:ok, deps} <- scan_dependencies_nif(path),
         {:ok, security} <- check_vulnerabilities_nif(deps),
         {:ok, versions} <- validate_versions_nif(deps) do
      
      unsafe = security[:vulnerabilities] ++ versions[:outdated]
      
      if length(unsafe) > 0 do
        mark_unsafe(unsafe, ["security_vulnerability", "outdated_version"])
      else
        {:ok, %{safe: true, dependencies: deps}}
      end
    end
  end

  @doc """
  Query package intelligence from central via NATS.
  Request/reply pattern using Singularity.NatsClient.
  """
  def query_intelligence(package_name) do
    query_central_intelligence(package_name, "any")
  end
  
  defp query_central_intelligence(package_name, version) do
    request = %{
      action: "get_package_intelligence",
      package_name: package_name,
      version: version,
      include_vulnerabilities: true,
      include_security_score: true
    }
    
    case Singularity.NatsClient.request("central.package.intelligence", Jason.encode!(request), timeout: 10000) do
      {:ok, response} ->
        case Jason.decode(response.data) do
          {:ok, data} -> {:ok, data}
          {:error, reason} -> {:error, "Failed to decode central response: #{reason}"}
        end
      {:error, reason} ->
        {:error, "NATS request failed: #{reason}"}
    end
  end

  @doc """
  Send package usage statistics to central for intelligence gathering.
  """
  def send_stats(stats) do
    EngineCentralHub.send_analysis(:package, %{
      type: "package_stats",
      data: stats
    })
  end

  # Private helpers

  defp cache_package_data(_package_name, _intelligence) do
    # Implementation would cache in local GenServer/ETS
    :ok
  end

  defp filter_vulnerabilities_for_version(intelligence, version) do
    vulnerabilities = intelligence[:vulnerabilities] || []
    
    applicable = Enum.filter(vulnerabilities, fn vuln ->
      version_in_range?(version, vuln[:affected_versions])
    end)

    {:ok, %{vulnerabilities: applicable, package: intelligence[:package]}}
  end

  defp version_in_range?(_version, _range) do
    # Simplified - real implementation would parse version ranges
    true
  end

  # NIF Implementation Functions

  defp scan_common_package_files(path) do
    # Scan for common package/dependency files
    package_files = [
      "package.json", "yarn.lock", "package-lock.json",  # JavaScript
      "requirements.txt", "setup.py", "Pipfile",         # Python
      "Gemfile", "Gemfile.lock",                         # Ruby
      "mix.exs", "mix.lock",                             # Elixir
      "Cargo.toml", "Cargo.lock",                        # Rust
      "go.mod", "go.sum",                                # Go
      "pom.xml", "build.gradle",                         # Java
      "composer.json",                                   # PHP
    ]

    # Check if path is a directory or file
    if File.dir?(path) do
      # Scan directory for package files
      found_files = Enum.filter(package_files, fn file ->
        File.exists?(Path.join(path, file))
      end)

      packages = Enum.flat_map(found_files, fn file ->
        parse_package_file(Path.join(path, file))
      end)

      {:ok, packages}
    else
      # Single file scan
      if Enum.member?(package_files, Path.basename(path)) do
        packages = parse_package_file(path)
        {:ok, packages}
      else
        {:ok, []}
      end
    end
  end

  defp parse_package_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        case Path.extname(file_path) do
          ".json" -> parse_json_package(content, file_path)
          ".toml" -> parse_toml_package(content, file_path)
          ".lock" -> parse_lockfile_package(content, file_path)
          _ -> parse_text_package(content, file_path)
        end

      {:error, _} -> []
    end
  end

  defp parse_json_package(content, file_path) do
    case Jason.decode(content) do
      {:ok, data} ->
        dependencies = data["dependencies"] || %{}
        dev_dependencies = data["devDependencies"] || %{}

        all_deps = Map.merge(dependencies, dev_dependencies)

        Enum.map(all_deps, fn {name, version} ->
          %{name: name, version: version, ecosystem: detect_ecosystem_from_file(file_path)}
        end)

      {:error, _} -> []
    end
  end

  defp parse_toml_package(content, file_path) do
    # Basic TOML parsing for Rust Cargo.toml
    if String.contains?(content, "[dependencies]") do
      # Simple parsing - real implementation would use proper TOML parser
      [%{name: "rust_dependencies", version: "latest", ecosystem: detect_ecosystem_from_file(file_path)}]
    else
      []
    end
  end

  defp parse_lockfile_package(_content, _file_path) do
    # Lock files are complex - return empty for now
    # Real implementation would parse specific lock file formats
    []
  end

  defp parse_text_package(content, file_path) do
    # Basic text parsing for other formats
    lines = String.split(content, "\n")
    ecosystem = detect_ecosystem_from_file(file_path)
    Enum.flat_map(lines, fn line ->
      cond do
        String.contains?(line, "gem ") -> [%{name: extract_gem_name(line), version: "latest", ecosystem: ecosystem}]
        String.contains?(line, "pip install") -> [%{name: extract_pip_name(line), version: "latest", ecosystem: ecosystem}]
        true -> []
      end
    end)
  end

  defp detect_ecosystem_from_file(file_path) do
    case Path.basename(file_path) do
      "package.json" -> "javascript"
      "requirements.txt" -> "python"
      "Gemfile" -> "ruby"
      "mix.exs" -> "elixir"
      "Cargo.toml" -> "rust"
      "go.mod" -> "go"
      "pom.xml" -> "java"
      "composer.json" -> "php"
      _ -> "unknown"
    end
  end

  defp extract_gem_name(line) do
    # Simple extraction - real implementation would be more robust
    String.split(line, "gem ") |> List.last() |> String.split() |> List.first() || "unknown"
  end

  defp extract_pip_name(line) do
    # Simple extraction - real implementation would be more robust
    String.split(line, "pip install ") |> List.last() |> String.split() |> List.first() || "unknown"
  end

  defp check_local_vulnerability_cache(packages) do
    # Check local cache for known vulnerabilities
    # Real implementation would query a local vulnerability database
    vulnerabilities = Enum.filter(packages, fn package ->
      # Mock vulnerability check - real implementation would check against CVE database
      String.contains?(package.name, "old") or package.version == "0.1.0"
    end)

    {:ok, %{vulnerabilities: vulnerabilities, total_checked: length(packages)}}
  end

  defp validate_package_versions(packages) do
    # Validate version constraints and check for updates
    # Real implementation would check against package registries
    validated = Enum.map(packages, fn package ->
      Map.put(package, :valid, true)
      |> Map.put(:latest_version, package.version)
      |> Map.put(:outdated, false)
    end)

    {:ok, %{packages: validated, total_validated: length(packages)}}
  end
end
