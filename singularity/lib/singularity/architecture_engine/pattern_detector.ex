defmodule Singularity.Architecture.PatternDetector do
  @moduledoc """
  Generic Pattern Detector - Orchestrates all pattern detectors based on config.

  Automatically discovers and runs any enabled pattern detector (Framework, Technology,
  ServiceArchitecture, etc.). No hardcoding needed - purely config-driven.

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Architecture.PatternDetector",
    "purpose": "Config-driven orchestration of all pattern detectors",
    "layer": "domain_service",
    "status": "production"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      Path["Path to analyze"]
      Detector["PatternDetector.detect/2"]
      Config["Config: pattern_types"]

      Detector -->|loads| Config
      Config -->|enabled: true| Framework["FrameworkDetector"]
      Config -->|enabled: true| Technology["TechnologyDetector"]
      Config -->|enabled: true| Service["ServiceArchitectureDetector"]

      Framework -->|detect/2| DB1["PatternStore<br/>(framework)"]
      Technology -->|detect/2| DB2["PatternStore<br/>(technology)"]
      Service -->|detect/2| DB3["PatternStore<br/>(service_architecture)"]

      Path -->|routed to| Framework
      Path -->|routed to| Technology
      Path -->|routed to| Service
  ```

  ## Usage Examples

  ```elixir
  # Detect ALL enabled pattern types
  {:ok, results} = PatternDetector.detect("/path/to/project")
  # => %{
  #   framework: [%{name: "React", confidence: 0.95}, ...],
  #   technology: [%{name: "TypeScript", confidence: 0.92}, ...],
  #   service_architecture: [%{name: "microservices", confidence: 0.88}, ...]
  # }

  # Detect specific pattern types only
  {:ok, results} = PatternDetector.detect(
    "/path/to/project",
    pattern_types: [:framework, :technology]
  )
  # => %{
  #   framework: [...],
  #   technology: [...]
  # }

  # Detect with options
  {:ok, results} = PatternDetector.detect(
    "/path/to/project",
    pattern_types: [:framework],
    min_confidence: 0.85,
    limit: 5
  )

  # Learn from detection results
  :ok = PatternDetector.learn_pattern(:framework, detection_result)
  ```

  ## Configuration

  ```elixir
  # config/config.exs
  config :singularity, :pattern_types,
    framework: %{
      module: Singularity.Architecture.Detectors.FrameworkDetector,
      enabled: true,
      description: "Detect web frameworks, build tools, etc."
    },
    technology: %{
      module: Singularity.Architecture.Detectors.TechnologyDetector,
      enabled: true,
      description: "Detect programming languages and tech stack"
    },
    service_architecture: %{
      module: Singularity.Architecture.Detectors.ServiceArchitectureDetector,
      enabled: true,
      description: "Detect microservice vs monolith architecture"
    }
  ```

  ## Call Graph

  ```yaml
  calls_out:
    - module: "[Enabled Pattern Detectors]"
      function: "detect/2"
      purpose: "Detect patterns of specific type"
      critical: true

    - module: "[Enabled Pattern Detectors]"
      function: "learn_pattern/1"
      purpose: "Learn from detection results"
      critical: true

    - module: Singularity.Architecture.PatternType
      function: "load_enabled_detectors/0"
      purpose: "Load config-enabled detectors"
      critical: true

    - module: Logger
      function: "[info|error]/2"
      purpose: "Logging detection progress"
      critical: false

  called_by:
    - module: Singularity.Architecture.ArchitectureAnalyzer
      count: "1+"
      purpose: "Full codebase architecture analysis"

    - module: Singularity.CodebaseAnalyzer
      count: "1+"
      purpose: "Codebase initial scan"

    - module: "[Future detection integrations]"
      count: "*"
      purpose: "Any new pattern discovery workflows"
  ```

  ## Anti-Patterns (Prevents Duplicates)

  ### ❌ DO NOT create new hardcoded detector modules
  **Why:** Config-driven discovery already handles all pattern detectors.
  **Use instead:**
  ```elixir
  # ❌ WRONG - new hardcoded detector
  defmodule MyPatternDetector do
    def detect(path), do: # ...
  end

  # ✅ CORRECT - add to config
  config :singularity, :pattern_types,
    my_pattern: %{
      module: Singularity.Architecture.Detectors.MyPatternDetector,
      enabled: true,
      description: "Detect my patterns"
    }
  ```

  ### ❌ DO NOT call individual detectors directly
  **Why:** PatternDetector provides unified orchestration.
  **Use instead:**
  ```elixir
  # ❌ WRONG
  FrameworkDetector.detect(path)

  # ✅ CORRECT
  PatternDetector.detect(path, pattern_types: [:framework])
  ```

  ### ❌ DO NOT hardcode pattern type lists
  **Why:** Config enables dynamic pattern discovery.
  **Use instead:** Let PatternDetector load from config.

  ### Search Keywords

  pattern detector, framework detection, technology detection, architecture patterns,
  config driven detection, pattern orchestrator, service architecture, pattern discovery,
  parallel detection, pattern learning, pattern types
  """

  require Logger
  alias Singularity.Architecture.PatternType

  @doc """
  Detect patterns in the given path using all enabled detectors.

  ## Options

  - `:pattern_types` - List of pattern types to detect (default: all enabled)
  - `:min_confidence` - Minimum confidence threshold (default: 0.5)
  - `:limit` - Maximum patterns per type to return (default: unlimited)
  - `:sample` - Sample files instead of scanning all (default: false)

  ## Returns

  `{:ok, %{pattern_type => [patterns]}}` or `{:error, reason}`

  Example:
  ```
  {:ok, %{
    framework: [%{name: "React", ...}],
    technology: [%{name: "TypeScript", ...}],
    service_architecture: [...]
  }}
  ```
  """
  def detect(path, _opts \\ []) when is_binary(path) do
    try do
      # Load all enabled detectors from config
      enabled_detectors = PatternType.load_enabled_detectors()

      # Filter by requested pattern types if specified
      pattern_types = Keyword.get(opts, :pattern_types, nil)

      detectors_to_run =
        if pattern_types do
          Enum.filter(enabled_detectors, fn {type, _} -> type in pattern_types end)
        else
          enabled_detectors
        end

      # Run all detectors in parallel (independent operations)
      results =
        detectors_to_run
        |> Enum.map(fn {pattern_type, detector_config} ->
          Task.async(fn -> run_detector(pattern_type, detector_config, path, _opts) end)
        end)
        |> Enum.map(&Task.await/1)
        |> Enum.into(%{})

      Logger.info("Pattern detection complete",
        patterns_found: Enum.map(results, fn {type, patterns} -> {type, length(patterns)} end)
      )

      {:ok, results}
    rescue
      e ->
        Logger.error("Pattern detection failed", error: inspect(e))
        {:error, :detection_failed}
    end
  end

  @doc """
  Learn from a detection result for a specific pattern type.
  """
  def learn_pattern(pattern_type, detection_result) when is_atom(pattern_type) do
    case PatternType.get_detector_module(pattern_type) do
      {:ok, module} ->
        Logger.info("Learning pattern for #{pattern_type}")
        module.learn_pattern(detection_result)

      {:error, reason} ->
        Logger.error("Cannot learn pattern for #{pattern_type}", reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Get all configured pattern types and their status.
  """
  def get_pattern_types_info do
    PatternType.load_enabled_detectors()
    |> Enum.map(fn {type, config} ->
      description = PatternType.get_description(type)

      %{
        name: type,
        enabled: true,
        description: description,
        module: config[:module]
      }
    end)
  end

  # Private helpers

  defp run_detector(pattern_type, detector_config, path, _opts) do
    try do
      module = detector_config[:module]

      if module && Code.ensure_loaded?(module) do
        Logger.debug("Running #{pattern_type} detector at #{path}")
        patterns = module.detect(path, _opts)

        # Filter and limit results
        filtered =
          patterns
          |> filter_by_confidence(_opts)
          |> limit_results(_opts)

        Logger.debug("#{pattern_type} detector found #{length(filtered)} patterns")
        {pattern_type, filtered}
      else
        Logger.warning("Detector module not found for #{pattern_type}")
        {pattern_type, []}
      end
    rescue
      e ->
        Logger.error("Detector failed for #{pattern_type}",
          error: inspect(e),
          stacktrace: inspect(__STACKTRACE__)
        )

        {pattern_type, []}
    end
  end

  defp filter_by_confidence(patterns, _opts) do
    min_confidence = Keyword.get(opts, :min_confidence, 0.5)

    Enum.filter(patterns, fn pattern ->
      pattern[:confidence] || 1.0 >= min_confidence
    end)
  end

  defp limit_results(patterns, _opts) do
    case Keyword.get(opts, :limit) do
      nil -> patterns
      limit -> Enum.take(patterns, limit)
    end
  end
end
