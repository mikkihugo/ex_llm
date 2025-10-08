defmodule Singularity.ParserEngine.Native do
  @moduledoc false

  use Rustler,
    otp_app: :singularity,
    crate: "parser-engine",
    path: "native/parser-engine/engine"

  def parse_file(_path), do: :erlang.nif_error(:nif_not_loaded)
  def parse_tree(_path), do: :erlang.nif_error(:nif_not_loaded)
end
