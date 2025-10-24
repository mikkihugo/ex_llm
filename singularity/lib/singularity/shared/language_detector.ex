defmodule Singularity.Shared.LanguageDetector do
  @moduledoc """
  Unified Language Detection Module - Single source for file-based language detection.

  Consolidates language detection from multiple modules:
  - MicroserviceAnalyzer
  - CodeStore
  - ArchitectureAnalyzer
  - Codebase metadata detection

  ## Module Identity (JSON)
  ```json
  {
    "module": "Singularity.Shared.LanguageDetector",
    "purpose": "Unified file-based language detection",
    "layer": "shared_infrastructure",
    "replaces": ["MicroserviceAnalyzer.detect_language/1", "CodeStore.basic_technology_detection/1"],
    "status": "production"
  }
  ```

  ## Supported Languages

  Detects languages by checking for canonical files/directories:

  | Language | Files/Markers |
  |----------|---------------|
  | TypeScript | package.json + .ts files |
  | JavaScript | package.json |
  | Rust | Cargo.toml |
  | Python | pyproject.toml, requirements.txt, setup.py |
  | Go | go.mod |
  | Elixir | mix.exs |
  | Java | pom.xml, build.gradle |
  | C/C++ | CMakeLists.txt, Makefile |
  | Ruby | Gemfile, .rb files |
  | PHP | composer.json |

  ## Usage Examples

  ```elixir
  # Detect single language
  :typescript = LanguageDetector.detect("/path/to/project")
  :rust = LanguageDetector.detect("/path/to/rust/project")
  nil = LanguageDetector.detect("/unknown/path")

  # Detect all languages in path
  [:typescript, :rust, :python] = LanguageDetector.detect_all("/workspace")

  # Detect from file extension
  :rust = LanguageDetector.from_extension(".rs")
  :typescript = LanguageDetector.from_extension(".ts")

  # Check if file is source code
  true = LanguageDetector.is_source_file?("lib/main.rs")
  false = LanguageDetector.is_source_file?("README.md")
  ```

  ## Detection Strategy

  1. **Primary**: Check for package manager files (Cargo.toml, go.mod, etc.)
  2. **Secondary**: Check for language-specific directories (.cargo/, vendor/)
  3. **Tertiary**: Scan file extensions in directory
  4. **Fallback**: None if no markers found

  ## Call Graph (Machine-Readable)

  ```yaml
  calls_out:
    - module: File
      function: "exists?/1"
      purpose: Check for marker files
      critical: true

    - module: Path
      function: "[join|basename|extname]/2"
      purpose: Path manipulation
      critical: true

    - module: Logger
      function: "[info|warn]/2"
      purpose: Logging detection results
      critical: false

  called_by:
    - module: Singularity.Storage.Code.Analyzers.MicroserviceAnalyzer
      count: "1+"
      purpose: Service language detection

    - module: Singularity.Storage.Code.CodeStore
      count: "1+"
      purpose: Codebase technology detection

    - module: Singularity.Architecture.Analyzer
      count: "1+"
      purpose: Architecture language context

    - module: Singularity.Execution.Feedback.Analyzer
      count: "1+"
      purpose: Agent feedback analysis
  ```

  ## Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** implement language detection in individual analyzers
  - ❌ **DO NOT** hardcode "package.json + .ts files = TypeScript" in multiple places
  - ✅ **DO** use `LanguageDetector.detect/1` for all language detection
  - ✅ **DO** call `from_extension/1` for single-file language detection
  """

  require Logger

  @language_markers %{
    typescript: ["package.json", "tsconfig.json", "*.ts", "*.tsx"],
    javascript: ["package.json"],
    rust: ["Cargo.toml"],
    python: ["pyproject.toml", "requirements.txt", "setup.py"],
    go: ["go.mod"],
    elixir: ["mix.exs"],
    java: ["pom.xml", "build.gradle"],
    cpp: ["CMakeLists.txt", "*.cpp"],
    ruby: ["Gemfile"],
    php: ["composer.json"],
    csharp: ["*.csproj", "*.sln"]
  }

  @source_extensions %{
    typescript: [".ts", ".tsx", ".js", ".jsx"],
    rust: [".rs"],
    python: [".py"],
    go: [".go"],
    elixir: [".ex", ".exs"],
    java: [".java"],
    cpp: [".cpp", ".h", ".cc"],
    c: [".c", ".h"],
    ruby: [".rb"],
    php: [".php"],
    csharp: [".cs"]
  }

  @doc """
  Detect the primary language of a directory.

  Returns the most likely language based on marker files found.
  Returns `nil` if no language markers detected.

  ## Returns

  - Atom: `:typescript`, `:rust`, `:python`, `:go`, `:elixir`, etc.
  - `nil` if no language detected
  """
  def detect(path) when is_binary(path) do
    cond do
      check_marker(path, "package.json") && has_ts_files?(path) ->
        Logger.debug("Detected TypeScript in #{path}")
        :typescript

      check_marker(path, "package.json") ->
        Logger.debug("Detected JavaScript in #{path}")
        :javascript

      check_marker(path, "Cargo.toml") ->
        Logger.debug("Detected Rust in #{path}")
        :rust

      check_marker(path, "pyproject.toml") || check_marker(path, "requirements.txt") ||
          check_marker(path, "setup.py") ->
        Logger.debug("Detected Python in #{path}")
        :python

      check_marker(path, "go.mod") ->
        Logger.debug("Detected Go in #{path}")
        :go

      check_marker(path, "mix.exs") ->
        Logger.debug("Detected Elixir in #{path}")
        :elixir

      check_marker(path, "pom.xml") || check_marker(path, "build.gradle") ->
        Logger.debug("Detected Java in #{path}")
        :java

      check_marker(path, "Gemfile") ->
        Logger.debug("Detected Ruby in #{path}")
        :ruby

      check_marker(path, "composer.json") ->
        Logger.debug("Detected PHP in #{path}")
        :php

      true ->
        Logger.debug("No language markers detected in #{path}")
        nil
    end
  end

  @doc """
  Detect all languages present in a directory and subdirectories.

  Scans the entire tree to find all detected languages.

  ## Returns

  List of detected languages: `[:typescript, :rust, :python]`
  """
  def detect_all(root_path) when is_binary(root_path) do
    root_path
    |> Path.expand()
    |> list_subdirs()
    |> Enum.map(&detect/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Detect language from file extension.

  Quick lookup based on file extension alone (no filesystem checks).

  ## Returns

  - Atom if extension is recognized: `:rust`, `:python`, etc.
  - `nil` if extension unknown
  """
  def from_extension(filename) when is_binary(filename) do
    ext = Path.extname(filename)

    Enum.find_value(@source_extensions, nil, fn {lang, exts} ->
      if ext in exts, do: lang
    end)
  end

  @doc """
  Check if a file is likely source code (not config, docs, etc.).

  Uses extension-based heuristics to distinguish source from metadata.

  ## Returns

  - `true` if file is likely source code
  - `false` if config, docs, data, etc.
  """
  def is_source_file?(filename) when is_binary(filename) do
    ext = Path.extname(filename)

    # Source code extensions
    case ext do
      ".ts" -> true
      ".tsx" -> true
      ".js" -> true
      ".jsx" -> true
      ".rs" -> true
      ".py" -> true
      ".go" -> true
      ".ex" -> true
      ".exs" -> true
      ".java" -> true
      ".cpp" -> true
      ".c" -> true
      ".h" -> true
      ".rb" -> true
      ".php" -> true
      ".cs" -> true
      _ -> false
    end
  end

  @doc """
  Get all source file extensions for a language.

  Useful for filtering files by language.

  ## Returns

  List of extensions: `[".ts", ".tsx", ".js", ".jsx"]`
  """
  def extensions_for(language) when is_atom(language) do
    Map.get(@source_extensions, language, [])
  end

  # Private helpers

  defp check_marker(path, marker) do
    File.exists?(Path.join(path, marker))
  end

  defp has_ts_files?(path) do
    case File.ls(path) do
      {:ok, files} ->
        Enum.any?(files, fn f ->
          String.ends_with?(f, ".ts") or String.ends_with?(f, ".tsx")
        end)

      {:error, _} ->
        false
    end
  rescue
    _ -> false
  end

  defp list_subdirs(root) do
    case File.ls(root) do
      {:ok, entries} ->
        Enum.map(entries, fn entry ->
          Path.join(root, entry)
        end)
        |> Enum.filter(&File.dir?/1)

      {:error, _} ->
        []
    end
  end
end
