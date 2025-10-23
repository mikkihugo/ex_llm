defmodule Singularity.LanguageDetection do
  @moduledoc """
  Language detection using Rust NIF backend - Single source of truth.

  ## Module Identity (JSON)

  ```json
  {
    "module_name": "Singularity.LanguageDetection",
    "purpose": "Unified language detection for files and projects",
    "type": "Detection service (Rust NIF backed)",
    "data_sources": ["Rust code_engine NIFs", "File extensions", "Manifest files"],
    "supports": "25+ programming languages"
  }
  ```

  ## Architecture (Mermaid)

  ```mermaid
  graph TD
      A[Elixir Code] -->|call| B[LanguageDetection]
      B -->|NIF| C[Rust code_engine]
      C -->|by_extension| D[Extension Registry]
      C -->|by_manifest| E[Manifest Analyzer]
      D --> F[Language + Confidence]
      E --> F
      B --> G[Elixir Result]
  ```

  ## Call Graph (YAML)

  ```yaml
  LanguageDetection:
    calls:
      - RustAnalyzer.detect_language_by_extension_nif/1  # NIF for file detection
      - RustAnalyzer.detect_language_by_manifest_nif/1   # NIF for project detection
    called_by:
      - CodeSession                      # Tech stack detection
      - CodeSynthesisPipeline            # Context detection
      - ParserEngine                     # File language identification
      - Any module needing language info
    result_type: "LanguageDetectionResult"
  ```

  ## Anti-Patterns

  **DO NOT create these duplicates:**
  - ❌ `ParserEngine.detect_language` - Use this module instead
  - ❌ `CodeSynthesisPipeline.detect_language_from_path` - Use this module
  - ❌ Hardcoded language matching in Elixir - Call Rust via NIF

  **Use this module when:**
  - ✅ Need to detect language from file path
  - ✅ Need to detect primary language from manifest (Cargo.toml, package.json, etc.)
  - ✅ Want confidence scores for language detection
  - ✅ Need consistent detection across codebase

  ## Search Keywords

  language-detection, language-registry, file-extension, manifest-detection, rust-nif,
  programming-language, techstack-detection, project-language, language-identification
  """

  require Logger

  @doc """
  Detect language from a file path using file extension.

  Uses the Rust language registry for accuracy across 25+ languages.
  This is the primary method for identifying individual file languages.

  ## Examples

      iex> LanguageDetection.by_extension("lib/module.ex")
      {:ok, %{language: "elixir", confidence: 0.99, detection_method: "extension"}}

      iex> LanguageDetection.by_extension("src/main.rs")
      {:ok, %{language: "rust", confidence: 0.99, detection_method: "extension"}}

      iex> LanguageDetection.by_extension("unknown.xyz")
      {:ok, %{language: "unknown", confidence: 0.0, detection_method: "extension"}}
  """
  def by_extension(file_path) when is_binary(file_path) do
    case detect_language_by_extension_nif(file_path) do
      {:ok, result} ->
        {:ok, result_to_map(result)}

      {:error, reason} ->
        Logger.warning("Language detection failed for #{file_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Detect primary language from a project manifest file.

  More accurate than extension-based detection for determining a project's
  primary language. Uses manifest files like:
  - Cargo.toml → Rust
  - package.json ± tsconfig.json → TypeScript/JavaScript
  - mix.exs → Elixir
  - go.mod → Go
  - etc.

  ## Examples

      iex> LanguageDetection.by_manifest("Cargo.toml")
      {:ok, %{language: "rust", confidence: 0.95, detection_method: "manifest"}}

      iex> LanguageDetection.by_manifest("mix.exs")
      {:ok, %{language: "elixir", confidence: 0.99, detection_method: "manifest"}}

      iex> LanguageDetection.by_manifest("package.json")
      {:ok, %{language: "javascript", confidence: 0.90, detection_method: "manifest"}}
  """
  def by_manifest(manifest_path) when is_binary(manifest_path) do
    case detect_language_by_manifest_nif(manifest_path) do
      {:ok, result} ->
        {:ok, result_to_map(result)}

      {:error, reason} ->
        Logger.warning("Manifest detection failed for #{manifest_path}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Detect language from file path, returning just the language atom.

  Convenience function that extracts just the language from extension detection.

  ## Examples

      iex> LanguageDetection.detect_file("module.ex")
      {:ok, :elixir}

      iex> LanguageDetection.detect_file("script.py")
      {:ok, :python}

      iex> LanguageDetection.detect_file("unknown.xyz")
      {:error, :unknown_language}
  """
  def detect_file(file_path) when is_binary(file_path) do
    case by_extension(file_path) do
      {:ok, %{language: "unknown"}} ->
        {:error, :unknown_language}

      {:ok, %{language: lang}} ->
        {:ok, String.to_atom(lang)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Detect primary project language from manifest path.

  Convenience function that extracts just the language from manifest detection.

  ## Examples

      iex> LanguageDetection.detect_project("Cargo.toml")
      {:ok, :rust}

      iex> LanguageDetection.detect_project("mix.exs")
      {:ok, :elixir}
  """
  def detect_project(manifest_path) when is_binary(manifest_path) do
    case by_manifest(manifest_path) do
      {:ok, %{language: "unknown"}} ->
        {:error, :unknown_language}

      {:ok, %{language: lang}} ->
        {:ok, String.to_atom(lang)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Smart detection - tries manifest first, falls back to extension.

  For maximum accuracy:
  1. If manifest_path provided, use manifest detection (project language)
  2. Otherwise, use file extension detection (file language)

  ## Examples

      iex> LanguageDetection.smart("mix.exs", "lib/module.ex")
      {:ok, :elixir}  # Manifest wins

      iex> LanguageDetection.smart(nil, "src/main.rs")
      {:ok, :rust}  # Falls back to extension
  """
  def smart(manifest_path, file_path) when is_binary(file_path) do
    case manifest_path do
      nil ->
        detect_file(file_path)

      manifest ->
        case detect_project(manifest) do
          {:ok, lang} -> {:ok, lang}
          {:error, _} -> detect_file(file_path)
        end
    end
  end

  @doc """
  Get detection confidence for a language.

  Useful for determining how confident the detection is.
  Higher values (0.9+) indicate high confidence.

  ## Examples

      iex> LanguageDetection.confidence("main.ex")
      {:ok, 0.99}

      iex> LanguageDetection.confidence("unknown.xyz")
      {:ok, 0.0}
  """
  def confidence(file_path) when is_binary(file_path) do
    case by_extension(file_path) do
      {:ok, %{confidence: conf}} -> {:ok, conf}
      {:error, reason} -> {:error, reason}
    end
  end

  # Private helper functions

  defp result_to_map(result) do
    %{
      language: result.language,
      confidence: result.confidence,
      detection_method: result.detection_method
    }
  end

  # NIF stubs - implemented in Rust

  defp detect_language_by_extension_nif(_file_path) do
    :erlang.nif_error(:nif_not_loaded)
  end

  defp detect_language_by_manifest_nif(_manifest_path) do
    :erlang.nif_error(:nif_not_loaded)
  end
end
