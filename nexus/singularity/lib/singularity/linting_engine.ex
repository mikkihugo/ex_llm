defmodule Singularity.LintingEngine do
  @moduledoc """
  Elixir wrapper for the Rust linting_engine NIF.

  Provides multi-language linting and quality gate enforcement using the
  unified language registry from parser_engine.

  ## Supported Languages

  The linting engine supports all languages registered in the language_registry:
  - Rust, JavaScript, TypeScript, Python, Go, Java, C++, C#
  - Elixir, Erlang, Gleam, and more

  ## Usage

  ```elixir
  # Get supported languages
  iex> Singularity.LintingEngine.get_supported_languages()
  ["rust", "javascript", "typescript", "python", "go", "java", ...]

  # Check if a language is supported
  iex> Singularity.LintingEngine.is_language_supported("elixir")
  true

  # Get version
  iex> Singularity.LintingEngine.version()
  "linting_engine-0.1.0 (0.1.0)"
  ```

  ## Architecture

  The linting engine uses the unified language registry to:
  1. Detect languages from file paths
  2. Apply language-specific linting rules
  3. Enforce quality gates across all supported languages
  4. Detect AI-generated code patterns
  5. Check enterprise compliance rules

  ## Integration with Language Registry

  The linting engine is tightly integrated with parser_engine's language_registry:
  - Language detection uses registry file extension mappings
  - Linting rules are language-family specific (via registry)
  - Quality thresholds are enforced uniformly across all languages
  - Custom rules can be added per language or language family

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.LintingEngine",
    "type": "wrapper",
    "purpose": "Elixir NIF wrapper for Rust linting engine with language registry integration",
    "layer": "code_quality",
    "pattern": "native_extension",
    "language_registry_integration": true
  }
  ```
  """

  require Logger

  # NIF function declarations
  def native do
    :erlang.nif_error(:not_loaded)
  end

  @doc """
  Get list of all supported languages from the language registry.

  Returns a list of language IDs that the linting engine can analyze.

  ## Examples

      iex> Singularity.LintingEngine.get_supported_languages()
      ["rust", "javascript", "typescript", "python", "go", "java", "cpp", "csharp",
       "elixir", "erlang", "gleam", "dart", "swift", "scala", "clojure", ...]

  ## Returns

  - `list()` - List of language ID strings
  """
  def get_supported_languages do
    case linting_get_supported_languages() do
      languages when is_list(languages) ->
        Logger.debug("[LintingEngine] Retrieved #{length(languages)} supported languages")
        languages

      error ->
        Logger.error("[LintingEngine] Failed to get supported languages", error: inspect(error))
        []
    end
  rescue
    error ->
      Logger.error("[LintingEngine] Exception getting supported languages",
        error: inspect(error)
      )

      []
  end

  @doc """
  Check if a specific language is supported by the linting engine.

  ## Parameters
  - `language_id` - Language identifier (e.g., "elixir", "rust", "python")

  ## Returns
  - `true` if the language is supported
  - `false` otherwise

  ## Examples

      iex> Singularity.LintingEngine.is_language_supported("elixir")
      true

      iex> Singularity.LintingEngine.is_language_supported("unknown")
      false
  """
  def is_language_supported(language_id) when is_binary(language_id) do
    case linting_is_language_supported(language_id) do
      result when is_boolean(result) ->
        Logger.debug("[LintingEngine] Language support check",
          language: language_id,
          supported: result
        )

        result

      error ->
        Logger.error("[LintingEngine] Failed to check language support",
          language: language_id,
          error: inspect(error)
        )

        false
    end
  rescue
    error ->
      Logger.error("[LintingEngine] Exception checking language support",
        language: language_id,
        error: inspect(error)
      )

      false
  end

  @doc """
  Get version information for the linting engine.

  Returns a string containing the version and build information.

  ## Examples

      iex> Singularity.LintingEngine.version()
      "linting_engine-0.1.0 (0.1.0)"
  """
  def version do
    case linting_version() do
      version when is_binary(version) ->
        Logger.debug("[LintingEngine] Version info", version: version)
        version

      error ->
        Logger.error("[LintingEngine] Failed to get version", error: inspect(error))
        "linting_engine-unknown"
    end
  rescue
    error ->
      Logger.error("[LintingEngine] Exception getting version", error: inspect(error))
      "linting_engine-unknown"
  end

  # ============================================================================
  # NIF Function Stubs
  # ============================================================================
  # These functions are implemented in Rust and compiled via Rustler NIF

  defp linting_get_supported_languages(), do: native()
  defp linting_is_language_supported(language_id), do: native()
  defp linting_version(), do: native()

  # ============================================================================
  # Helper Functions for Elixir Code
  # ============================================================================

  @doc """
  Check if a file extension is supported for linting.

  ## Parameters
  - `extension` - File extension (with or without dot, e.g., ".ex" or "ex")

  ## Returns
  - `true` if files with this extension can be linted
  - `false` otherwise

  ## Examples

      iex> Singularity.LintingEngine.is_extension_supported(".ex")
      true

      iex> Singularity.LintingEngine.is_extension_supported(".rs")
      true
  """
  def is_extension_supported(extension) when is_binary(extension) do
    # Remove leading dot if present
    ext = String.trim_leading(extension, ".")

    # Check against supported languages
    get_supported_languages()
    |> Enum.any?(fn lang ->
      # Map extension to language
      case ext do
        "ex" -> lang == "elixir"
        "exs" -> lang == "elixir"
        "erl" -> lang == "erlang"
        "hrl" -> lang == "erlang"
        "rs" -> lang == "rust"
        "py" -> lang == "python"
        "js" -> lang == "javascript"
        "ts" -> lang == "typescript"
        "tsx" -> lang == "typescript"
        "jsx" -> lang == "javascript"
        "go" -> lang == "go"
        "java" -> lang == "java"
        ext when ext in ["cpp", "cc", "cxx"] -> lang == "cpp"
        "c" -> lang == "c"
        "cs" -> lang == "csharp"
        "dart" -> lang == "dart"
        "swift" -> lang == "swift"
        "scala" -> lang == "scala"
        ext when ext in ["clj", "cljs"] -> lang == "clojure"
        "php" -> lang == "php"
        "rb" -> lang == "ruby"
        _ -> false
      end
    end)
  end

  @doc """
  Detect language from file extension.

  ## Parameters
  - `file_path` - File path (full path or just filename)

  ## Returns
  - `{:ok, language_id}` if language detected
  - `{:error, reason}` if not detected

  ## Examples

      iex> Singularity.LintingEngine.detect_language("example.ex")
      {:ok, "elixir"}

      iex> Singularity.LintingEngine.detect_language("unknown.xyz")
      {:error, "Unknown file extension"}
  """
  def detect_language(file_path) when is_binary(file_path) do
    extension =
      file_path
      |> Path.extname()
      |> String.trim_leading(".")
      |> String.downcase()

    case extension do
      "ex" -> {:ok, "elixir"}
      "exs" -> {:ok, "elixir"}
      "erl" -> {:ok, "erlang"}
      "hrl" -> {:ok, "erlang"}
      "rs" -> {:ok, "rust"}
      "py" -> {:ok, "python"}
      "js" -> {:ok, "javascript"}
      "ts" -> {:ok, "typescript"}
      "tsx" -> {:ok, "typescript"}
      "jsx" -> {:ok, "javascript"}
      "go" -> {:ok, "go"}
      "java" -> {:ok, "java"}
      "cpp" -> {:ok, "cpp"}
      "cc" -> {:ok, "cpp"}
      "cxx" -> {:ok, "cpp"}
      "c" -> {:ok, "c"}
      "cs" -> {:ok, "csharp"}
      "dart" -> {:ok, "dart"}
      "swift" -> {:ok, "swift"}
      "scala" -> {:ok, "scala"}
      "clj" -> {:ok, "clojure"}
      "cljs" -> {:ok, "clojure"}
      "php" -> {:ok, "php"}
      "rb" -> {:ok, "ruby"}
      _ -> {:error, "Unknown file extension: .#{extension}"}
    end
  end

  @doc """
  Get language family for a given language.

  Maps individual languages to their language families as defined in the registry.

  ## Parameters
  - `language_id` - Language identifier

  ## Returns
  - Language family name (string)
  - "unknown" if language not found

  ## Examples

      iex> Singularity.LintingEngine.get_language_family("elixir")
      "beam"

      iex> Singularity.LintingEngine.get_language_family("rust")
      "systems"
  """
  def get_language_family(language_id) when is_binary(language_id) do
    case language_id do
      "elixir" -> "beam"
      "erlang" -> "beam"
      "gleam" -> "beam"
      "rust" -> "systems"
      "c" -> "systems"
      "cpp" -> "systems"
      "go" -> "systems"
      "python" -> "scripting"
      "ruby" -> "scripting"
      "php" -> "scripting"
      "javascript" -> "web"
      "typescript" -> "web"
      "java" -> "jvm"
      "scala" -> "jvm"
      "kotlin" -> "jvm"
      "clojure" -> "jvm"
      "csharp" -> "dotnet"
      "dart" -> "mobile"
      "swift" -> "mobile"
      _ -> "unknown"
    end
  end
end
