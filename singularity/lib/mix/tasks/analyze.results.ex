defmodule Mix.Tasks.Analyze.Results do
  @moduledoc """
  Query and report on stored code analysis results.

  ## Usage

      # Show recent analysis results
      mix analyze.results --codebase-id my-project

      # Show quality trend for specific file
      mix analyze.results --file-path lib/my_module.ex --trend

      # Find files with declining quality
      mix analyze.results --codebase-id my-project --degraded

      # Show detailed metrics for specific file
      mix analyze.results --file-path lib/my_module.ex --detailed

      # Export results to JSON
      mix analyze.results --codebase-id my-project --export results.json

  ## Options

      --codebase-id    Codebase identifier
      --file-path      Specific file path
      --trend          Show quality trend over time
      --degraded       Find files with declining quality
      --detailed       Show detailed metrics
      --export         Export to JSON file
      --limit          Limit number of results (default: 20)
      --min-quality    Minimum quality score filter (0.0-1.0)
      --max-quality    Maximum quality score filter (0.0-1.0)
  """

  use Mix.Task
  import Ecto.Query
  alias Singularity.{Repo, Schemas.CodeFile, Schemas.CodeAnalysisResult}

  @shortdoc "Query and report on stored analysis results"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _} =
      OptionParser.parse!(args,
        strict: [
          codebase_id: :string,
          file_path: :string,
          trend: :boolean,
          degraded: :boolean,
          detailed: :boolean,
          export: :string,
          limit: :integer,
          min_quality: :float,
          max_quality: :float
        ]
      )

    cond do
      opts[:trend] && opts[:file_path] ->
        show_file_trend(opts[:file_path])

      opts[:degraded] && opts[:codebase_id] ->
        show_degraded_files(opts[:codebase_id], opts)

      opts[:detailed] && opts[:file_path] ->
        show_detailed_metrics(opts[:file_path])

      opts[:export] && opts[:codebase_id] ->
        export_results(opts[:codebase_id], opts[:export], opts)

      opts[:codebase_id] ->
        show_recent_results(opts[:codebase_id], opts)

      opts[:file_path] ->
        show_file_results(opts[:file_path], opts)

      true ->
        Mix.shell().error("Error: Must provide --codebase-id or --file-path")
        Mix.shell().info("\nUsage: mix analyze.results --codebase-id my-project")
    end
  end

  # Show recent analysis results for codebase
  defp show_recent_results(codebase_id, opts) do
    limit = opts[:limit] || 20

    query =
      from r in CodeAnalysisResult,
        join: f in CodeFile,
        on: r.code_file_id == f.id,
        where: f.codebase_id == ^codebase_id,
        order_by: [desc: r.inserted_at],
        limit: ^limit,
        select: {f.file_path, r}

    query = apply_quality_filters(query, opts)

    results = Repo.all(query)

    if Enum.empty?(results) do
      Mix.shell().info("No analysis results found for codebase: #{codebase_id}")
    else
      Mix.shell().info("\n" <> String.duplicate("=", 80))
      Mix.shell().info("Recent Analysis Results for: #{codebase_id}")
      Mix.shell().info(String.duplicate("=", 80) <> "\n")

      Enum.each(results, fn {path, result} ->
        print_result_summary(path, result)
      end)

      Mix.shell().info("\nShowing #{length(results)} most recent results")
    end
  end

  # Show all analysis results for specific file
  defp show_file_results(file_path, opts) do
    limit = opts[:limit] || 20

    query =
      from r in CodeAnalysisResult,
        join: f in CodeFile,
        on: r.code_file_id == f.id,
        where: f.file_path == ^file_path,
        order_by: [desc: r.inserted_at],
        limit: ^limit,
        select: r

    query = apply_quality_filters(query, opts)

    results = Repo.all(query)

    if Enum.empty?(results) do
      Mix.shell().info("No analysis results found for file: #{file_path}")
    else
      Mix.shell().info("\n" <> String.duplicate("=", 80))
      Mix.shell().info("Analysis Results for: #{file_path}")
      Mix.shell().info(String.duplicate("=", 80) <> "\n")

      Enum.each(results, fn result ->
        print_result_summary(file_path, result)
      end)

      Mix.shell().info("\nShowing #{length(results)} results")
    end
  end

  # Show quality trend over time for specific file
  defp show_file_trend(file_path) do
    query =
      from r in CodeAnalysisResult,
        join: f in CodeFile,
        on: r.code_file_id == f.id,
        where: f.file_path == ^file_path,
        order_by: [asc: r.inserted_at],
        select: {r.inserted_at, r.quality_score, r.complexity_score, r.maintainability_score}

    results = Repo.all(query)

    if Enum.empty?(results) do
      Mix.shell().info("No analysis results found for file: #{file_path}")
    else
      Mix.shell().info("\n" <> String.duplicate("=", 80))
      Mix.shell().info("Quality Trend for: #{file_path}")
      Mix.shell().info(String.duplicate("=", 80) <> "\n")

      Mix.shell().info(
        String.pad_trailing("Date", 25) <>
          String.pad_trailing("Quality", 12) <>
          String.pad_trailing("Complexity", 12) <>
          "Maintainability"
      )

      Mix.shell().info(String.duplicate("-", 80))

      Enum.each(results, fn {timestamp, quality, complexity, maintainability} ->
        date = Calendar.strftime(timestamp, "%Y-%m-%d %H:%M:%S")
        quality_str = if quality, do: Float.round(quality, 2), else: "N/A"
        complexity_str = if complexity, do: Float.round(complexity, 2), else: "N/A"
        maintainability_str = if maintainability, do: Float.round(maintainability, 2), else: "N/A"

        Mix.shell().info(
          String.pad_trailing(date, 25) <>
            String.pad_trailing("#{quality_str}", 12) <>
            String.pad_trailing("#{complexity_str}", 12) <>
            "#{maintainability_str}"
        )
      end)

      # Calculate trend
      if length(results) >= 2 do
        {_first_time, first_quality, _, _} = List.first(results)
        {_last_time, last_quality, _, _} = List.last(results)

        if first_quality && last_quality do
          change = last_quality - first_quality

          trend =
            cond do
              change > 0.05 -> "📈 Improving"
              change < -0.05 -> "📉 Declining"
              true -> "➡️  Stable"
            end

          Mix.shell().info("\n#{trend} (#{format_change(change)})")
        end
      end
    end
  end

  # Show files with declining quality
  defp show_degraded_files(codebase_id, opts) do
    limit = opts[:limit] || 20

    # Find files with at least 2 analyses
    subquery =
      from r in CodeAnalysisResult,
        join: f in CodeFile,
        on: r.code_file_id == f.id,
        where: f.codebase_id == ^codebase_id and not is_nil(r.quality_score),
        group_by: r.code_file_id,
        having: count(r.id) >= 2,
        select: %{code_file_id: r.code_file_id}

    # Get first and last quality scores
    query =
      from f in CodeFile,
        join: s in subquery(subquery),
        on: f.id == s.code_file_id,
        join: first in CodeAnalysisResult,
        on: first.code_file_id == f.id,
        join: last in CodeAnalysisResult,
        on: last.code_file_id == f.id,
        where:
          first.inserted_at ==
            fragment(
              "(SELECT MIN(inserted_at) FROM code_analysis_results WHERE code_file_id = ?)",
              f.id
            ),
        where:
          last.inserted_at ==
            fragment(
              "(SELECT MAX(inserted_at) FROM code_analysis_results WHERE code_file_id = ?)",
              f.id
            ),
        where: last.quality_score < first.quality_score,
        order_by: [asc: fragment("? - ?", last.quality_score, first.quality_score)],
        limit: ^limit,
        select:
          {f.file_path, first.quality_score, last.quality_score, first.inserted_at,
           last.inserted_at}

    results = Repo.all(query)

    if Enum.empty?(results) do
      Mix.shell().info("✅ No files with declining quality found!")
    else
      Mix.shell().info("\n" <> String.duplicate("=", 80))
      Mix.shell().info("📉 Files with Declining Quality")
      Mix.shell().info(String.duplicate("=", 80) <> "\n")

      Mix.shell().info(
        String.pad_trailing("File", 45) <>
          String.pad_trailing("First", 10) <>
          String.pad_trailing("Last", 10) <>
          "Change"
      )

      Mix.shell().info(String.duplicate("-", 80))

      Enum.each(results, fn {path, first_quality, last_quality, _first_time, _last_time} ->
        change = last_quality - first_quality
        shortened_path = String.slice(path, -40..-1) || path

        Mix.shell().info(
          String.pad_trailing(shortened_path, 45) <>
            String.pad_trailing("#{Float.round(first_quality, 2)}", 10) <>
            String.pad_trailing("#{Float.round(last_quality, 2)}", 10) <>
            format_change(change)
        )
      end)

      Mix.shell().info("\nShowing #{length(results)} files with declining quality")
    end
  end

  # Show detailed metrics for specific file
  defp show_detailed_metrics(file_path) do
    query =
      from r in CodeAnalysisResult,
        join: f in CodeFile,
        on: r.code_file_id == f.id,
        where: f.file_path == ^file_path,
        order_by: [desc: r.inserted_at],
        limit: 1,
        select: r

    case Repo.one(query) do
      nil ->
        Mix.shell().info("No analysis results found for file: #{file_path}")

      result ->
        Mix.shell().info("\n" <> String.duplicate("=", 80))
        Mix.shell().info("Detailed Analysis for: #{file_path}")
        Mix.shell().info(String.duplicate("=", 80) <> "\n")

        print_detailed_result(result)
    end
  end

  # Export results to JSON
  defp export_results(codebase_id, output_file, opts) do
    limit = opts[:limit] || 1000

    query =
      from r in CodeAnalysisResult,
        join: f in CodeFile,
        on: r.code_file_id == f.id,
        where: f.codebase_id == ^codebase_id,
        order_by: [desc: r.inserted_at],
        limit: ^limit,
        select: %{
          file_path: f.file_path,
          language: r.language_id,
          analysis_type: r.analysis_type,
          quality_score: r.quality_score,
          complexity_score: r.complexity_score,
          maintainability_score: r.maintainability_score,
          cyclomatic_complexity: r.cyclomatic_complexity,
          source_lines_of_code: r.source_lines_of_code,
          functions_count: r.functions_count,
          classes_count: r.classes_count,
          has_errors: r.has_errors,
          error_message: r.error_message,
          analysis_duration_ms: r.analysis_duration_ms,
          cache_hit: r.cache_hit,
          analyzed_at: r.inserted_at
        }

    query = apply_quality_filters(query, opts)

    results = Repo.all(query)

    json_data = Jason.encode!(results, pretty: true)
    File.write!(output_file, json_data)

    Mix.shell().info("✅ Exported #{length(results)} results to: #{output_file}")
  end

  # Print result summary
  defp print_result_summary(path, result) do
    date = Calendar.strftime(result.inserted_at, "%Y-%m-%d %H:%M:%S")
    quality = if result.quality_score, do: "#{Float.round(result.quality_score, 2)}", else: "N/A"

    complexity =
      if result.complexity_score, do: "#{Float.round(result.complexity_score, 2)}", else: "N/A"

    status = if result.has_errors, do: "❌ ERROR", else: "✅"
    cache_indicator = if result.cache_hit, do: "💾", else: ""

    shortened_path = String.slice(path, -50..-1) || path

    Mix.shell().info("#{status} #{cache_indicator} [#{date}] #{shortened_path}")

    Mix.shell().info(
      "    Language: #{result.language_id} | Quality: #{quality} | Complexity: #{complexity}"
    )

    if result.has_errors do
      Mix.shell().info("    Error: #{result.error_message}")
    end

    Mix.shell().info("")
  end

  # Print detailed result
  defp print_detailed_result(result) do
    Mix.shell().info("Language: #{result.language_id}")
    Mix.shell().info("Analysis Type: #{result.analysis_type}")
    Mix.shell().info("Analyzed: #{Calendar.strftime(result.inserted_at, "%Y-%m-%d %H:%M:%S")}")
    Mix.shell().info("Duration: #{result.analysis_duration_ms}ms")
    Mix.shell().info("Cache Hit: #{result.cache_hit}")
    Mix.shell().info("")

    if result.has_errors do
      Mix.shell().info("⚠️  Status: ERROR")
      Mix.shell().info("Error: #{result.error_message}")
    else
      Mix.shell().info("✅ Status: SUCCESS")
      Mix.shell().info("")

      Mix.shell().info("Quality Metrics:")
      Mix.shell().info("  Quality Score:        #{format_metric(result.quality_score)}")
      Mix.shell().info("  Complexity Score:     #{format_metric(result.complexity_score)}")
      Mix.shell().info("  Maintainability:      #{format_metric(result.maintainability_score)}")
      Mix.shell().info("")

      if result.cyclomatic_complexity do
        Mix.shell().info("RCA Metrics:")
        Mix.shell().info("  Cyclomatic Complexity:   #{result.cyclomatic_complexity}")

        Mix.shell().info(
          "  Cognitive Complexity:    #{format_metric(result.cognitive_complexity)}"
        )

        Mix.shell().info(
          "  Maintainability Index:   #{format_metric(result.maintainability_index)}"
        )

        Mix.shell().info(
          "  Source Lines of Code:    #{format_metric(result.source_lines_of_code)}"
        )

        Mix.shell().info(
          "  Physical Lines:          #{format_metric(result.physical_lines_of_code)}"
        )

        Mix.shell().info(
          "  Logical Lines:           #{format_metric(result.logical_lines_of_code)}"
        )

        Mix.shell().info(
          "  Comment Lines:           #{format_metric(result.comment_lines_of_code)}"
        )

        Mix.shell().info("")

        if result.halstead_difficulty do
          Mix.shell().info("Halstead Metrics:")
          Mix.shell().info("  Difficulty:  #{Float.round(result.halstead_difficulty, 2)}")
          Mix.shell().info("  Volume:      #{Float.round(result.halstead_volume, 2)}")
          Mix.shell().info("  Effort:      #{Float.round(result.halstead_effort, 2)}")
          Mix.shell().info("  Bugs:        #{Float.round(result.halstead_bugs, 2)}")
          Mix.shell().info("")
        end
      end

      if result.functions_count do
        Mix.shell().info("AST Metrics:")
        Mix.shell().info("  Functions:  #{result.functions_count}")
        Mix.shell().info("  Classes:    #{format_metric(result.classes_count)}")
        Mix.shell().info("  Imports:    #{format_metric(result.imports_count)}")
        Mix.shell().info("  Exports:    #{format_metric(result.exports_count)}")
      end
    end
  end

  # Apply quality score filters to query
  defp apply_quality_filters(query, opts) do
    query =
      if min_quality = opts[:min_quality] do
        from r in query, where: r.quality_score >= ^min_quality
      else
        query
      end

    if max_quality = opts[:max_quality] do
      from r in query, where: r.quality_score <= ^max_quality
    else
      query
    end
  end

  # Format metric value
  defp format_metric(nil), do: "N/A"
  defp format_metric(value) when is_float(value), do: "#{Float.round(value, 2)}"
  defp format_metric(value), do: "#{value}"

  # Format quality change
  defp format_change(change) when change > 0, do: "+#{Float.round(change, 2)}"
  defp format_change(change), do: "#{Float.round(change, 2)}"
end
