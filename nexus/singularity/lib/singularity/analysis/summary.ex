defmodule Singularity.Analysis.Summary do
  @moduledoc """
  Summary view equivalent to the Rust `CodebaseAnalysis` struct.  Stores a map
  of file analyses plus aggregate statistics for the analysed repository.
  """

  alias Singularity.Analysis.FileReport

  @derive {Jason.Encoder,
           only: [
             :files,
             :total_files,
             :total_lines,
             :total_functions,
             :total_classes,
             :languages,
             :analyzed_at
           ]}
  @type t :: %__MODULE__{
          files: %{optional(String.t()) => FileReport.t()},
          total_files: non_neg_integer(),
          total_lines: non_neg_integer(),
          total_functions: non_neg_integer(),
          total_classes: non_neg_integer(),
          languages: %{optional(String.t()) => non_neg_integer()},
          analyzed_at: non_neg_integer()
        }

  defstruct files: %{},
            total_files: 0,
            total_lines: 0,
            total_functions: 0,
            total_classes: 0,
            languages: %{},
            analyzed_at: 0

  @doc "Build an analysis summary from a map produced by the Rust analyzer."
  @spec new(map() | keyword()) :: t()
  def new(attrs \\ %{}) do
    attrs = Map.new(attrs)

    base = Map.from_struct(%__MODULE__{})

    data =
      base
      |> Map.merge(%{
        files: build_files(attrs),
        total_files: fetch_integer_field(attrs, "total_files"),
        total_lines: fetch_integer_field(attrs, "total_lines"),
        total_functions: fetch_integer_field(attrs, "total_functions"),
        total_classes: fetch_integer_field(attrs, "total_classes"),
        languages: fetch_map(attrs, "languages"),
        analyzed_at: fetch_integer_field(attrs, "analyzed_at")
      })

    struct(__MODULE__, data)
  end

  defp build_files(attrs) do
    case Map.get(attrs, :files) || Map.get(attrs, "files") do
      files when is_map(files) ->
        Map.new(files, fn {path, info} ->
          {to_string(path), FileReport.new(info)}
        end)

      _ ->
        %{}
    end
  end

  defp fetch_integer_field(map, key) do
    value = Map.get(map, key, Map.get(map, to_string(key), 0))
    coerce_integer(value)
  end

  defp fetch_map(map, key) do
    case Map.get(map, key) || Map.get(map, to_string(key)) do
      %{} = value ->
        Map.new(value, fn {k, v} -> {to_string(k), coerce_integer(v)} end)

      value when is_list(value) ->
        Map.new(value, fn
          {k, v} -> {to_string(k), coerce_integer(v)}
          other -> {to_string(other), 1}
        end)

      _ ->
        %{}
    end
  end

  defp coerce_integer(value) when is_integer(value), do: value

  defp coerce_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp coerce_integer(_), do: 0
end
