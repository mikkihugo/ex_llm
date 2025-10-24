defmodule CentralCloud.Engines.ParserEngine do
  @moduledoc """
  Parser Engine - Delegates to Singularity via NATS.

  CentralCloud doesn't compile Rust NIFs directly (compile: false in mix.exs).
  Instead, this module delegates parsing requests to Singularity
  via NATS, which has the compiled parser_engine NIF.
  """

  # Note: Rustler bindings disabled - NIFs compiled only in Singularity
  # use Rustler,
  #   otp_app: :centralcloud,
  #   crate: :parser_engine,
  #   path: "../../../../rust/parser_engine"

  require Logger

  @doc """
  Parse a single file using Rust Parser Engine.
  """
  def parse_file(file_path, opts \\ []) do
    language = Keyword.get(opts, :language, "auto")
    include_ast = Keyword.get(opts, :include_ast, true)

    request = %{
      "file_path" => file_path,
      "language" => language,
      "include_ast" => include_ast
    }

    case parser_engine_call("parse_file", request) do
      {:ok, results} ->
        Logger.debug("Parser engine parsed file",
          file: file_path,
          language: Map.get(results, "language", "unknown")
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Parser engine failed", reason: reason)
        {:error, reason}
    end
  end

  @doc """
  Parse entire codebase.
  """
  def parse_codebase(codebase_info, opts \\ []) do
    languages = Keyword.get(opts, :languages, ["elixir", "rust", "javascript"])
    include_ast = Keyword.get(opts, :include_ast, true)

    request = %{
      "codebase_info" => codebase_info,
      "languages" => languages,
      "include_ast" => include_ast
    }

    case parser_engine_call("parse_codebase", request) do
      {:ok, results} ->
        Logger.debug("Parser engine parsed codebase",
          files_parsed: length(Map.get(results, "parsed_files", []))
        )
        {:ok, results}

      {:error, reason} ->
        Logger.error("Parser engine failed", reason: reason)
        {:error, reason}
    end
  end

  # NIF function (loaded from shared Rust crate)
  defp parser_engine_call(_operation, _request), do: :erlang.nif_error(:nif_not_loaded)
end
