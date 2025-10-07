defmodule Singularity.VersionManager do
  @moduledoc """
  Version Management - Handle semantic versioning and compatibility
  
  Provides version parsing, range checking, and compatibility analysis:
  - Parse version specifiers (@latest, ^1.2.3, >=1.0.0 <2.0.0)
  - Check version compatibility
  - Resolve version specifiers
  - Generate compatibility warnings
  """

  use Rustler, otp_app: :singularity_app, crate: :singularity_unified

  # Version management functions
  def parse_version_specifier(_spec), do: :erlang.nif_error(:nif_not_loaded)
  def check_version_compatibility(_current_version, _target_spec), do: :erlang.nif_error(:nif_not_loaded)
  def resolve_version_specifier(_spec, _package_name, _ecosystem), do: :erlang.nif_error(:nif_not_loaded)
  def get_compatibility_warning(_spec, _current_version), do: :erlang.nif_error(:nif_not_loaded)
  def compare_versions(_version1, _version2), do: :erlang.nif_error(:nif_not_loaded)
  def is_version_in_range(_version, _range_spec), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Parse version specifier string
  
  ## Examples
  
      iex> Singularity.VersionManager.parse_version_specifier("@latest")
      %{type: :latest, spec: "latest"}
      
      iex> Singularity.VersionManager.parse_version_specifier("^1.2.3")
      %{type: :range, spec: "^1.2.3", constraints: [...]}
      
      iex> Singularity.VersionManager.parse_version_specifier(">=1.0.0 <2.0.0")
      %{type: :range, spec: ">=1.0.0 <2.0.0", constraints: [...]}
  """
  def parse_version_specifier(spec) do
    parse_version_specifier(spec)
  end

  @doc """
  Check if two versions are compatible
  
  ## Examples
  
      iex> Singularity.VersionManager.check_version_compatibility("1.8.0", ">=2.0.0")
      %{
        is_compatible: false,
        breaking_changes: ["Major version changed from 1 to 2"],
        migration_notes: ["Check breaking changes documentation"]
      }
  """
  def check_version_compatibility(current_version, target_spec) do
    check_version_compatibility(current_version, target_spec)
  end

  @doc """
  Resolve version specifier to actual version
  
  ## Examples
  
      iex> Singularity.VersionManager.resolve_version_specifier("@latest", "react", "npm")
      "18.2.0"
      
      iex> Singularity.VersionManager.resolve_version_specifier("@lts", "react", "npm")
      "18.1.0"
  """
  def resolve_version_specifier(spec, package_name, ecosystem) do
    resolve_version_specifier(spec, package_name, ecosystem)
  end

  @doc """
  Get compatibility warning for code snippets
  
  ## Examples
  
      iex> Singularity.VersionManager.get_compatibility_warning(">=2.0.0", "1.8.0")
      "⚠️  Major version mismatch: Code requires >=2.0.0 but you have 1.8.0 - API may have breaking changes!"
  """
  def get_compatibility_warning(spec, current_version) do
    get_compatibility_warning(spec, current_version)
  end

  @doc """
  Compare two versions
  
  ## Examples
  
      iex> Singularity.VersionManager.compare_versions("1.2.3", "1.2.4")
      :lt
      
      iex> Singularity.VersionManager.compare_versions("2.0.0", "1.9.9")
      :gt
  """
  def compare_versions(version1, version2) do
    compare_versions(version1, version2)
  end

  @doc """
  Check if version is in range
  
  ## Examples
  
      iex> Singularity.VersionManager.is_version_in_range("1.5.0", ">=1.0.0 <2.0.0")
      true
      
      iex> Singularity.VersionManager.is_version_in_range("2.1.0", ">=1.0.0 <2.0.0")
      false
  """
  def is_version_in_range(version, range_spec) do
    is_version_in_range(version, range_spec)
  end
end
