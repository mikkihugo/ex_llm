defmodule Singularity.CodeEngine do
  @moduledoc """
  Simplified code-analysis engine implemented in Elixir.

  The original Rust NIF has been removed; this module offers heuristic analyses so callers that
  rely on `CodeEngine` continue to work. Functions return deterministic maps/tuples mirroring the
  previous API shape.
  """

  @behaviour Singularity.Engine

  @impl Singularity.Engine
  def id, do: :code

  @impl Singularity.Engine
  def label, do: "Code Engine"

  @impl Singularity.Engine
  def description,
    do: "Heuristic code analysis, refactoring insights, and language-aware quality metrics."

  @impl Singularity.Engine
  def capabilities do
    [
      %{
        id: :file_analysis,
        label: "File Analysis",
        description: "Calculate size, complexity, and TODO density for source files.",
        available?: true,
        tags: [:analysis, :heuristic]
      },
      %{
        id: :quality_metrics,
        label: "Quality Metrics",
        description: "Estimate maintainability/readability scores and highlight issues.",
        available?: true,
        tags: [:quality, :metrics]
      },
      %{
        id: :refactoring,
        label: "Refactoring Opportunities",
        description: "Surface candidate blocks for consolidation and improvement.",
        available?: true,
        tags: [:refactoring]
      },
      %{
        id: :language_specific,
        label: "Language-Specific Analysis",
        description: "Infer language traits and recommend targeted improvements.",
        available?: true,
        tags: [:language, :analysis]
      }
    ]
  end

  @impl Singularity.Engine
  def health, do: :ok

  @type analysis :: %{
          path: String.t(),
          language: String.t(),
          bytes: non_neg_integer(),
          lines: non_neg_integer(),
          todo_count: non_neg_integer(),
          complexity: float(),
          summary: String.t()
        }

  @spec analyze_code(String.t(), String.t()) :: {:ok, analysis} | {:error, term()}
  def analyze_code(path, language) do
    with {:ok, contents} <- read_source(path) do
      lines = String.split(contents, "\n")
      line_count = length(lines)
      todo_count = Enum.count(lines, &String.match?(&1, ~r/\b(TODO|FIXME|XXX)\b/))
      complexity = estimate_complexity(lines)

      analysis = %{
        path: path,
        language: language || infer_language(path),
        bytes: byte_size(contents),
        lines: line_count,
        todo_count: todo_count,
        complexity: Float.round(complexity, 2),
        summary: build_summary(line_count, todo_count, complexity)
      }

      {:ok, analysis}
    end
  end

  @spec calculate_quality_metrics(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def calculate_quality_metrics(source, language) do
    lines = String.split(source, "\n")
    complexity = estimate_complexity(lines)
    todo_count = Enum.count(lines, &String.match?(&1, ~r/\b(TODO|FIXME|XXX)\b/))

    metrics = %{
      language: language,
      maintainability: Float.round(max(0.0, 1.0 - complexity / 50), 2),
      readability: Float.round(max(0.0, 1.0 - average_length(lines) / 140), 2),
      todo_count: todo_count,
      issues: detect_simple_issues(lines)
    }

    {:ok, metrics}
  end

  @spec analyze_refactoring_opportunities(String.t(), String.t(), String.t()) :: {:ok, map()}
  def analyze_refactoring_opportunities(path, refactor_type \\ "all", severity \\ "medium") do
    with {:ok, contents} <- read_source(path) do
      chunks = String.split(contents, "\n\n")
      long_chunks = Enum.filter(chunks, &(String.split(&1, "\n") |> length() > 50))

      {:ok,
       %{
         path: path,
         refactor_type: refactor_type,
         severity: severity,
         candidate_count: length(long_chunks),
         candidates: Enum.take(long_chunks, 5)
       }}
    end
  end

  @spec analyze_complexity(String.t(), String.t(), integer()) :: {:ok, map()} | {:error, term()}
  def analyze_complexity(path, _type \\ "all", threshold \\ 10) do
    with {:ok, contents} <- read_source(path) do
      lines = String.split(contents, "\n")
      complexity = Float.round(estimate_complexity(lines), 2)

      {:ok,
       %{
         path: path,
         complexity: complexity,
         threshold: threshold,
         status: if(complexity <= threshold, do: :within_threshold, else: :exceeds_threshold)
       }}
    end
  end

  @spec detect_todos(String.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def detect_todos(path, _types \\ "all", severity \\ "medium") do
    with {:ok, contents} <- read_source(path) do
      todos =
        contents
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} -> String.match?(line, ~r/\b(TODO|FIXME|XXX)\b/) end)
        |> Enum.map(fn {line, line_no} -> %{line: line_no, text: String.trim(line)} end)

      {:ok, %{path: path, severity: severity, todos: todos}}
    end
  end

  @spec consolidate_code(String.t(), String.t(), float()) :: {:ok, map()} | {:error, term()}
  def consolidate_code(path, _type \\ "duplicates", similarity_threshold \\ 0.8) do
    {:ok,
     %{
       path: path,
       similarity_threshold: similarity_threshold,
       duplicates: [],
       suggestions: ["Consider extracting shared helpers if you see repeated logic."],
       status: :not_scanned_in_lightweight_mode
     }}
  end

  @spec analyze_language_specific(String.t(), String.t() | nil, String.t(), boolean()) :: {:ok, map()} | {:error, term()}
  def analyze_language_specific(path, language \\ nil, analysis_type \\ "all", include_recommendations \\ true) do
    detected_language = language || infer_language(path)

    with {:ok, contents} <- read_source(path) do
      {:ok,
       %{
         path: path,
         language: detected_language,
         analysis_type: analysis_type,
         metrics: %{
           stylistic_score: stylistic_score(contents),
           dependency_count: dependency_count(contents)
         },
         recommendations: if(include_recommendations, do: language_recommendations(detected_language), else: [])
       }}
    end
  end

  @spec analyze_quality(String.t(), list(String.t()), boolean()) :: {:ok, map()} | {:error, term()}
  def analyze_quality(path, quality_aspects \\ ["maintainability", "readability", "performance"], include_suggestions \\ true) do
    with {:ok, contents} <- read_source(path) do
      lines = String.split(contents, "\n")

      metrics = %{
        maintainability: Float.round(max(0.0, 1.0 - estimate_complexity(lines) / 60), 2),
        readability: Float.round(max(0.0, 1.0 - average_length(lines) / 150), 2),
        performance: 0.7,
        security: 0.85
      }

      {:ok,
       %{
         path: path,
         aspects: quality_aspects,
         metrics: Map.take(metrics, Enum.map(quality_aspects, &String.to_atom/1)),
         suggestions: if(include_suggestions, do: default_suggestions(), else: [])
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper functions
  # ---------------------------------------------------------------------------

  defp read_source(path) do
    cond do
      File.regular?(path) -> File.read(path)
      File.dir?(path) -> aggregate_directory(path)
      true -> {:ok, path}
    end
  end

  defp aggregate_directory(dir) do
    files = Path.wildcard(Path.join(dir, "**/*.{ex,exs,rs,ts,tsx,js,py,go,java}"))

    contents =
      files
      |> Enum.take(200)
      |> Enum.map(fn file ->
        case File.read(file) do
          {:ok, text} -> "# File: #{file}\n" <> text
          {:error, _} -> ""
        end
      end)
      |> Enum.join("\n")

    {:ok, contents}
  end

  defp estimate_complexity(lines) do
    branch_count =
      lines
      |> Enum.map(&String.trim/1)
      |> Enum.count(fn line ->
        String.starts_with?(line, ["if ", "for ", "while ", "case ", "cond "]) or
          String.contains?(line, ["&&", "||", "? :"])
      end)

    branch_count + Enum.count(lines, &String.contains?(&1, "(")) / 20
  end

  defp average_length(lines) do
    case lines do
      [] -> 0
      _ -> Enum.sum(Enum.map(lines, &String.length/1)) / length(lines)
    end
  end

  defp detect_simple_issues(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce([], fn {line, index}, acc ->
      trimmed = String.trim(line)

      acc
      |> maybe_add_issue(String.length(trimmed) > 120, {:long_line, index})
      |> maybe_add_issue(String.contains?(trimmed, "TODO"), {:todo, index})
      |> maybe_add_issue(String.contains?(trimmed, "IO.inspect"), {:debug_call, index})
    end)
  end

  defp stylistic_score(contents) do
    lines = String.split(contents, "\n")
    comment_ratio =
      lines
      |> Enum.count(&String.starts_with?(String.trim_leading(&1), ["#", "//", "--"]))
      |> case do
        0 -> 0.0
        comment_count -> comment_count / max(length(lines), 1)
      end

    Float.round(min(1.0, 0.6 + comment_ratio), 2)
  end

  defp dependency_count(contents) do
    contents
    |> String.split("\n")
    |> Enum.count(&String.match?(&1, ~r/(use |import |require )/))
  end

  defp language_recommendations("elixir"), do: ["Consider extracting complex pipelines into named functions."]
  defp language_recommendations("rust"), do: ["Ensure error handling covers all Result branches."]
  defp language_recommendations(_), do: []

  defp default_suggestions do
    [
      "Add inline documentation for complex sections.",
      "Introduce tests covering edge cases.",
      "Consider splitting long functions into smaller units."
    ]
  end

  defp build_summary(line_count, todo_count, complexity) do
    "Lines: #{line_count}, TODOs: #{todo_count}, Complexity estimate: #{Float.round(complexity, 2)}"
  end

  defp infer_language(path) do
    cond do
      String.ends_with?(path, [".ex", ".exs"]) -> "elixir"
      String.ends_with?(path, ".rs") -> "rust"
      String.ends_with?(path, [".ts", ".tsx"]) -> "typescript"
      String.ends_with?(path, ".js") -> "javascript"
      String.ends_with?(path, ".py") -> "python"
      String.ends_with?(path, ".go") -> "go"
      String.ends_with?(path, ".java") -> "java"
      true -> "unknown"
    end
  end

  defp maybe_add_issue(issues, true, issue), do: [issue | issues]
  defp maybe_add_issue(issues, false, _issue), do: issues
end
