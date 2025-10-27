defmodule Singularity.Pipeline.Context do
  @moduledoc """
  Unified Context Gathering Layer - Pre-Generation Phase

  Consolidates all pre-generation context gathering into a single, clean interface.

  This module serves as the integration layer for Phase 1 (Context Gathering) of the
  self-evolving pipeline, coordinating:

  - **Feature Extraction** - Extract structural features (dependencies, patterns, complexity)
  - **Pattern Matching** - Identify framework/technology patterns in codebase
  - **Risk Analysis** - Assess potential failure points and complexity
  - **Duplicate Detection** - Find similar implementations to avoid re-implementing
  - **Framework/Technology Detection** - Identify frameworks, libraries, and technologies in use

  ## Architecture

  This layer orchestrates multiple specialized analyzers and detectors:
  - FrameworkDetector - detects frameworks (Phoenix, Django, Rails, etc.)
  - TechnologyDetector - detects technologies (PostgreSQL, Redis, etc.)
  - PatternDetector - detects architectural patterns
  - CodePatternExtractor - extracts code patterns
  - DuplicateDetector - finds similar code
  - QualityAnalyzer - analyzes code quality

  ## Single API

  ```
  {:ok, context} = Singularity.Pipeline.Context.gather(story, _opts)
  ```

  Returns a unified context map with:
  - `:frameworks` - Detected frameworks
  - `:technologies` - Detected technologies
  - `:patterns` - Architectural patterns
  - `:duplicates` - Similar implementations
  - `:quality_issues` - Code quality concerns
  - `:dependencies` - Codebase dependencies
  - `:complexity` - Estimated complexity

  ## Usage in Pipeline

  Used in Phase 1 of the self-evolving pipeline:

  ```elixir
  # Gather context for constraint generation
  {:ok, context} = Singularity.Pipeline.Context.gather(story)

  # Generate constrained plan
  {:ok, plan} = Singularity.Pipeline.PlanGenerator.generate(story, context)

  # Validate plan
  {:ok, validation} = Singularity.Pipeline.Validator.validate(plan, context)
  ```
  """

  require Logger

  alias Singularity.Architecture.Detectors.FrameworkDetector
  alias Singularity.Architecture.Detectors.TechnologyDetector
  alias Singularity.Architecture.PatternDetector
  alias Singularity.Storage.Code.Patterns.CodePatternExtractor
  alias Singularity.DeduplicationEngine
  alias Singularity.Architecture.Analyzers.QualityAnalyzer

  @type story :: String.t() | map()
  @type gather_opts :: keyword()
  @type context :: map()

  @doc """
  Gather enriched context for a story before plan generation.

  ## Parameters
  - `story` - Story description or goal
  - `_opts` - Options for context gathering:
    - `:codebase_path` - Path to codebase (default: current)
    - `:include_patterns` - Include pattern detection (default: true)
    - `:include_duplicates` - Include duplicate analysis (default: true)
    - `:include_quality` - Include quality analysis (default: true)
    - `:timeout` - Timeout in ms (default: 30000)

  ## Returns
  - `{:ok, context}` - Unified context map
  - `{:error, reason}` - Error details

  ## Context Structure
  ```
  %{
    story: "original story",
    frameworks: [%{name: "Phoenix", version: "1.7.0"}],
    technologies: [%{name: "PostgreSQL", version: "15.0"}],
    patterns: [%{type: "MVC", confidence: 0.95}],
    duplicates: [%{path: "lib/user_handler.ex", similarity: 0.89}],
    quality_issues: [%{type: "unused_variable", severity: "warning"}],
    dependencies: [%{name: "ecto", version: "3.10.0"}],
    complexity: "medium"
  }
  ```
  """
  @spec gather(story, gather_opts) :: {:ok, context} | {:error, term()}
  def gather(story, _opts \\ []) do
    codebase_path = Keyword.get(opts, :codebase_path, ".")
    timeout_ms = Keyword.get(opts, :timeout, 30000)

    Logger.info("Pipeline.Context: Gathering context",
      story_length: story_length(story),
      codebase_path: codebase_path
    )

    start_time = System.monotonic_time(:millisecond)

    try do
      context =
        %{
          story: story_to_string(story),
          gathered_at: DateTime.utc_now()
        }
        |> gather_frameworks(codebase_path)
        |> gather_technologies(codebase_path)
        |> gather_patterns(codebase_path, _opts)
        |> gather_duplicates(story, codebase_path, _opts)
        |> gather_quality_issues(codebase_path, _opts)
        |> gather_dependencies(codebase_path)
        |> estimate_complexity(story)

      duration_ms = System.monotonic_time(:millisecond) - start_time

      Logger.info("Pipeline.Context: Context gathered successfully",
        duration_ms: duration_ms,
        frameworks: context[:frameworks] |> Enum.count(),
        technologies: context[:technologies] |> Enum.count(),
        patterns: context[:patterns] |> Enum.count()
      )

      {:ok, context}
    rescue
      error ->
        Logger.error("Pipeline.Context: Error gathering context",
          error: inspect(error),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )

        {:error, error}
    end
  end

  # Helper Functions

  defp story_to_string(story) when is_binary(story), do: story
  defp story_to_string(story) when is_map(story), do: Map.get(story, :description, inspect(story))
  defp story_to_string(story), do: inspect(story)

  defp story_length(story) when is_binary(story), do: String.length(story)
  defp story_length(story), do: String.length(inspect(story))

  defp gather_frameworks(context, codebase_path) do
    case FrameworkDetector.detect(codebase_path) do
      {:ok, frameworks} when is_list(frameworks) ->
        Map.put(context, :frameworks, frameworks)

      _ ->
        Map.put(context, :frameworks, [])
    end
  rescue
    _ -> Map.put(context, :frameworks, [])
  end

  defp gather_technologies(context, codebase_path) do
    case TechnologyDetector.detect(codebase_path) do
      {:ok, technologies} when is_list(technologies) ->
        Map.put(context, :technologies, technologies)

      _ ->
        Map.put(context, :technologies, [])
    end
  rescue
    _ -> Map.put(context, :technologies, [])
  end

  defp gather_patterns(context, codebase_path, _opts) do
    include_patterns = Keyword.get(opts, :include_patterns, true)

    if include_patterns do
      case PatternDetector.detect(codebase_path) do
        {:ok, patterns} when is_list(patterns) ->
          Map.put(context, :patterns, patterns)

        _ ->
          Map.put(context, :patterns, [])
      end
    else
      Map.put(context, :patterns, [])
    end
  rescue
    _ -> Map.put(context, :patterns, [])
  end

  defp gather_duplicates(context, story, codebase_path, _opts) do
    include_duplicates = Keyword.get(opts, :include_duplicates, true)

    if include_duplicates do
      case DeduplicationEngine.find_similar(story_to_string(story), codebase_path) do
        {:ok, duplicates} when is_list(duplicates) ->
          Map.put(context, :duplicates, duplicates)

        _ ->
          Map.put(context, :duplicates, [])
      end
    else
      Map.put(context, :duplicates, [])
    end
  rescue
    _ -> Map.put(context, :duplicates, [])
  end

  defp gather_quality_issues(context, codebase_path, _opts) do
    include_quality = Keyword.get(opts, :include_quality, true)

    if include_quality do
      case QualityAnalyzer.analyze(codebase_path) do
        {:ok, issues} when is_list(issues) ->
          Map.put(context, :quality_issues, issues)

        _ ->
          Map.put(context, :quality_issues, [])
      end
    else
      Map.put(context, :quality_issues, [])
    end
  rescue
    _ -> Map.put(context, :quality_issues, [])
  end

  defp gather_dependencies(context, codebase_path) do
    case CodePatternExtractor.extract_dependencies(codebase_path) do
      {:ok, deps} when is_list(deps) ->
        Map.put(context, :dependencies, deps)

      _ ->
        Map.put(context, :dependencies, [])
    end
  rescue
    _ -> Map.put(context, :dependencies, [])
  end

  defp estimate_complexity(context, story) do
    # Estimate complexity based on story length and gathered context
    complexity =
      case context do
        %{technologies: techs, patterns: patterns} when length(techs) > 3 or length(patterns) > 2 ->
          "complex"

        %{technologies: techs} when length(techs) > 1 ->
          "medium"

        _ ->
          if String.length(story_to_string(story)) > 500 do
            "medium"
          else
            "simple"
          end
      end

    Map.put(context, :complexity, complexity)
  end
end
