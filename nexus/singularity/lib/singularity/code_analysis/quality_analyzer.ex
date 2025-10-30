defmodule Singularity.CodeAnalysis.QualityAnalyzer do
  @moduledoc """
  High-level façade that combines semantic metrics from `Singularity.CodeAnalyzer`
  with issue discovery from `Singularity.CodeQuality.AstQualityAnalyzer`.

  The goal is to give callers a single entry-point for “valuable” code quality
  data while keeping the heavy lifting inside the existing analyzers and NIFs.
  """

  alias Singularity.CodeAnalyzer
  alias Singularity.CodeAnalysis.LanguageDetection
  alias Singularity.CodeQuality.AstQualityAnalyzer
  alias Singularity.Analysis.Metadata

  require Logger

  @type analysis_result :: %{
          files: [map()],
          issues: [map()],
          summary: map(),
          refactoring_suggestions: list()
        }

  @doc """
  Analyse a file or directory for code quality issues.

  When `path` points at a directory we recursively sample source files (up to
  `:max_files`, default 200) and aggregate their metrics. When `path` is a file
  we analyse only that file.
  """
  @spec analyze(Path.t(), keyword()) :: {:ok, analysis_result()} | {:error, term()}
  def analyze(path, opts \\ []) when is_binary(path) do
    cond do
      File.dir?(path) ->
        analyze_directory(path, opts)

      File.regular?(path) ->
        with {:ok, file} <-
               do_analyze_file(path, Keyword.put_new(opts, :root, Path.dirname(path))) do
          summary = %{
            total_files: 1,
            languages: %{file.language => 1},
            quality_score: Map.get(file.metrics, :quality_score, 0.0),
            issues_count: length(file.issues),
            report_summary: %{
              total: length(file.issues),
              by_severity:
                file.issues
                |> Enum.group_by(& &1.severity, fn _ -> 1 end)
                |> Enum.map(fn {sev, vals} -> {sev, length(vals)} end)
                |> Map.new(),
              by_category:
                file.issues
                |> Enum.group_by(& &1.category, fn _ -> 1 end)
                |> Enum.map(fn {cat, vals} -> {cat, length(vals)} end)
                |> Map.new()
            }
          }

          {:ok,
           %{
             files: [file],
             issues: file.issues,
             summary: summary,
             refactoring_suggestions: []
           }}
        end

      true ->
        {:error, :invalid_path}
    end
  end

  @doc """
  Analyse a block of source code directly. Useful for editor integrations or
  ephemeral code evaluation.
  """
  @spec analyze_source(String.t(), String.t() | atom(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def analyze_source(source, language_hint, opts \\ [])
      when is_binary(source) and (is_binary(language_hint) or is_atom(language_hint)) do
    language = language_hint |> to_string() |> String.downcase()

    with {:ok, analysis} <- CodeAnalyzer.analyze_language(source, language),
         metadata <-
           build_metadata(analysis, %{path: opts[:path] || "memory", language: language}) do
      issues = extract_issues(analysis, %{path: opts[:path] || "memory", language: language})
      metrics = extract_metrics(analysis)

      {:ok,
       %{
         path: opts[:path] || "memory",
         language: language,
         metadata: metadata,
         metrics: metrics,
         issues: issues,
         raw_analysis: analysis
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Directory analysis --------------------------------------------------------

  defp analyze_directory(root, opts) do
    max_files = Keyword.get(opts, :max_files, 200)
    extensions = Keyword.get(opts, :extensions, default_extensions())
    concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())

    files =
      root
      |> source_file_stream(extensions)
      |> Enum.take(max_files)

    Logger.debug("QualityAnalyzer: analysing #{length(files)} files from #{root}")

    file_results =
      files
      |> Task.async_stream(&do_analyze_file(&1, Keyword.put(opts, :root, root)),
        timeout: Keyword.get(opts, :timeout, 30_000),
        max_concurrency: concurrency,
        ordered: false
      )
      |> Enum.reduce({[], []}, fn
        {:ok, {:ok, file_result}}, {ok, failures} ->
          {[file_result | ok], failures}

        {:ok, {:error, reason}}, {ok, failures} ->
          {ok, [{:error, reason} | failures]}

        {:exit, reason}, {ok, failures} ->
          {ok, [{:error, reason} | failures]}
      end)

    {files_ok, failures} = file_results

    quality_report =
      case AstQualityAnalyzer.analyze_codebase_quality(root, opts) do
        {:ok, report} ->
          report

        {:error, reason} ->
          Logger.warning("QualityAnalyzer: AST quality analysis failed – #{inspect(reason)}")

          %{
            issues: [],
            score: 0,
            summary: %{total: 0, by_severity: %{}, by_category: %{}},
            refactoring_suggestions: [],
            analyzed_at: DateTime.utc_now()
          }
      end

    summary = build_summary(files_ok, quality_report)

    result = %{
      files: Enum.sort_by(files_ok, & &1.path),
      issues: merge_issues(files_ok, quality_report),
      summary: Map.put(summary, :failures, Enum.reverse(failures)),
      refactoring_suggestions: Map.get(quality_report, :refactoring_suggestions, [])
    }

    {:ok, result}
  end

  # File analysis -------------------------------------------------------------

  defp do_analyze_file(path, opts) when is_binary(path) do
    with {:ok, source} <- File.read(path) do
      root = Keyword.get(opts, :root, File.cwd!())
      rel_path = Path.relative_to(path, root)

      language =
        case Keyword.get(opts, :language) do
          nil -> detect_language_for_file(path)
          lang -> to_string(lang)
        end

      analysis_result =
        case CodeAnalyzer.analyze_language(source, language) do
          {:ok, analysis} -> {:ok, analysis}
          {:error, reason} -> {:error, reason}
        end

      case analysis_result do
        {:ok, analysis} ->
          metadata = build_metadata(analysis, %{path: rel_path, language: language})
          metrics = extract_metrics(analysis)
          issues = extract_issues(analysis, %{path: rel_path, language: language})

          {:ok,
           %{
             path: rel_path,
             absolute_path: path,
             language: language,
             metadata: metadata,
             metrics: metrics,
             issues: issues,
             raw_analysis: analysis
           }}

        {:error, reason} ->
          Logger.warning("QualityAnalyzer: failed to analyse #{path}: #{inspect(reason)}")
          {:error, {:analysis_failed, path, reason}}
      end
    else
      {:error, reason} ->
        Logger.error("QualityAnalyzer: unable to read #{path}: #{inspect(reason)}")
        {:error, {:file_read_failed, path, reason}}
    end
  end

  # Helpers -------------------------------------------------------------------

  defp build_summary(files, %{score: score, summary: summary}) do
    quality_scores =
      files
      |> Enum.map(&Map.get(&1.metrics, :quality_score))
      |> Enum.reject(&is_nil/1)

    avg_quality =
      case quality_scores do
        [] -> score
        list -> Enum.sum(list) / length(list)
      end

    languages =
      Enum.reduce(files, %{}, fn file, acc ->
        lang = file.language || "unknown"
        Map.update(acc, lang, 1, &(&1 + 1))
      end)

    %{
      total_files: length(files),
      languages: languages,
      quality_score: Float.round(avg_quality, 2),
      issues_count: summary[:total] || 0,
      report_summary: summary
    }
  end

  defp merge_issues(files, quality_report) do
    file_issue_map =
      files
      |> Enum.flat_map(fn file ->
        Enum.map(file.issues, &Map.put(&1, :source, :static))
      end)

    report_issues =
      quality_report.issues
      |> Enum.map(
        &normalize_issue(&1, %{path: &1.file, language: &1.language, source: :ast_quality})
      )

    file_issue_map ++ report_issues
  end

  defp build_metadata(analysis, defaults) do
    analysis
    |> Map.put_new("path", defaults.path)
    |> Map.put_new("language", defaults.language)
    |> Metadata.new()
  rescue
    _ -> Metadata.new(%{path: defaults.path, language: defaults.language})
  end

  defp extract_metrics(analysis) when is_map(analysis) do
    %{
      quality_score: fetch_number(analysis, ["quality_score", :quality_score]),
      cyclomatic_complexity:
        fetch_number(analysis, ["cyclomatic_complexity", :cyclomatic_complexity]),
      maintainability_index:
        fetch_number(analysis, ["maintainability_index", :maintainability_index]),
      cognitive_complexity:
        fetch_number(analysis, ["cognitive_complexity", :cognitive_complexity]),
      halstead_volume: fetch_number(analysis, ["halstead_volume", :halstead_volume])
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp extract_metrics(_), do: %{}

  defp extract_issues(analysis, defaults) do
    analysis
    |> Map.get(:issues) || Map.get(analysis, "issues") ||
      []
      |> Enum.map(&normalize_issue(&1, defaults))
  end

  defp normalize_issue(issue, defaults) do
    base = %{
      path: Map.get(defaults, :path, "unknown"),
      language: Map.get(defaults, :language, "unknown"),
      severity: :info,
      category: "quality",
      message: nil,
      metadata: %{},
      source: Map.get(defaults, :source, :code_analyzer)
    }

    issue_map =
      case issue do
        %{} = map -> map
        _ -> %{}
      end

    severity =
      issue_map[:severity] || issue_map["severity"] ||
        issue_map[:level] || issue_map["level"] || base.severity

    category = issue_map[:category] || issue_map["category"] || base.category

    message =
      issue_map[:message] || issue_map["message"] ||
        issue_map[:description] || issue_map["description"] ||
        issue_map[:rule] || issue_map["rule"]

    issue_line = issue_map[:line] || issue_map["line"]
    issue_column = issue_map[:column] || issue_map["column"]
    rule_id = issue_map[:rule_id] || issue_map["rule_id"]

    known_keys = [
      :severity,
      "severity",
      :level,
      "level",
      :category,
      "category",
      :message,
      "message",
      :description,
      "description",
      :rule,
      "rule",
      :line,
      "line",
      :column,
      "column",
      :rule_id,
      "rule_id"
    ]

    metadata =
      issue_map
      |> Enum.reject(fn {k, _} -> k in known_keys end)
      |> Enum.into(%{})

    base
    |> Map.put(:severity, normalize_severity(severity))
    |> Map.put(:category, category || base.category)
    |> Map.put(:message, message || "Quality issue detected")
    |> Map.put(:line, issue_line)
    |> Map.put(:column, issue_column)
    |> Map.put(:rule_id, rule_id)
    |> Map.put(:metadata, metadata)
  end

  defp normalize_severity(nil), do: :info
  defp normalize_severity(severity) when is_atom(severity), do: severity

  defp normalize_severity(severity) when is_binary(severity) do
    severity
    |> String.downcase()
    |> case do
      "critical" -> :critical
      "high" -> :high
      "medium" -> :medium
      "low" -> :low
      "info" -> :info
      # BUG FIX: Don't use String.to_atom on unknown values - can create unbounded atoms
      # causing atom table exhaustion and VM crash. Default to :info instead.
      _unknown -> :info
    end
  end

  defp normalize_severity(other), do: other

  defp fetch_number(data, keys) do
    Enum.find_value(keys, fn key ->
      case Map.get(data, key) do
        value when is_number(value) ->
          value

        value when is_binary(value) ->
          case Float.parse(value) do
            {float, _} -> float
            :error -> nil
          end

        _ ->
          nil
      end
    end)
  end

  defp detect_language_for_file(path) do
    case LanguageDetection.by_extension(path) do
      {:ok, %{language: language}} when is_binary(language) -> language
      _ -> infer_language_from_extension(path)
    end
  end

  defp infer_language_from_extension(path) do
    path
    |> Path.extname()
    |> case do
      ".ex" -> "elixir"
      ".exs" -> "elixir"
      ".rs" -> "rust"
      ".py" -> "python"
      ".js" -> "javascript"
      ".ts" -> "typescript"
      ".go" -> "go"
      ".java" -> "java"
      ".rb" -> "ruby"
      ".cs" -> "csharp"
      ".cpp" -> "cpp"
      ".c" -> "c"
      ".swift" -> "swift"
      ".kt" -> "kotlin"
      _ -> "unknown"
    end
  end

  defp source_file_stream(root, extensions) do
    extensions_glob =
      extensions
      |> Enum.map(&String.trim_leading(&1, "."))
      |> Enum.join(",")

    wildcard = Path.join([root, "**", "*.{" <> extensions_glob <> "}"])

    wildcard
    |> Path.wildcard(match_dot: false)
    |> Enum.filter(&File.regular?/1)
  end

  defp default_extensions do
    ~w(
      .ex .exs .heex .rs .py .js .jsx .ts .tsx .go .java .rb .php
      .cs .cpp .c .swift .kt .scala .clj .lua .sql .sh .json .yaml
      .yml .toml .md
    )
  end
end
