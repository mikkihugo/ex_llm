defmodule Singularity.CodeAnalysis.Scanners.LintingScanner do
  @moduledoc """
  Wrapper that exposes `Singularity.LintingEngine` as a unified scanner module.
  This allows the scan orchestrator and configuration (`config :singularity, :scanner_types`)
  to treat the linting engine like other scanners (quality, security, etc).

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.CodeAnalysis.Scanners.LintingScanner",
    "type": "linting_scanner_wrapper",
    "purpose": "Expose multi-language linting as unified scanner interface",
    "layer": "code_analysis",
    "wrapped_module": "Singularity.LintingEngine",
    "languages": "Elixir, Rust, TypeScript, Python, JavaScript, Go, Java, C/C#, Gleam, Erlang, and more"
  }
  ```

  ## Architecture Diagram

  ```mermaid
  graph TD
      A["LintingScanner.scan/2"] --> B["discover_files_by_language"]
      B --> C["run_linters_for_language"]
      C --> D["LintingEngine.analyze_code_quality/2"]
      D --> E["LintingEngine.detect_ai_patterns/2"]
      E --> F["generate_linting_report"]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls:
    - Singularity.LintingEngine (multi-language linting)
    - File (read codebase files)

  called_by:
    - Scan Orchestrator
    - Code analysis workflows
  ```

  ## Anti-Patterns

  ❌ **DO NOT** call LintingEngine directly - use this wrapper
  ❌ **DO NOT** skip language detection - affects linter selection
  ❌ **DO NOT** mix quality metrics with linting issues - maintain separation
  """

  alias Singularity.LintingEngine

  require Logger

  @type scan_result :: %{
          issues: [map()],
          summary: map()
        }

  @doc "Human readable name used by the scan orchestrator."
  @spec name() :: atom()
  def name, do: :linting

  @doc "Return scanner metadata (name + description) used in UIs."
  @spec info() :: map()
  def info do
    config = Application.get_env(:singularity, :scanner_types, %{})
    scanner_cfg = Map.get(config, name(), %{})

    %{
      name: name(),
      description:
        Map.get(
          scanner_cfg,
          :description,
          "Multi-language linting: style, security, performance, AI patterns"
        ),
      enabled: Map.get(scanner_cfg, :enabled, true)
    }
  end

  @doc """
  Check if the scanner is enabled in configuration.
  """
  @spec enabled?() :: boolean()
  def enabled? do
    info()[:enabled]
  end

  @doc """
  Run the linting scanner against a path (file or directory).

  Scans supported languages using language-appropriate linters:
  - Elixir: Credo
  - Rust: Clippy
  - TypeScript/JavaScript: ESLint
  - Python: Pylint/Flake8
  - And more...

  Returns linting issues with categories (style, security, performance, ai_patterns).
  """
  @spec scan(Path.t(), keyword()) :: {:ok, scan_result()} | {:error, term()}
  def scan(path, opts \\ []) do
    try do
      exclude_patterns = Keyword.get(opts, :exclude_patterns, ["test/**", "deps/**", "_build/**"])

      with {:ok, files_by_lang} <- discover_files_by_language(path, exclude_patterns),
           {:ok, issues} <- run_linters_for_all_languages(files_by_lang),
           {:ok, ai_patterns} <- detect_ai_patterns_in_files(files_by_lang) do
        all_issues = issues ++ ai_patterns

        summary = %{
          total: length(all_issues),
          by_category: categorize_issues(all_issues),
          by_severity: severity_summary(all_issues),
          scanned_at: DateTime.utc_now()
        }

        {:ok, %{issues: all_issues, summary: summary}}
      end
    rescue
      error ->
        Logger.warning("Linting scan failed: #{inspect(error)}")
        {:error, "Linting scan failed: #{inspect(error)}"}
    end
  end

  # ============================================================================
  # Private Helpers - File Discovery
  # ============================================================================

  defp discover_files_by_language(path, exclude_patterns) do
    extensions = %{
      "elixir" => [".ex", ".exs"],
      "rust" => [".rs"],
      "typescript" => [".ts", ".tsx"],
      "javascript" => [".js", ".jsx"],
      "python" => [".py"],
      "go" => [".go"],
      "java" => [".java"],
      "c" => [".c", ".h"],
      "cpp" => [".cpp", ".hpp", ".cc", ".cxx"],
      "csharp" => [".cs"],
      "gleam" => [".gleam"],
      "erlang" => [".erl"]
    }

    files_by_lang =
      Enum.reduce(extensions, %{}, fn {lang, exts}, acc ->
        files =
          for ext <- exts do
            Path.wildcard("#{path}/**/*#{ext}")
          end
          |> List.flatten()
          |> Enum.reject(fn file ->
            Enum.any?(exclude_patterns, fn pattern ->
              String.contains?(file, pattern)
            end)
          end)

        case files do
          [] -> acc
          files_list -> Map.put(acc, lang, files_list)
        end
      end)

    {:ok, files_by_lang}
  end

  # ============================================================================
  # Private Helpers - Linting
  # ============================================================================

  defp run_linters_for_all_languages(files_by_lang) do
    issues =
      for {language, files} <- files_by_lang do
        run_linters_for_language(language, files)
      end
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    {:ok, issues}
  end

  defp run_linters_for_language(language, files) do
    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          case LintingEngine.analyze_code_quality(content, language) do
            {:ok, %{issues: issues}} ->
              Enum.map(issues, fn issue ->
                Map.merge(issue, %{
                  file: file,
                  language: language,
                  type: :linting_issue
                })
              end)

            {:error, _reason} ->
              []
          end

        {:error, _reason} ->
          []
      end
    end)
  end

  defp detect_ai_patterns_in_files(files_by_lang) do
    ai_issues =
      for {language, files} <- files_by_lang do
        detect_ai_patterns_for_language(language, files)
      end
      |> List.flatten()
      |> Enum.reject(&is_nil/1)

    {:ok, ai_issues}
  end

  defp detect_ai_patterns_for_language(language, files) do
    Enum.flat_map(files, fn file ->
      case File.read(file) do
        {:ok, content} ->
          case LintingEngine.detect_ai_patterns(content, language) do
            {:ok, patterns} ->
              Enum.map(patterns, fn pattern ->
                %{
                  type: :ai_pattern,
                  file: file,
                  language: language,
                  category: :ai_patterns,
                  severity: :info,
                  pattern: pattern.get(:pattern, "unknown"),
                  description: pattern.get(:description, "AI-generated pattern detected"),
                  line: pattern.get(:line)
                }
              end)

            {:error, _reason} ->
              []
          end

        {:error, _reason} ->
          []
      end
    end)
  end

  # ============================================================================
  # Private Helpers - Reporting
  # ============================================================================

  defp categorize_issues(issues) do
    issues
    |> Enum.group_by(fn issue ->
      Map.get(issue, :category, :other)
    end)
    |> Enum.map(fn {category, items} ->
      {category, length(items)}
    end)
    |> Map.new()
  end

  defp severity_summary(issues) do
    issues
    |> Enum.group_by(fn issue ->
      Map.get(issue, :severity, :info)
    end)
    |> Enum.map(fn {severity, items} ->
      {severity, length(items)}
    end)
    |> Map.new()
  end
end
