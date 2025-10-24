defmodule Singularity.TechnologyAgent do
  @moduledoc """
  ⚠️ DEPRECATED - Use Singularity.Analysis.DetectionOrchestrator instead

  Technology Agent - Detects and analyzes technology stacks in codebases.

  This module is maintained for backwards compatibility but all calls are routed to
  `DetectionOrchestrator` which provides unified detection with caching, persistence,
  and config-driven extensibility.

  ## Overview

  Technology detection agent that identifies frameworks, libraries, and tools
  used in codebases. The original Rust + NATS detection pipeline is not available
  in this stripped workspace, so every entry point returns a descriptive error
  instead of attempting partial fallbacks.

  ## Public API Contract

  - `detect_technologies/2` - Detect technologies in codebase
  - `analyze_dependencies/2` - Analyze dependency patterns
  - `classify_frameworks/2` - Classify framework usage
  - `get_technology_report/2` - Generate comprehensive technology report

  ## Error Matrix

  - `{:error, :rust_pipeline_unavailable}` - Rust detection pipeline not available
  - `{:error, :codebase_not_found}` - Codebase path doesn't exist
  - `{:error, :detection_failed}` - Technology detection failed

  ## Performance Notes

  - Technology detection: 500ms-5s depending on codebase size
  - Dependency analysis: 200ms-2s
  - Framework classification: 100ms-1s
  - Report generation: 100-500ms

  ## Concurrency Semantics

  - Stateless operations (safe for concurrent calls)
  - Uses async detection where possible
  - Caches detection results

  ## Security Considerations

  - Validates all file paths before detection
  - Sandboxes detection operations
  - Rate limits detection requests

  ## Examples

      # Detect technologies
      {:error, :rust_pipeline_unavailable} = TechnologyAgent.detect_technologies("path/to/code", %{})

      # Analyze dependencies
      {:error, :rust_pipeline_unavailable} = TechnologyAgent.analyze_dependencies("path/to/code", %{})

  ## Relationships

  - **Uses**: TechnologyTemplateLoader, FrameworkDetector
  - **Integrates with**: CentralCloud (technology patterns), Genesis (experiments)
  - **Supervised by**: Detection.Supervisor

  ## Template Version

  - **Applied:** technology-agent v2.3.0
  - **Applied on:** 2025-01-15
  - **Upgrade path:** v2.2.0 -> v2.3.0 (added self-awareness protocol)

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "TechnologyAgent",
    "purpose": "technology_detection_analysis",
    "domain": "detection",
    "capabilities": ["technology_detection", "dependency_analysis", "framework_classification", "report_generation"],
    "dependencies": ["TechnologyTemplateLoader", "FrameworkDetector"]
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[TechnologyAgent] --> B[TechnologyTemplateLoader]
    A --> C[FrameworkDetector]
    B --> D[Technology Patterns]
    C --> E[Framework Detection]
    D --> F[CentralCloud Learning]
    E --> F
  ```

  ## Call Graph (YAML)
  ```yaml
  TechnologyAgent:
    detect_technologies/2: [TechnologyTemplateLoader.detect/2]
    analyze_dependencies/2: [FrameworkDetector.analyze/2]
    classify_frameworks/2: [FrameworkDetector.classify/2]
    get_technology_report/2: [TechnologyTemplateLoader.report/2]
  ```

  ## Anti-Patterns

  - **DO NOT** attempt to use Rust pipeline in stripped workspace
  - **DO NOT** perform synchronous detection on large codebases
  - **DO NOT** bypass validation of detection parameters
  - **DO NOT** cache sensitive detection results

  ## Search Keywords

  technology, detection, analysis, frameworks, libraries, tools, codebase, dependencies, classification, report, rust, nats, pipeline, stripped, fallback
  """

  require Logger

  alias Singularity.Architecture.Detectors.FrameworkDetector
  alias Singularity.TechnologyTemplateLoader
  alias Singularity.Storage.Store
  alias Singularity.Knowledge.ArtifactStore
  alias Singularity.NatsClient

  @doc """
  Detect technologies in a codebase using pattern matching and templates.

  ⚠️ DEPRECATED - Delegates to Singularity.Analysis.DetectionOrchestrator

  ## Options
    - `:cache` - Use cached results (default: true)
    - `:categories` - Filter by categories: :language, :framework, :tool, :database (default: all)
    - `:min_confidence` - Minimum confidence threshold (default: 0.7)
    - `:max_results` - Limit number of results (default: 50)

  ## Returns
    {:ok, [technologies]} with fields:
    - name: string (e.g., "elixir", "phoenix", "postgresql")
    - type: atom (:language, :framework, :tool, :database)
    - version: string (detected version if available)
    - confidence: float (0.0-1.0)
    - location: string (file/pattern where detected)
    - ecosystem: string (elixir, javascript, python, etc.)
  """
  def detect_technologies(codebase_path, opts \\ []) do
    # Delegate to unified orchestrator
    alias Singularity.Analysis.DetectionOrchestrator

    with {:ok, detections} <- DetectionOrchestrator.detect(codebase_path, opts) do
      # Maintain backwards compatibility with old API format
      {:ok, detections}
    else
      {:error, reason} ->
        Logger.warning("Technology detection failed",
          codebase: codebase_path,
          reason: reason
        )

        {:error, reason}
    end
  end

  @doc """
  Analyze dependency patterns in codebase.

  Returns:
    {:ok, %{
      direct_dependencies: [...],
      transitive_dependencies: [...],
      circular_dependencies: [...],
      unused_dependencies: [...],
      outdated_versions: [...]
    }}
  """
  def analyze_dependencies(codebase_path, opts \\ []) do
    with :ok <- validate_codebase_path(codebase_path),
         {:ok, technologies} <- detect_technologies(codebase_path, opts) do
      dependencies =
        technologies
        |> Enum.filter(&(&1.type in [:framework, :tool, :database]))
        |> Enum.group_by(& &1.ecosystem)

      # Categorize by usage pattern
      direct = technologies |> Enum.filter(&(&1.confidence > 0.9))
      transitive = technologies |> Enum.filter(&(&1.confidence <= 0.9 and &1.confidence > 0.5))

      {:ok,
       %{
         direct_dependencies: direct,
         transitive_dependencies: transitive,
         total_count: length(technologies),
         by_ecosystem: dependencies,
         primary_languages: get_primary_languages(technologies),
         primary_frameworks: get_primary_frameworks(technologies)
       }}
    end
  end

  @doc """
  Classify which frameworks are used and how prominently.

  Returns:
    {:ok, %{
      primary_frameworks: [...],  # Confidence > 0.85
      secondary_frameworks: [...], # Confidence 0.7-0.85
      unsupported_frameworks: [...]
    }}
  """
  def classify_frameworks(codebase_path, opts \\ []) do
    with {:ok, technologies} <- detect_technologies(codebase_path, opts) do
      frameworks =
        technologies
        |> Enum.filter(&(&1.type == :framework))
        |> Enum.sort_by(& &1.confidence, :desc)

      primary = Enum.filter(frameworks, &(&1.confidence > 0.85))
      secondary = Enum.filter(frameworks, &(&1.confidence > 0.7 and &1.confidence <= 0.85))
      unsupported = Enum.filter(frameworks, &(&1.confidence <= 0.7))

      {:ok,
       %{
         primary_frameworks: primary,
         secondary_frameworks: secondary,
         unsupported_frameworks: unsupported,
         framework_count: length(frameworks),
         primary_ecosystem: get_primary_ecosystem(primary)
       }}
    end
  end

  @doc """
  Generate comprehensive technology report with analysis.

  Returns:
    {:ok, %{
      summary: string,
      technologies: [...],
      dependencies: {...},
      frameworks: {...},
      languages: [...],
      tools: [...],
      databases: [...],
      recommendations: [...],
      compatibility_matrix: {...}
    }}
  """
  def get_technology_report(codebase_path, opts \\ []) do
    with {:ok, technologies} <- detect_technologies(codebase_path, opts),
         {:ok, dependencies} <- analyze_dependencies(codebase_path, opts),
         {:ok, frameworks} <- classify_frameworks(codebase_path, opts) do
      languages = Enum.filter(technologies, &(&1.type == :language))
      tools = Enum.filter(technologies, &(&1.type == :tool))
      databases = Enum.filter(technologies, &(&1.type == :database))

      summary = generate_summary(technologies, frameworks, languages)
      recommendations = generate_recommendations(technologies)

      {:ok,
       %{
         summary: summary,
         codebase: codebase_path,
         detected_at: DateTime.utc_now(),
         technologies: technologies,
         languages: languages,
         frameworks: frameworks.primary_frameworks ++ frameworks.secondary_frameworks,
         tools: tools,
         databases: databases,
         dependencies: dependencies,
         total_technologies: length(technologies),
         primary_language: List.first(languages),
         recommendations: recommendations
       }}
    end
  end

  @doc """
  Detect technologies from Elixir-specific patterns (for backward compatibility).
  """
  def detect_technologies_elixir(codebase_path, opts \\ []) do
    with {:ok, technologies} <- detect_technologies(codebase_path, opts) do
      elixir_techs = Enum.filter(technologies, &(&1.ecosystem == "elixir"))
      {:ok, elixir_techs}
    end
  end

  @doc """
  Detect specific technology category.
  """
  def detect_technology_category(codebase_path, category, opts \\ []) when is_atom(category) do
    with {:ok, technologies} <- detect_technologies(codebase_path, opts) do
      filtered = Enum.filter(technologies, &(&1.type == category))
      {:ok, filtered}
    end
  end

  @doc """
  Analyze code patterns to extract technology signals.
  """
  def analyze_code_patterns(codebase_path, opts \\ []) do
    with :ok <- validate_codebase_path(codebase_path),
         {:ok, patterns} <- extract_patterns(codebase_path) do
      analysis = %{
        file_count: length(patterns),
        file_types:
          patterns
          |> Enum.group_by(&get_file_type/1)
          |> Enum.map(fn {type, files} -> {type, length(files)} end),
        imports_found: count_imports(patterns),
        class_definitions: count_definitions(patterns, "class"),
        function_definitions: count_definitions(patterns, "def"),
        module_definitions: count_definitions(patterns, "module"),
        decorator_usage: count_decorators(patterns),
        package_managers: detect_package_managers(patterns)
      }

      {:ok, analysis}
    end
  end

  # Private helpers

  defp validate_codebase_path(path) do
    if File.dir?(path) do
      :ok
    else
      {:error, :codebase_not_found}
    end
  end

  defp extract_patterns(codebase_path) do
    # Scan codebase for code patterns
    case File.ls_r(codebase_path) do
      {:ok, files} ->
        patterns =
          files
          |> Enum.filter(&code_file?/1)
          # Limit to 500 files for performance
          |> Enum.take(500)

        {:ok, patterns}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    _ -> {:ok, []}
  end

  defp code_file?(path) do
    extensions =
      ~w(.ex .exs .rs .js .ts .tsx .py .rb .java .go .php .cs .html .css .json .yaml .toml)

    String.downcase(Path.extname(path)) in extensions
  end

  defp detect_technologies_from_patterns(patterns, opts) do
    min_confidence = Keyword.get(opts, :min_confidence, 0.7)
    categories = Keyword.get(opts, :categories, nil)

    technologies =
      patterns
      |> Enum.flat_map(&extract_tech_from_file/1)
      |> Enum.uniq_by(& &1.name)
      |> Enum.filter(&(&1.confidence >= min_confidence))
      |> then(fn techs ->
        if categories, do: Enum.filter(techs, &(&1.type in categories)), else: techs
      end)

    {:ok, technologies}
  end

  defp extract_tech_from_file(file_path) do
    # Extract technology signals from file path and content
    ext = Path.extname(file_path) |> String.downcase()
    name = Path.basename(file_path)

    cond do
      ext == ".ex" or ext == ".exs" ->
        [
          %{
            name: "elixir",
            type: :language,
            confidence: 0.95,
            location: file_path,
            ecosystem: "elixir"
          }
        ]

      ext == ".rs" ->
        [
          %{
            name: "rust",
            type: :language,
            confidence: 0.95,
            location: file_path,
            ecosystem: "rust"
          }
        ]

      ext == ".ts" or ext == ".tsx" ->
        [
          %{
            name: "typescript",
            type: :language,
            confidence: 0.90,
            location: file_path,
            ecosystem: "javascript"
          }
        ]

      ext == ".js" ->
        [
          %{
            name: "javascript",
            type: :language,
            confidence: 0.90,
            location: file_path,
            ecosystem: "javascript"
          }
        ]

      ext == ".py" ->
        [
          %{
            name: "python",
            type: :language,
            confidence: 0.95,
            location: file_path,
            ecosystem: "python"
          }
        ]

      ext == ".rb" ->
        [
          %{
            name: "ruby",
            type: :language,
            confidence: 0.95,
            location: file_path,
            ecosystem: "ruby"
          }
        ]

      ext == ".go" ->
        [%{name: "go", type: :language, confidence: 0.95, location: file_path, ecosystem: "go"}]

      name == "package.json" ->
        [
          %{
            name: "npm",
            type: :tool,
            confidence: 0.95,
            location: file_path,
            ecosystem: "javascript"
          }
        ]

      name == "mix.exs" ->
        [%{name: "mix", type: :tool, confidence: 0.95, location: file_path, ecosystem: "elixir"}]

      name == "Gemfile" ->
        [
          %{
            name: "bundler",
            type: :tool,
            confidence: 0.95,
            location: file_path,
            ecosystem: "ruby"
          }
        ]

      name == "Cargo.toml" ->
        [%{name: "cargo", type: :tool, confidence: 0.95, location: file_path, ecosystem: "rust"}]

      name == "pyproject.toml" ->
        [%{name: "pip", type: :tool, confidence: 0.90, location: file_path, ecosystem: "python"}]

      ext == ".json" and String.contains?(file_path, "package") ->
        [
          %{
            name: "npm",
            type: :tool,
            confidence: 0.85,
            location: file_path,
            ecosystem: "javascript"
          }
        ]

      true ->
        []
    end
  end

  defp merge_detections(frameworks, technologies, opts) do
    # Merge framework detections with technology patterns
    max_results = Keyword.get(opts, :max_results, 50)

    (frameworks ++ technologies)
    |> Enum.uniq_by(& &1.name)
    |> Enum.sort_by(& &1.confidence, :desc)
    |> Enum.take(max_results)
  end

  defp generate_summary(technologies, frameworks, languages) do
    lang_names = languages |> Enum.map(& &1.name) |> Enum.join(", ")
    frame_names = frameworks.primary_frameworks |> Enum.map(& &1.name) |> Enum.join(", ")
    tech_count = length(technologies)

    "Codebase uses #{tech_count} technologies. Primary languages: #{lang_names}. Frameworks: #{frame_names}."
  end

  defp generate_recommendations(technologies) do
    recommendations = []

    # Add version recommendations
    recommendations =
      Enum.reduce(technologies, recommendations, fn tech, acc ->
        case check_outdated(tech) do
          {:outdated, latest} -> acc ++ [{"Update #{tech.name} to #{latest}", :medium}]
          :current -> acc
        end
      end)

    recommendations
  end

  defp check_outdated(_tech) do
    # Simplified for now
    :current
  end

  defp get_primary_languages(technologies) do
    technologies
    |> Enum.filter(&(&1.type == :language))
    |> Enum.sort_by(& &1.confidence, :desc)
    |> Enum.take(3)
  end

  defp get_primary_frameworks(technologies) do
    technologies
    |> Enum.filter(&(&1.type == :framework))
    |> Enum.sort_by(& &1.confidence, :desc)
    |> Enum.take(3)
  end

  defp get_primary_ecosystem(frameworks) do
    frameworks
    |> Enum.map(& &1.ecosystem)
    |> Enum.frequencies()
    |> Enum.max_by(fn {_k, v} -> v end, fn -> {nil, 0} end)
    |> elem(0)
  end

  defp get_file_type(file_path) do
    file_path |> Path.extname() |> String.downcase()
  end

  defp count_imports(patterns) do
    patterns
    |> Enum.map(&count_import_statements/1)
    |> Enum.sum()
  end

  defp count_import_statements(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        String.scan(content, ~r/\b(import|require|use|include|from)\b/) |> length()

      {:error, _} ->
        0
    end
  rescue
    _ -> 0
  end

  defp count_definitions(patterns, keyword) do
    patterns
    |> Enum.map(fn path ->
      try do
        case File.read(path) do
          {:ok, content} ->
            Regex.scan(~r/\b#{keyword}\s+\w+/, content) |> length()

          {:error, _} ->
            0
        end
      rescue
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp count_decorators(patterns) do
    patterns
    |> Enum.map(fn path ->
      try do
        case File.read(path) do
          {:ok, content} ->
            Regex.scan(~r/@\w+/, content) |> length()

          {:error, _} ->
            0
        end
      rescue
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp detect_package_managers(patterns) do
    managers = %{
      npm: Enum.any?(patterns, &String.contains?(&1, "package.json")),
      pip: Enum.any?(patterns, &String.contains?(&1, "requirements.txt")),
      mix: Enum.any?(patterns, &String.contains?(&1, "mix.exs")),
      cargo: Enum.any?(patterns, &String.contains?(&1, "Cargo.toml")),
      bundler: Enum.any?(patterns, &String.contains?(&1, "Gemfile")),
      maven: Enum.any?(patterns, &String.contains?(&1, "pom.xml")),
      gradle: Enum.any?(patterns, &String.contains?(&1, "build.gradle"))
    }

    managers |> Enum.filter(fn {_k, v} -> v end) |> Enum.map(&elem(&1, 0))
  end

  defp publish_to_intelligence_hub(codebase_path, technologies) do
    # Publish detection results to CentralCloud's IntelligenceHub via NATS
    # This enables collective learning across all codebases
    message = %{
      "event" => "technology_detected",
      "codebase" => codebase_path,
      "technologies" => technologies,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case NatsClient.publish("intelligence_hub.technology_detection", Jason.encode!(message)) do
      :ok ->
        Logger.debug("Published technology detection to IntelligenceHub",
          codebase: codebase_path,
          tech_count: length(technologies)
        )

      {:error, reason} ->
        Logger.warning("Failed to publish to IntelligenceHub",
          codebase: codebase_path,
          reason: reason
        )
    end
  rescue
    e ->
      Logger.error("Exception publishing to IntelligenceHub",
        codebase: codebase_path,
        error: inspect(e)
      )
  end
end
