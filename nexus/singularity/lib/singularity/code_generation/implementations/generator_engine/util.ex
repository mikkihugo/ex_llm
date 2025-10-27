defmodule Singularity.CodeGeneration.Implementations.GeneratorEngine.Util do
  @moduledoc false

  @spec slug(String.t()) :: String.t()
  def slug(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
    |> case do
      "" -> "generated"
      other -> other
    end
  end

  @spec extension(String.t() | nil) :: String.t()
  def extension(language) do
    case String.downcase(language || "") do
      "elixir" -> "ex"
      "typescript" -> "ts"
      "python" -> "py"
      _ -> "txt"
    end
  end
end
