defmodule Singularity.Analysis.FileReport do
  @moduledoc """
  Mirrors the Rust `FileAnalysis` struct – a single file plus its metadata and
  bookkeeping details.
  """

  alias Singularity.Analysis.Metadata

  @derive {Jason.Encoder, only: [:path, :metadata, :analyzed_at, :content_hash]}
  @type t :: %__MODULE__{
          path: String.t(),
          metadata: Metadata.t(),
          analyzed_at: non_neg_integer(),
          content_hash: String.t()
        }

  defstruct path: "",
            metadata: %Metadata{},
            analyzed_at: 0,
            content_hash: ""

  @doc "Build a new file analysis struct from a map produced by the analyzer."
  @spec new(map() | keyword()) :: t()
  def new(attrs \\ %{}) do
    attrs = Map.new(attrs)

    defaults = Map.from_struct(%__MODULE__{})

    defaults
    |> Map.merge(%{
      path: fetch_string(attrs, "path"),
      metadata: fetch_metadata(attrs),
      analyzed_at: fetch_integer(attrs, "analyzed_at"),
      content_hash: fetch_string(attrs, "content_hash")
    })
    |> then(&struct(__MODULE__, &1))
  end

  defp fetch_string(map, key) do
    map
    |> Map.get(key, Map.get(map, to_string(key), ""))
    |> case do
      nil -> ""
      value -> to_string(value)
    end
  end

  defp fetch_integer(map, key) do
    value = Map.get(map, key, Map.get(map, to_string(key), 0))

    cond do
      is_integer(value) ->
        value

      is_binary(value) ->
        case Integer.parse(value) do
          {int, _} -> int
          :error -> 0
        end

      true ->
        0
    end
  end

  defp fetch_metadata(map) do
    case Map.get(map, :metadata) || Map.get(map, "metadata") do
      %Metadata{} = metadata -> metadata
      metadata when is_map(metadata) -> Metadata.new(metadata)
      _ -> %Metadata{}
    end
  end
end
