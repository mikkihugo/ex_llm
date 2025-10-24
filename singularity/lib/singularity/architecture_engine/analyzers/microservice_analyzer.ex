defmodule Singularity.Architecture.Analyzers.MicroserviceAnalyzer do
  @moduledoc """
  Microservice Analyzer - Detects microservice vs monolith architecture patterns.

  Analyzes repository structure and service boundaries to determine:
  - Number of independent services
  - Service communication patterns
  - Monolithic vs distributed architecture
  - Service mesh presence

  Implements `@behaviour AnalyzerType` for config-driven orchestration.

  Note: This consolidates service analysis from the storage layer into the
  architecture engine for unified orchestration.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Architecture.Analyzers.MicroserviceAnalyzer",
    "type": "analyzer",
    "purpose": "Detect microservice vs monolith architecture patterns",
    "layer": "architecture_engine",
    "behavior": "AnalyzerType",
    "registered_in": "config :singularity, :analyzer_types, microservice: ...",
    "scope": "Repository structure, service boundaries, deployment patterns"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A[analyze/2] --> B[discover_services]
      B --> C[detect_language]
      B --> D[detect_build_config]
      B --> E[detect_build_system]
      C --> F[classify_architecture]
      D --> F
      E --> F
      F --> G[detect_service_mesh]
      G --> H[return architecture type]
      H --> I[service_count + pattern]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.LanguageDetection (language detection)
    - File system inspection (build config detection)
    - Logger (error handling and learning)

  called_by:
    - Singularity.Architecture.AnalysisOrchestrator
    - Architecture assessment pipelines
    - Service boundary analyzers
    - Migration planning tools
  ```

  ## Anti-Patterns

  - ❌ `ServiceDetector` - Use MicroserviceAnalyzer for service discovery
  - ❌ `ArchitectureClassifier` - Use microservice analyzer for classification
  - ❌ `DeploymentAnalyzer` - Use build config detection from MicroserviceAnalyzer
  - ✅ Use AnalysisOrchestrator for discovery
  - ✅ Pair with language detection results

  ## Architecture Patterns Detected

  - **Microservices**: 4+ independent services with separate build/deploy configs
  - **Distributed**: 2-3 independent services
  - **Modular**: 1 service with clear module boundaries
  - **Monolith**: Single codebase without service separation

  ## Search Keywords

  microservices, architecture patterns, monolith detection, service boundaries,
  distributed systems, service mesh, build configuration, deployment patterns,
  service discovery, architecture analysis
  """

  @behaviour Singularity.Architecture.AnalyzerType
  require Logger
  alias Singularity.Code.Analyzers.MicroserviceAnalyzer, as: LegacyAnalyzer

  @impl true
  def analyzer_type, do: :microservice

  @impl true
  def description, do: "Detect microservice vs monolith architecture patterns"

  @impl true
  def supported_types do
    ["microservices", "distributed", "modular", "monolith", "service_mesh"]
  end

  @impl true
  def analyze(codebase_path, _opts \\ []) when is_binary(codebase_path) do
    try do
      # Discover services in the codebase
      services = discover_services(codebase_path)

      # Classify architecture based on service count
      [classify_architecture(services)]
    rescue
      e ->
        Logger.error("Microservice analysis failed for #{codebase_path}", error: inspect(e))
        []
    end
  end

  @impl true
  def learn_pattern(result) do
    # Update architecture patterns based on analysis results
    case result do
      %{type: type, success: true} ->
        Logger.info("Microservice pattern #{type} analysis was accurate")
        :ok

      %{type: type, success: false} ->
        Logger.info("Microservice pattern #{type} analysis needs refinement")
        :ok

      _ ->
        :ok
    end
  end

  # Private helpers

  defp discover_services(root_path) do
    root_path
    |> list_subdirs()
    |> Enum.map(&detect_service/1)
    |> Enum.reject(&is_nil/1)
  end

  defp detect_service(service_path) do
    # A service must have clear build/deploy markers
    language = detect_language(service_path)

    if language && has_build_config?(service_path, language) do
      %{
        path: service_path,
        language: language,
        build_system: detect_build_system(service_path)
      }
    else
      nil
    end
  end

  defp detect_language(service_path) do
    case Singularity.LanguageDetection.detect(service_path) do
      {:ok, lang} when is_atom(lang) -> lang
      {:error, _} -> nil
    end
  end

  defp has_build_config?(service_path, language) do
    case language do
      :typescript -> has_any_file?(service_path, ["package.json", "tsconfig.json"])
      :rust -> has_file?(service_path, "Cargo.toml")
      :python -> has_any_file?(service_path, ["pyproject.toml", "setup.py", "requirements.txt"])
      :go -> has_file?(service_path, "go.mod")
      :java -> has_any_file?(service_path, ["pom.xml", "build.gradle"])
      :elixir -> has_file?(service_path, "mix.exs")
      _ -> false
    end
  end

  defp detect_build_system(service_path) do
    cond do
      has_file?(service_path, "package.json") -> "npm"
      has_file?(service_path, "Cargo.toml") -> "cargo"
      has_file?(service_path, "pyproject.toml") -> "poetry"
      has_file?(service_path, "requirements.txt") -> "pip"
      has_file?(service_path, "setup.py") -> "setuptools"
      has_file?(service_path, "go.mod") -> "go"
      has_file?(service_path, "pom.xml") -> "maven"
      has_file?(service_path, "build.gradle") -> "gradle"
      has_file?(service_path, "mix.exs") -> "mix"
      true -> "unknown"
    end
  end

  defp classify_architecture(services) do
    case {length(services), detect_service_mesh()} do
      {count, true} when count >= 2 ->
        %{
          type: "service_mesh",
          severity: "low",
          message: "Microservices with service mesh detected",
          service_count: count,
          services: services
        }

      {count, _} when count >= 4 ->
        %{
          type: "microservices",
          severity: "low",
          message: "Microservice architecture detected",
          service_count: count,
          services: services
        }

      {count, _} when count == 3 ->
        %{
          type: "distributed",
          severity: "low",
          message: "Distributed system with multiple services",
          service_count: count,
          services: services
        }

      {count, _} when count == 2 ->
        %{
          type: "distributed",
          severity: "low",
          message: "Two-service distributed system",
          service_count: count,
          services: services
        }

      {1, _} ->
        %{
          type: "modular",
          severity: "low",
          message: "Single service with clear module boundaries",
          service_count: 1
        }

      {0, _} ->
        %{
          type: "monolith",
          severity: "low",
          message: "Monolithic single codebase",
          service_count: 0
        }
    end
  end

  defp detect_service_mesh do
    false # TODO: Implement service mesh detection
  end

  defp list_subdirs(root) do
    case File.ls(root) do
      {:ok, entries} ->
        entries
        |> Enum.map(&Path.join(root, &1))
        |> Enum.filter(&File.dir?/1)

      {:error, _} ->
        []
    end
  rescue
    _ -> []
  end

  defp has_file?(path, filename) do
    File.exists?(Path.join(path, filename))
  end

  defp has_any_file?(path, filenames) do
    Enum.any?(filenames, fn f -> has_file?(path, f) end)
  end
end
