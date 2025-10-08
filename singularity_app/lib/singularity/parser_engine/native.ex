defmodule Singularity.ParserEngine.Native do
  @moduledoc false

  def parse_file(_path), do: {:error, :nif_disabled}
  def parse_tree(_path), do: {:error, :nif_disabled}
end
