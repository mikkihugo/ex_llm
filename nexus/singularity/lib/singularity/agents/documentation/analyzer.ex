defmodule Singularity.Agents.Documentation.Analyzer do
  @moduledoc """
  Documentation Quality Analyzer - Analyzes documentation quality for source files.

  ## Purpose

  Provides comprehensive documentation quality analysis across multiple languages
  (Elixir, Rust, TypeScript). Assesses presence of required elements, calculates
  quality scores, and identifies missing documentation components.

  ## Public API

  - `analyze_documentation_quality/1` - Analyze file documentation quality
  - `identify_missing_documentation/2` - Identify missing documentation elements
  - `has_documentation?/2` - Check if file has documentation
  - `detect_language/1` - Detect source file language
  - `calculate_quality_score/2` - Calculate documentation quality score

  ## Module Identity (JSON)
  ```json
  {
    "module_name": "Documentation.Analyzer",
    "purpose": "documentation_quality_analysis",
    "domain": "agents/documentation",
    "capabilities": ["quality_assessment", "language_detection", "missing_element_identification"],
    "dependencies": []
  }
  ```

  ## Architecture Diagram (Mermaid)
  ```mermaid
  graph TD
    A[Documentation.Analyzer] --> B[analyze_documentation_quality/1]
    B --> C[has_documentation?/2]
    B --> D[detect_language/1]
    B --> E[calculate_quality_score/2]
    A --> F[identify_missing_documentation/2]
    F --> C
    F --> D
  ```

  ## Call Graph (YAML)
  ```yaml
  Documentation.Analyzer:
    analyze_documentation_quality/1: [File.read/1, has_documentation?/2, detect_language/1, calculate_quality_score/2]
    identify_missing_documentation/2: [detect_language/1, has_documentation?/2]
    has_documentation?/2: [detect_language/1]
    detect_language/1: [String.ends_with?/2]
    calculate_quality_score/2: [detect_language/1, get_required_elements/1]
  ```

  ## Anti-Patterns

  - DO NOT use this for code generation (use DocumentationPipeline instead)
  - DO NOT call LLM services directly (this is analysis only)
  - DO NOT modify files (this is read-only analysis)

  ## Search Keywords

  documentation, quality, analysis, analyzer, elixir, rust, typescript, moduledoc,
  quality_score, missing_elements, language_detection, code_documentation
  """

  require Logger

  @doc """
  Analyze file documentation quality.

  Returns comprehensive quality analysis including presence of required elements,
  language detection, and calculated quality score.

  ## Examples

      iex> Analyzer.analyze_documentation_quality("lib/my_module.ex")
      {:ok, %{
        has_documentation: true,
        has_identity: true,
        has_architecture_diagram: false,
        language: :elixir,
        quality_score: 0.67
      }}
  """
  @spec analyze_documentation_quality(String.t()) :: {:ok, map()} | {:error, term()}
  def analyze_documentation_quality(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        quality_analysis = %{
          has_documentation: has_documentation?(content, file_path),
          has_identity: String.contains?(content, "Identity"),
          has_architecture_diagram: String.contains?(content, "Architecture Diagram"),
          has_call_graph: String.contains?(content, "Call Graph"),
          has_anti_patterns: String.contains?(content, "Anti-Patterns"),
          has_search_keywords: String.contains?(content, "Search Keywords"),
          language: detect_language(file_path),
          quality_score: calculate_quality_score(content, file_path)
        }

        {:ok, quality_analysis}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Identify missing documentation elements for a file.

  Analyzes content to determine which required documentation elements are missing
  and returns them along with detected language.

  ## Examples

      iex> Analyzer.identify_missing_documentation(content, "lib/my_module.ex")
      {:ok, %{missing: [:architecture_diagram, :call_graph], language: :elixir}}
  """
  @spec identify_missing_documentation(String.t(), String.t()) :: {:ok, map()}
  def identify_missing_documentation(content, file_path) do
    language = detect_language(file_path)

    missing =
      []
      |> maybe_add(!has_documentation?(content, file_path), :documentation)
      |> maybe_add(!String.contains?(content, "Identity"), :identity)
      |> maybe_add(!String.contains?(content, "Architecture Diagram"), :architecture_diagram)
      |> maybe_add(!String.contains?(content, "Call Graph"), :call_graph)
      |> maybe_add(!String.contains?(content, "Anti-Patterns"), :anti_patterns)
      |> maybe_add(!String.contains?(content, "Search Keywords"), :search_keywords)

    {:ok, %{missing: missing, language: language}}
  end

  @doc """
  Check if content has documentation based on language.

  Detects language and checks for appropriate documentation markers
  (@moduledoc for Elixir, /// for Rust, /** for TypeScript).

  ## Examples

      iex> Analyzer.has_documentation?(content, "lib/my_module.ex")
      true
  """
  @spec has_documentation?(String.t(), String.t()) :: boolean()
  def has_documentation?(content, file_path) do
    language = detect_language(file_path)

    case language do
      :elixir -> String.contains?(content, "@moduledoc")
      :rust -> String.contains?(content, "///")
      :typescript -> String.contains?(content, "/**")
      _ -> false
    end
  end

  @doc """
  Detect programming language from file path.

  Determines language based on file extension (.ex/.exs = Elixir, .rs = Rust, .ts/.tsx = TypeScript).

  ## Examples

      iex> Analyzer.detect_language("lib/my_module.ex")
      :elixir

      iex> Analyzer.detect_language("src/main.rs")
      :rust
  """
  @spec detect_language(String.t()) :: :elixir | :rust | :typescript | :unknown
  def detect_language(file_path) do
    cond do
      String.ends_with?(file_path, ".ex") or String.ends_with?(file_path, ".exs") ->
        :elixir

      String.ends_with?(file_path, ".rs") ->
        :rust

      String.ends_with?(file_path, ".ts") or String.ends_with?(file_path, ".tsx") ->
        :typescript

      true ->
        :unknown
    end
  end

  @doc """
  Calculate documentation quality score (0.0 to 1.0).

  Evaluates content against required elements for the detected language and
  returns percentage of elements present.

  ## Examples

      iex> Analyzer.calculate_quality_score(content, "lib/my_module.ex")
      0.83
  """
  @spec calculate_quality_score(String.t(), String.t()) :: float()
  def calculate_quality_score(content, file_path) do
    language = detect_language(file_path)
    required_elements = get_required_elements(language)

    score =
      required_elements
      |> Enum.map(fn element -> String.contains?(content, element) end)
      |> Enum.count(& &1)
      |> Kernel./(length(required_elements))

    Float.round(score, 2)
  end

  # Private helper functions

  defp get_required_elements(language) do
    case language do
      :elixir ->
        [
          "@moduledoc",
          "Module Identity",
          "Architecture Diagram",
          "Call Graph",
          "Anti-Patterns",
          "Search Keywords"
        ]

      :rust ->
        [
          "///",
          "Crate Identity",
          "Architecture Diagram",
          "Call Graph",
          "Anti-Patterns",
          "Search Keywords"
        ]

      :typescript ->
        [
          "/**",
          "Component Identity",
          "Architecture Diagram",
          "Call Graph",
          "Anti-Patterns",
          "Search Keywords"
        ]

      _ ->
        []
    end
  end

  defp maybe_add(list, true, item), do: [item | list]
  defp maybe_add(list, false, _item), do: list
end
