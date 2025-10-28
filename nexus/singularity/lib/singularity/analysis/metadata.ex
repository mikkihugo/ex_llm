defmodule Singularity.Analysis.Metadata do
  @moduledoc """
  Pure Elixir representation of the Rust `CodebaseMetadata` structure from the
  analysis-suite.  The struct mirrors the fields emitted by the Singularity Code Analyzer so
  that ingestion jobs can persist results to Postgres and make them available to
  BEAM services.

  All numeric counters default to zero, while collections default to empty
  lists.  The `new/1` constructor accepts either atom or string keyed maps and
  normalises them into this struct.
  """

  @typedoc "Equivalent to analysis-suite's CodebaseMetadata"
  @type t :: %__MODULE__{
          path: String.t(),
          size: non_neg_integer(),
          lines: non_neg_integer(),
          language: String.t(),
          last_modified: non_neg_integer(),
          file_type: String.t(),
          cyclomatic_complexity: float(),
          cognitive_complexity: float(),
          maintainability_index: float(),
          nesting_depth: non_neg_integer(),
          function_count: non_neg_integer(),
          class_count: non_neg_integer(),
          struct_count: non_neg_integer(),
          enum_count: non_neg_integer(),
          trait_count: non_neg_integer(),
          interface_count: non_neg_integer(),
          total_lines: non_neg_integer(),
          code_lines: non_neg_integer(),
          comment_lines: non_neg_integer(),
          blank_lines: non_neg_integer(),
          halstead_vocabulary: non_neg_integer(),
          halstead_length: non_neg_integer(),
          halstead_volume: float(),
          halstead_difficulty: float(),
          halstead_effort: float(),
          pagerank_score: float(),
          centrality_score: float(),
          dependency_count: non_neg_integer(),
          dependent_count: non_neg_integer(),
          technical_debt_ratio: float(),
          code_smells_count: non_neg_integer(),
          duplication_percentage: float(),
          security_score: float(),
          vulnerability_count: non_neg_integer(),
          quality_score: float(),
          test_coverage: float(),
          documentation_coverage: float(),
          domains: [String.t()],
          patterns: [String.t()],
          features: [String.t()],
          business_context: [String.t()],
          performance_characteristics: [String.t()],
          security_characteristics: [String.t()],
          dependencies: [String.t()],
          related_files: [String.t()],
          imports: [String.t()],
          exports: [String.t()],
          functions: [String.t()],
          classes: [String.t()],
          structs: [String.t()],
          enums: [String.t()],
          traits: [String.t()]
        }

  @fields [
    :path,
    :size,
    :lines,
    :language,
    :last_modified,
    :file_type,
    :cyclomatic_complexity,
    :cognitive_complexity,
    :maintainability_index,
    :nesting_depth,
    :function_count,
    :class_count,
    :struct_count,
    :enum_count,
    :trait_count,
    :interface_count,
    :total_lines,
    :code_lines,
    :comment_lines,
    :blank_lines,
    :halstead_vocabulary,
    :halstead_length,
    :halstead_volume,
    :halstead_difficulty,
    :halstead_effort,
    :pagerank_score,
    :centrality_score,
    :dependency_count,
    :dependent_count,
    :technical_debt_ratio,
    :code_smells_count,
    :duplication_percentage,
    :security_score,
    :vulnerability_count,
    :quality_score,
    :test_coverage,
    :documentation_coverage,
    :domains,
    :patterns,
    :features,
    :business_context,
    :performance_characteristics,
    :security_characteristics,
    :dependencies,
    :related_files,
    :imports,
    :exports,
    :functions,
    :classes,
    :structs,
    :enums,
    :traits
  ]

  @derive {Jason.Encoder, only: @fields}
  defstruct path: "",
            size: 0,
            lines: 0,
            language: "unknown",
            last_modified: 0,
            file_type: "source",
            cyclomatic_complexity: 0.0,
            cognitive_complexity: 0.0,
            maintainability_index: 0.0,
            nesting_depth: 0,
            function_count: 0,
            class_count: 0,
            struct_count: 0,
            enum_count: 0,
            trait_count: 0,
            interface_count: 0,
            total_lines: 0,
            code_lines: 0,
            comment_lines: 0,
            blank_lines: 0,
            halstead_vocabulary: 0,
            halstead_length: 0,
            halstead_volume: 0.0,
            halstead_difficulty: 0.0,
            halstead_effort: 0.0,
            pagerank_score: 0.0,
            centrality_score: 0.0,
            dependency_count: 0,
            dependent_count: 0,
            technical_debt_ratio: 0.0,
            code_smells_count: 0,
            duplication_percentage: 0.0,
            security_score: 0.0,
            vulnerability_count: 0,
            quality_score: 0.0,
            test_coverage: 0.0,
            documentation_coverage: 0.0,
            domains: [],
            patterns: [],
            features: [],
            business_context: [],
            performance_characteristics: [],
            security_characteristics: [],
            dependencies: [],
            related_files: [],
            imports: [],
            exports: [],
            functions: [],
            classes: [],
            structs: [],
            enums: [],
            traits: []

  @doc """
  Build a new metadata struct from a map. Accepts camelCase, snake_case, or
  string keys produced by the Singularity Code Analyzer.
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs \\ %{}) do
    attrs
    |> normalise_keys()
    |> Map.take(@fields)
    |> Enum.reduce(%__MODULE__{}, fn {key, value}, acc ->
      Map.put(acc, key, convert_field(key, value))
    end)
    |> ensure_required()
  end

  defp ensure_required(%__MODULE__{path: path} = metadata) when path in [nil, ""] do
    %__MODULE__{metadata | path: ""}
  end

  defp ensure_required(metadata), do: metadata

  defp normalise_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {key, value} ->
      {key |> to_string() |> normalise_key() |> String.to_atom(), value}
    end)
  end

  defp normalise_keys(attrs) when is_list(attrs), do: attrs |> Enum.into(%{}) |> normalise_keys()

  defp normalise_key(key) do
    key
    |> String.replace("-", "_")
    |> Macro.underscore()
  end

  defp convert_field(field, value)
       when field in [
              :domains,
              :patterns,
              :features,
              :business_context,
              :performance_characteristics,
              :security_characteristics,
              :dependencies,
              :related_files,
              :imports,
              :exports,
              :functions,
              :classes,
              :structs,
              :enums,
              :traits
            ] do
    coerce_list(value)
  end

  defp convert_field(field, value)
       when field in [
              :size,
              :lines,
              :nesting_depth,
              :function_count,
              :class_count,
              :struct_count,
              :enum_count,
              :trait_count,
              :interface_count,
              :total_lines,
              :code_lines,
              :comment_lines,
              :blank_lines,
              :halstead_vocabulary,
              :halstead_length,
              :dependency_count,
              :dependent_count,
              :code_smells_count,
              :vulnerability_count
            ] do
    coerce_integer(value)
  end

  defp convert_field(field, value)
       when field in [
              :cyclomatic_complexity,
              :cognitive_complexity,
              :maintainability_index,
              :halstead_volume,
              :halstead_difficulty,
              :halstead_effort,
              :pagerank_score,
              :centrality_score,
              :technical_debt_ratio,
              :duplication_percentage,
              :security_score,
              :quality_score,
              :test_coverage,
              :documentation_coverage
            ] do
    coerce_float(value)
  end

  defp convert_field(:last_modified, value), do: coerce_integer(value)
  defp convert_field(_field, value), do: value

  defp coerce_integer(nil), do: 0
  defp coerce_integer(value) when is_integer(value), do: value

  defp coerce_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end

  defp coerce_integer(value) when is_float(value), do: trunc(value)
  defp coerce_integer(_), do: 0

  defp coerce_float(nil), do: 0.0
  defp coerce_float(value) when is_float(value), do: value
  defp coerce_float(value) when is_integer(value), do: value * 1.0

  defp coerce_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp coerce_float(_), do: 0.0

  defp coerce_list(nil), do: []

  defp coerce_list(list) when is_list(list), do: list

  defp coerce_list(value) when is_binary(value) do
    # Try to parse as JSON array first
    case Jason.decode(value) do
      {:ok, decoded} when is_list(decoded) -> decoded
      _ -> [value]
    end
  end

  defp coerce_list(value) when is_atom(value), do: [Atom.to_string(value)]

  defp coerce_list(value) when is_number(value), do: [value]

  defp coerce_list(value) when is_map(value) do
    # Convert map to list of key-value pairs
    value
    |> Map.to_list()
    |> Enum.map(fn {k, v} -> %{key: k, value: v} end)
  end

  defp coerce_list(value), do: [value]
end
