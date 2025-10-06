defmodule Singularity.UniversalParserNif do
  @moduledoc """
  NIF wrapper for the Rust universal parser framework.
  
  This module provides Elixir functions that call into the Rust universal parser
  via NIFs (Native Implemented Functions), enabling high-performance code parsing
  and analysis.
  
  ## Features
  
  - **Multi-language parsing** - 30+ programming languages
  - **High-performance** - Rust implementation with NIF integration
  - **Unified interface** - Consistent API across all languages
  - **Rich analysis** - AST, metrics, complexity, maintainability
  
  ## Usage
  
      # Initialize the universal parser
      {:ok, parser} = UniversalParserNif.init()
      
      # Analyze file content
      {:ok, result} = UniversalParserNif.analyze_content(parser, code, "lib/app.ex", "elixir")
      
      # Analyze file from filesystem
      {:ok, result} = UniversalParserNif.analyze_file(parser, "lib/app.ex", "elixir")
      
      # Get parser metadata
      {:ok, metadata} = UniversalParserNif.get_metadata(parser)
      
      # Get supported languages
      {:ok, languages} = UniversalParserNif.supported_languages(parser)
  """

  use Rustler, otp_app: :singularity, crate: :universal_parser

  # NIF functions
  def init(), do: error()
  def analyze_content(_parser, _content, _file_path, _language), do: error()
  def analyze_file(_parser, _file_path, _language), do: error()
  def get_metadata(_parser), do: error()
  def supported_languages(_parser), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end