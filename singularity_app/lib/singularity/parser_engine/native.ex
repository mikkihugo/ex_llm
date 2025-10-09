defmodule Singularity.ParserEngine.Native do
  @moduledoc false

  # Load the Rust NIF that powers the parsing engine (use precompiled .so)
  use Rustler,
    otp_app: :singularity,
    crate: "parser_engine",
    skip_compilation?: true

  def parse_file(_path), do: :erlang.nif_error(:nif_not_loaded)
  def parse_tree(_path), do: :erlang.nif_error(:nif_not_loaded)
end

defmodule :parsing_engine do
  @moduledoc false

  @spec parse_file(String.t()) :: {:ok, map()} | {:error, term()}
  def parse_file(path), do: Singularity.ParserEngine.Native.parse_file(path)

  @spec parse_tree(String.t()) :: {:ok, list()} | {:error, term()}
  def parse_tree(path), do: Singularity.ParserEngine.Native.parse_tree(path)
end
