defmodule Singularity.CodeEngine do
  @moduledoc """
  Elixir wrapper for the Rust `code_quality_engine` NIF via `Singularity.CodeAnalyzer.Native`.

  Provides high-performance code parsing and analysis via Rust + tree-sitter.

  ## Functions

  - `parse_file/1` - Parse a single file and return structured data
  - `analyze_code/2` - Analyze code quality and patterns
  - `calculate_quality_metrics/2` - Calculate quality metrics
  - `supported_languages/0` - Get list of supported languages

  ## Example

      iex> CodeEngine.parse_file("lib/my_module.ex")
      {:ok, %Singularity.CodeAnalyzer.ParsedFile{
        file_path: "lib/my_module.ex",
        language: "elixir",
        ast_json: "{...}",
        symbols: ["MyModule", "my_function"],
        imports: ["Ecto.Schema"],
        exports: ["my_function/1"]
      }}
  """

  # The NIF is actually loaded via Singularity.CodeAnalyzer.Native (from rust/code_quality_engine)
  # We wrap it here for convenience
  # NOTE: Rust functions keep _nif suffix, so we call them with suffix but provide cleaner API

  defdelegate parse_file(file_path), to: Singularity.CodeAnalyzer.Native, as: :parse_file_nif

  defdelegate analyze_code(codebase_path, language),
    to: Singularity.CodeAnalyzer.Native,
    as: :analyze_code_nif

  defdelegate calculate_quality_metrics(code, language),
    to: Singularity.CodeAnalyzer.Native,
    as: :calculate_quality_metrics_nif

  defdelegate supported_languages(),
    to: Singularity.CodeAnalyzer.Native,
    as: :supported_languages

  defdelegate rca_supported_languages(),
    to: Singularity.CodeAnalyzer.Native,
    as: :rca_supported_languages

  defdelegate ast_grep_supported_languages(),
    to: Singularity.CodeAnalyzer.Native,
    as: :ast_grep_supported_languages

  defdelegate has_rca_support?(language),
    to: Singularity.CodeAnalyzer.Native,
    as: :has_rca_support

  defdelegate has_ast_grep_support?(language),
    to: Singularity.CodeAnalyzer.Native,
    as: :has_ast_grep_support
end
