defmodule Singularity.TechnologyDetector do
  @moduledoc """
  Technology Detector (RustNif) - Detect frameworks, libraries, and tools
  
  Identifies technology stack:
  - Detect frameworks and libraries
  - Identify build tools and CI/CD
  - Detect databases and cloud services
  - Analyze technology usage patterns
  - Generate technology summary
  """

  use Rustler, otp_app: :singularity_app, crate: :singularity_unified

  def detect_frameworks(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def detect_libraries(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def detect_build_tools(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def detect_databases(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def detect_cloud_services(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def detect_ci_cd_tools(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)
  def get_technology_summary(_codebase_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Detect frameworks in codebase
  
  ## Examples
  
      iex> Singularity.TechnologyDetector.detect_frameworks("/path/to/project")
      [
        %{name: "React", version: "18.2.0", confidence: 0.95, category: "frontend"},
        %{name: "Express", version: "4.18.0", confidence: 0.88, category: "backend"}
      ]
  """
  def detect_frameworks(codebase_path) do
    detect_frameworks(codebase_path)
  end

  @doc """
  Detect libraries and dependencies
  
  ## Examples
  
      iex> Singularity.TechnologyDetector.detect_libraries("/path/to/project")
      [
        %{name: "lodash", version: "4.17.21", purpose: "utility"},
        %{name: "axios", version: "1.3.0", purpose: "http_client"}
      ]
  """
  def detect_libraries(codebase_path) do
    detect_libraries(codebase_path)
  end

  @doc """
  Detect build tools and package managers
  
  ## Examples
  
      iex> Singularity.TechnologyDetector.detect_build_tools("/path/to/project")
      [
        %{name: "webpack", version: "5.75.0", type: "bundler"},
        %{name: "npm", version: "8.19.0", type: "package_manager"}
      ]
  """
  def detect_build_tools(codebase_path) do
    detect_build_tools(codebase_path)
  end

  @doc """
  Detect databases and data stores
  
  ## Examples
  
      iex> Singularity.TechnologyDetector.detect_databases("/path/to/project")
      [
        %{name: "PostgreSQL", version: "14.0", type: "relational"},
        %{name: "Redis", version: "6.2.0", type: "cache"}
      ]
  """
  def detect_databases(codebase_path) do
    detect_databases(codebase_path)
  end

  @doc """
  Detect cloud services and platforms
  
  ## Examples
  
      iex> Singularity.TechnologyDetector.detect_cloud_services("/path/to/project")
      [
        %{name: "AWS S3", purpose: "file_storage"},
        %{name: "AWS Lambda", purpose: "serverless"}
      ]
  """
  def detect_cloud_services(codebase_path) do
    detect_cloud_services(codebase_path)
  end

  @doc """
  Detect CI/CD tools and pipelines
  
  ## Examples
  
      iex> Singularity.TechnologyDetector.detect_ci_cd_tools("/path/to/project")
      [
        %{name: "GitHub Actions", type: "ci_cd"},
        %{name: "Docker", version: "20.10.0", type: "containerization"}
      ]
  """
  def detect_ci_cd_tools(codebase_path) do
    detect_ci_cd_tools(codebase_path)
  end

  @doc """
  Get comprehensive technology summary
  
  ## Examples
  
      iex> Singularity.TechnologyDetector.get_technology_summary("/path/to/project")
      %{
        frontend: ["React", "TypeScript", "Webpack"],
        backend: ["Node.js", "Express", "PostgreSQL"],
        tools: ["npm", "Docker", "GitHub Actions"],
        languages: ["JavaScript", "TypeScript", "SQL"],
        total_technologies: 15
      }
  """
  def get_technology_summary(codebase_path) do
    get_technology_summary(codebase_path)
  end
end
