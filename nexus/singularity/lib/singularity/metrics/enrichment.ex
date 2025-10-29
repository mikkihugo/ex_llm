defmodule Singularity.Metrics.Enrichment do
  @moduledoc """
  Enrichment Data - Query PostgreSQL for pattern matching and historical context

  Enriches raw metric calculations with database knowledge:
  - Similar code patterns from knowledge base
  - Historical metric trends
  - Code relationships and dependencies
  - Refactoring patterns and success rates
  - Test coverage data

  This bridges the gap between Rust NIF calculations and PostgreSQL knowledge base.

  ## Architecture

      Rust NIF Calculation (fast, language-aware)
              ↓
      Enrichment.query() (PostgreSQL context)
              ↓
      Enriched Metrics (contextualized insights)
  """

  import Ecto.Query
  require Logger

  @doc """
  Get similar code patterns from knowledge base

  Uses pgvector semantic search to find patterns similar to the current code.

  ## Parameters
    - code: binary - source code to analyze
    - language: atom - programming language
    - limit: integer (default: 10) - max patterns to return

  ## Returns
    - list of %{id, name, complexity_score, similarity_score, usage_frequency, ...}

  ## Example
      iex> Enrichment.find_similar_patterns("let x: i32 = 42;", :rust, limit: 5)
      [
        %{
          id: "pattern_123",
          name: "Type-annotated variable",
          complexity_score: 1.0,
          similarity_score: 0.92,
          usage_frequency: 1200,
          success_rate: 0.95
        }
      ]
  """
  def find_similar_patterns(code, language, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    try do
      # Query knowledge artifacts with embeddings
      # This would use pgvector similarity search
      Singularity.Knowledge.ArtifactStore.search(
        code,
        artifact_type: "code_pattern",
        language: Atom.to_string(language),
        top_k: limit
      )
      |> case do
        {:ok, patterns} ->
          Enum.map(patterns, fn pattern ->
            %{
              id: pattern.id,
              name: pattern.metadata["name"],
              complexity_score: pattern.metadata["complexity_score"] || 0.5,
              similarity_score: pattern.similarity || 0.0,
              usage_frequency: pattern.metadata["usage_frequency"] || 0,
              success_rate: pattern.metadata["success_rate"] || 0.5
            }
          end)

        {:error, reason} ->
          Logger.warning("Failed to find similar patterns: #{inspect(reason)}")
          []
      end
    rescue
      e ->
        Logger.error("Error in find_similar_patterns: #{inspect(e)}")
        []
    end
  end

  @doc """
  Get historical metric trends for a file

  Shows how metrics have changed over time (via git commits).

  ## Parameters
    - file_path: string - path to the file
    - language: atom - programming language
    - limit: integer (default: 20) - max history entries to return

  ## Returns
    - list of %{timestamp, type_safety, coupling, error_handling, complexity, ...}
  """
  def get_metric_history(file_path, language, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)

    try do
      Singularity.Metrics.CodeMetrics
      |> where(file_path: ^file_path, language: ^Atom.to_string(language))
      |> order_by(desc: :analysis_timestamp)
      |> limit(^limit)
      |> Singularity.Repo.all()
      |> Enum.map(fn metrics ->
        %{
          timestamp: metrics.analysis_timestamp,
          type_safety: metrics.type_safety_score,
          coupling: metrics.coupling_score,
          error_handling: metrics.error_handling_score,
          complexity: metrics.cyclomatic_complexity,
          quality: metrics.overall_quality_score,
          git_commit: metrics.git_commit
        }
      end)
    rescue
      e ->
        Logger.error("Error fetching metric history: #{inspect(e)}")
        []
    end
  end

  @doc """
  Get refactoring patterns and success rates for a language

  Shows what refactorings have worked well in the past.

  ## Parameters
    - language: atom - programming language
    - limit: integer (default: 10) - max patterns to return

  ## Returns
    - list of %{pattern_name, success_rate, avg_quality_improvement, example_files, ...}
  """
  def get_refactoring_patterns(language, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    try do
      # Query knowledge artifacts for refactoring patterns
      Singularity.Knowledge.ArtifactStore.query_jsonb(
        artifact_type: "refactoring_pattern",
        filter: %{"language" => Atom.to_string(language)}
      )
      |> case do
        {:ok, patterns} ->
          Enum.take(patterns, limit)
          |> Enum.map(fn pattern ->
            %{
              name: pattern.metadata["name"],
              description: pattern.metadata["description"],
              success_rate: pattern.metadata["success_rate"] || 0.5,
              avg_quality_improvement: pattern.metadata["avg_improvement"] || 5.0,
              examples_count: pattern.metadata["examples_count"] || 0
            }
          end)

        {:error, _} ->
          []
      end
    rescue
      e ->
        Logger.error("Error fetching refactoring patterns: #{inspect(e)}")
        []
    end
  end

  @doc """
  Get language-specific quality benchmarks

  Returns average quality metrics for the language to contextualize scores.

  ## Parameters
    - language: atom - programming language

  ## Returns
    - %{
        avg_type_safety: float,
        avg_coupling: float,
        avg_error_handling: float,
        avg_quality: float,
        file_count: integer,
        percentile_type_safety: map,
        percentile_coupling: map
      }
  """
  def get_language_benchmarks(language) do
    language_str = Atom.to_string(language)

    try do
      # Get average metrics
      avg_metrics = Singularity.Metrics.CodeMetrics.average_by_language(language_str)

      # Get percentile data (top performers)
      top_performers =
        Singularity.Metrics.CodeMetrics
        |> where(language: ^language_str)
        |> order_by(desc: :overall_quality_score)
        |> limit(10)
        |> Singularity.Repo.all()

      %{
        avg_type_safety: avg_metrics.avg_type_safety || 0.0,
        avg_coupling: avg_metrics.avg_coupling || 0.0,
        avg_error_handling: avg_metrics.avg_error_handling || 0.0,
        avg_quality: avg_metrics.avg_quality || 0.0,
        file_count: avg_metrics.file_count || 0,
        best_type_safety: top_performers |> Enum.map(& &1.type_safety_score) |> Enum.max(),
        best_coupling: top_performers |> Enum.map(& &1.coupling_score) |> Enum.max(),
        best_error_handling: top_performers |> Enum.map(& &1.error_handling_score) |> Enum.max()
      }
    rescue
      e ->
        Logger.error("Error fetching language benchmarks: #{inspect(e)}")
        %{}
    end
  end

  @doc """
  Find code relationships (imports, dependencies)

  Gets the dependency graph for a file to understand coupling context.

  ## Parameters
    - file_path: string - path to the file

  ## Returns
    - %{
        imports_from: list of {module, count},
        imported_by: list of {module, count},
        external_dependencies: list of strings
      }
  """
  def get_code_relationships(file_path) do
    try do
      # This would query a dependency graph stored in PostgreSQL
      # For now, returning the structure
      %{
        imports_from: [],
        imported_by: [],
        external_dependencies: []
      }
    rescue
      e ->
        Logger.error("Error fetching code relationships: #{inspect(e)}")
        %{}
    end
  end

  @doc """
  Build enrichment context for metrics

  Combines all enrichment data into a single context map.

  ## Parameters
    - file_path: string
    - language: atom
    - code: binary (optional - for pattern matching)

  ## Returns
    - %{
        similar_patterns: list,
        history: list,
        refactoring_patterns: list,
        benchmarks: map,
        relationships: map
      }
  """
  def build_context(file_path, language, code \\ nil) do
    %{
      similar_patterns: (code && find_similar_patterns(code, language)) || [],
      history: get_metric_history(file_path, language),
      refactoring_patterns: get_refactoring_patterns(language),
      benchmarks: get_language_benchmarks(language),
      relationships: get_code_relationships(file_path)
    }
  end

  @doc """
  Contextualize a raw metric score with benchmarks

  Returns whether a score is good/average/poor compared to language benchmarks.

  ## Parameters
    - metric_type: atom (:type_safety, :coupling, :error_handling)
    - score: float (0-100)
    - language: atom
    - benchmarks: map (optional - fetches if not provided)

  ## Returns
    - %{score: float, percentile: integer, status: atom}
      - status: :excellent (80+), :good (60-79), :average (40-59), :poor (20-39), :critical (<20)
  """
  def contextualize_score(metric_type, score, language, benchmarks \\ nil) do
    benchmarks = benchmarks || get_language_benchmarks(language)

    avg_score =
      case metric_type do
        :type_safety -> benchmarks[:avg_type_safety] || 50.0
        # Invert: lower is better
        :coupling -> 100.0 - (benchmarks[:avg_coupling] || 50.0)
        :error_handling -> benchmarks[:avg_error_handling] || 50.0
        _ -> 50.0
      end

    # Simple percentile: compare to average
    percentile =
      if avg_score > 0 do
        min(round(score / avg_score * 100), 100)
      else
        50
      end

    status =
      cond do
        score >= 80 -> :excellent
        score >= 60 -> :good
        score >= 40 -> :average
        score >= 20 -> :poor
        true -> :critical
      end

    %{score: score, percentile: percentile, status: status, benchmark: avg_score}
  end

  @doc """
  Generate enrichment insights (anomalies, improvements, etc.)

  Analyzes metrics and enrichment data to generate actionable insights.
  """
  def generate_insights(metrics, enrichment_context) do
    insights = []

    # Check for type safety anomalies
    insights =
      if metrics.type_safety_score && metrics.type_safety_score < 40 do
        insights ++
          [
            %{
              type: :type_safety_anomaly,
              severity: :high,
              message: "Type safety score is critically low. Consider adding type annotations.",
              recommendation:
                "Review #{Enum.count(enrichment_context.similar_patterns)} similar patterns for examples"
            }
          ]
      else
        insights
      end

    # Check for coupling issues
    insights =
      if metrics.coupling_score && metrics.coupling_score > 75 do
        insights ++
          [
            %{
              type: :high_coupling,
              severity: :medium,
              message: "Module has high coupling. Consider breaking into smaller modules.",
              recommendation:
                "Review refactoring patterns: #{Enum.map(enrichment_context.refactoring_patterns, & &1.name) |> Enum.join(", ")}"
            }
          ]
      else
        insights
      end

    insights
  end
end
