defmodule Singularity.RustAnalyzer do
  @moduledoc """
  Rust Analyzer NIF - Direct bindings to Rust code analysis tools.

  This module loads the Rust NIF from `rust/code_engine` which provides:
  - Code parsing via tree-sitter (30+ languages)
  - Quality metrics calculation
  - Code analysis and pattern detection

  ## NIF Functions

  All functions return `{:ok, result}` on success or `{:error, reason}` on failure.

  ### Parsing
  - `parse_file_nif/1` - Parse a single file using tree-sitter
  - `supported_languages_nif/0` - Get list of supported languages

  ### Analysis
  - `analyze_code_nif/2` - Analyze code quality and patterns
  - `calculate_quality_metrics_nif/2` - Calculate quality metrics

  ### Knowledge (placeholder)
  - `load_asset_nif/1` - Load asset from local cache
  - `query_asset_nif/1` - Query asset from central service

  ## NIF Loading

  The NIF is loaded from `priv/native/libcode_engine.so` (compiled from rust/code_engine).
  If the NIF fails to load, functions will return `:nif_not_loaded` errors.

  ## Example

      iex> Singularity.RustAnalyzer.parse_file_nif("lib/my_module.ex")
      {:ok, %Singularity.RustAnalyzer.ParsedFile{
        file_path: "lib/my_module.ex",
        language: "elixir",
        ast_json: "...",
        symbols: ["MyModule"],
        imports: ["Ecto.Schema"],
        exports: []
      }}
  """

  use Rustler,
    otp_app: :singularity,
    crate: "code_engine",
    path: "../rust/code_engine"

  # Parsing NIFs
  # NOTE: Elixir function names MUST match Rust function names exactly (including _nif suffix)
  def parse_file_nif(_file_path), do: :erlang.nif_error(:nif_not_loaded)
  def supported_languages_nif(), do: :erlang.nif_error(:nif_not_loaded)

  # Analysis NIFs
  def analyze_code_nif(_codebase_path, _language), do: :erlang.nif_error(:nif_not_loaded)
  def calculate_quality_metrics_nif(_code, _language), do: :erlang.nif_error(:nif_not_loaded)

  # Knowledge NIFs (placeholder)
  def load_asset_nif(_id), do: :erlang.nif_error(:nif_not_loaded)
  def query_asset_nif(_id), do: :erlang.nif_error(:nif_not_loaded)
end
