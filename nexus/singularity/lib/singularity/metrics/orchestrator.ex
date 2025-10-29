defmodule Singularity.Metrics.Orchestrator do
  @moduledoc """
  Metrics Orchestrator - Unified interface for code metrics analysis

  Orchestrates the complete metrics pipeline:
  1. Language detection
  2. NIF metric calculation (Rust)
  3. PostgreSQL enrichment (patterns, history, benchmarks)
  4. Storage and analysis
  5. Insight generation

  ## Architecture

  ```
  Code File
      ↓
  Language Detection
      ↓
  Rust NIF Metrics (Type Safety, Coupling, Error Handling)
      ↓
  PostgreSQL Enrichment (patterns, history, benchmarks)
      ↓
  Store Results → CodeMetrics table
      ↓
  Generate Insights
      ↓
  Return contextualized metrics
  ```

  ## Example

      iex> Singularity.Metrics.Orchestrator.analyze_file("lib/my_module.ex")
      {:ok, %{
        file_path: "lib/my_module.ex",
        language: :elixir,
        metrics: %{
          type_safety: 85.5,
          coupling: 72.0,
          error_handling: 90.0,
          overall_quality: 82.5
        },
        enrichment: %{
          similar_patterns: [...],
          history: [...],
          benchmarks: [...]
        },
        insights: [...]
      }}
  """

  require Logger
  import Ecto.Query

  @doc """
  Analyze a single code file end-to-end

  Performs complete analysis: metric calculation → enrichment → storage → insights

  ## Parameters
    - file_path: string - path to the file
    - opts: keyword list
      - code: binary (optional) - file contents (read from disk if not provided)
      - language: atom (optional) - language override (auto-detected if not provided)
      - enrich: boolean (default: true) - include enrichment data
      - store: boolean (default: true) - store results in database
      - project_id: string (optional) - project identifier

  ## Returns
    - {:ok, analysis_result} on success
    - {:error, reason} on failure
  """
  def analyze_file(file_path, opts \\ []) do
    with {:ok, code} <- read_code(file_path, opts),
         {:ok, language} <- detect_language(file_path, opts),
         {:ok, metrics} <- calculate_metrics(language, code),
         enrichment <- (Keyword.get(opts, :enrich, true) && enrich_metrics(file_path, language, code)) || %{},
         {:ok, stored} <- (Keyword.get(opts, :store, true) && store_metrics(file_path, language, metrics, enrichment)) || {:ok, metrics},
         insights <- generate_insights(stored, enrichment) do
      {:ok, %{
        file_path: file_path,
        language: language,
        metrics: format_metrics(stored),
        enrichment: enrichment,
        insights: insights,
        timestamp: DateTime.utc_now()
      }}
    else
      {:error, reason} ->
        Logger.error("Failed to analyze #{file_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Batch analyze multiple files

  More efficient than individual analysis when processing many files.

  ## Parameters
    - file_paths: list of strings
    - opts: keyword list (same as analyze_file)

  ## Returns
    - {successful_count, failed_count, results}
  """
  def analyze_batch(file_paths, opts \\ []) do
    results = file_paths
      |> Enum.map(&analyze_file(&1, opts))
      |> Enum.reduce({0, 0, []}, fn
        {:ok, result}, {ok_count, err_count, acc} ->
          {ok_count + 1, err_count, [result | acc]}
        {:error, _reason}, {ok_count, err_count, acc} ->
          {ok_count, err_count + 1, acc}
      end)

    results
  end

  @doc """
  Get metrics for a language across all analyzed files

  Returns aggregated statistics about code quality in a language.
  """
  def language_report(language, opts \\ []) do
    language_str = Atom.to_string(language)
    limit = Keyword.get(opts, :limit, 100)

    try do
      # Get all metrics for language
      all_metrics = Singularity.Metrics.CodeMetrics
        |> where(language: ^language_str)
        |> order_by(desc: :overall_quality_score)
        |> limit(^limit)
        |> Singularity.Repo.all()

      # Calculate statistics
      scores = all_metrics |> Enum.map(& &1.overall_quality_score) |> Enum.filter(& !is_nil(&1))
      avg_quality = if Enum.empty?(scores), do: 0.0, else: Enum.sum(scores) / Enum.count(scores)

      {:ok, %{
        language: language,
        file_count: Enum.count(all_metrics),
        avg_quality_score: avg_quality,
        best_files: Enum.take(all_metrics, 10) |> Enum.map(&%{path: &1.file_path, score: &1.overall_quality_score}),
        worst_files: Enum.take(Enum.reverse(all_metrics), 10) |> Enum.map(&%{path: &1.file_path, score: &1.overall_quality_score}),
        type_safety_avg: Enum.map(all_metrics, & &1.type_safety_score) |> avg_safe(),
        coupling_avg: Enum.map(all_metrics, & &1.coupling_score) |> avg_safe(),
        error_handling_avg: Enum.map(all_metrics, & &1.error_handling_score) |> avg_safe(),
        complexity_avg: Enum.map(all_metrics, & &1.cyclomatic_complexity) |> avg_safe()
      }}
    rescue
      e ->
        Logger.error("Error generating language report: #{inspect(e)}")
        {:error, "Failed to generate report"}
    end
  end

  @doc """
  Find refactoring opportunities across codebase

  Returns files with quality issues that would benefit from refactoring.
  """
  def find_refactoring_opportunities(language \\ nil, threshold \\ 60) do
    query = Singularity.Metrics.CodeMetrics
      |> where([m], m.overall_quality_score < ^threshold)
      |> order_by(asc: :overall_quality_score)
      |> limit(50)

    query = case language do
      nil -> query
      lang -> where(query, language: ^Atom.to_string(lang))
    end

    files = Singularity.Repo.all(query)

    Enum.map(files, fn metrics ->
      opportunities = []

      opportunities = if metrics.type_safety_score && metrics.type_safety_score < 50 do
        opportunities ++ [%{type: :type_safety, severity: :high, score: metrics.type_safety_score}]
      else
        opportunities
      end

      opportunities = if metrics.coupling_score && metrics.coupling_score > 75 do
        opportunities ++ [%{type: :high_coupling, severity: :high, score: metrics.coupling_score}]
      else
        opportunities
      end

      opportunities = if metrics.error_handling_score && metrics.error_handling_score < 50 do
        opportunities ++ [%{type: :error_handling, severity: :high, score: metrics.error_handling_score}]
      else
        opportunities
      end

      %{
        file_path: metrics.file_path,
        language: metrics.language,
        overall_quality: metrics.overall_quality_score,
        opportunities: opportunities
      }
    end)
  end

  # Private helpers

  defp read_code(file_path, opts) do
    case Keyword.get(opts, :code) do
      nil ->
        case File.read(file_path) do
          {:ok, code} -> {:ok, code}
          {:error, _} -> {:error, "Could not read file: #{file_path}"}
        end
      code -> {:ok, code}
    end
  end

  defp detect_language(file_path, opts) do
    case Keyword.get(opts, :language) do
      nil ->
        ext = Path.extname(file_path) |> String.trim_leading(".")
        case Singularity.Metrics.NIF.language_from_extension(ext) do
          nil -> {:error, "Could not detect language for: #{file_path}"}
          lang -> {:ok, lang}
        end
      lang -> {:ok, lang}
    end
  end

  defp calculate_metrics(language, code) do
    case Singularity.Metrics.NIF.analyze_all(language, code) do
      {:ok, metrics} ->
        {:ok, metrics}
      {:error, reason} ->
        Logger.error("Metric calculation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp enrich_metrics(file_path, language, code) do
    Singularity.Metrics.Enrichment.build_context(file_path, language, code)
  end

  defp store_metrics(file_path, language, metrics, enrichment) do
    code_hash = :crypto.hash(:sha256, inspect(metrics)) |> Base.encode16()

    Singularity.Metrics.CodeMetrics.create(%{
      file_path: file_path,
      language: Atom.to_string(language),
      type_safety_score: metrics.type_safety[:score],
      type_safety_details: metrics.type_safety,
      error_handling_score: metrics.error_handling[:score],
      error_handling_details: metrics.error_handling,
      coupling_score: metrics[:coupling_score],
      overall_quality_score: (
        (metrics.type_safety[:score] + metrics.error_handling[:score]) / 2
      ),
      analysis_timestamp: DateTime.utc_now(),
      code_hash: code_hash,
      similar_patterns_found: Enum.count(enrichment[:similar_patterns] || []),
      pattern_matches: %{},
      refactoring_opportunities: Enum.count(enrichment[:refactoring_patterns] || []),
      status: "enriched",
      processing_time_ms: 0
    })
  end

  defp generate_insights(metrics, enrichment) do
    Singularity.Metrics.Enrichment.generate_insights(metrics, enrichment)
  end

  defp format_metrics(stored) do
    %{
      type_safety: stored.type_safety_score,
      error_handling: stored.error_handling_score,
      coupling: stored.coupling_score,
      overall_quality: stored.overall_quality_score
    }
  end

  defp avg_safe(list) do
    filtered = list |> Enum.filter(& !is_nil(&1))
    if Enum.empty?(filtered), do: 0.0, else: Enum.sum(filtered) / Enum.count(filtered)
  end
end
