defmodule Centralcloud.Engines.ParserEngine do
  @moduledoc """
  Parser Engine - Delegates to Singularity via NATS.

  This module provides a simple interface to Singularity's Rust code
  parsing engine via NATS messaging. CentralCloud does not compile its own
  copy of the Rust NIF; instead it uses the Singularity instance's compiled
  engines through the SharedEngineService.
  """

  alias Centralcloud.Engines.SharedEngineService
  require Logger

  @doc """
  Parse a single file using Singularity's Rust Parser Engine.

  Delegates to Singularity via NATS for the actual computation.
  """
  def parse_file(file_path, opts \\ []) do
    language = Keyword.get(opts, :language, "auto")
    include_ast = Keyword.get(opts, :include_ast, true)

    request = %{
      "file_path" => file_path,
      "language" => language,
      "include_ast" => include_ast
    }

    SharedEngineService.call_parser_engine("parse_file", request, timeout: 30_000)
  end

  @doc """
  Parse entire codebase.

  Delegates to Singularity via NATS for the actual computation.
  """
  def parse_codebase(codebase_info, opts \\ []) do
    languages = Keyword.get(opts, :languages, ["elixir", "rust", "javascript"])
    include_ast = Keyword.get(opts, :include_ast, true)

    request = %{
      "codebase_info" => codebase_info,
      "languages" => languages,
      "include_ast" => include_ast
    }

    SharedEngineService.call_parser_engine("parse_codebase", request, timeout: 30_000)
  end
end
