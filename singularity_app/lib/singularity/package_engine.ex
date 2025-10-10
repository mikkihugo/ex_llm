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

  use Rustler, otp_app: :singularity_app, crate: "package"

  alias Singularity.EngineCentralHub

  # NIF functions
  def scan_dependencies_nif(_path), do: :erlang.nif_error(:nif_not_loaded)
  def check_vulnerabilities_nif(_packages), do: :erlang.nif_error(:nif_not_loaded)
  def validate_versions_nif(_packages), do: :erlang.nif_error(:nif_not_loaded)

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
        # Query central for latest intelligence
        case query_intelligence(package_name) do
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
  Query package intelligence from central.
  Request/reply pattern via NATS.
  """
  def query_intelligence(package_name) do
    EngineCentralHub.query_package(package_name, "any")
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

  defp cache_package_data(package_name, intelligence) do
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
end
