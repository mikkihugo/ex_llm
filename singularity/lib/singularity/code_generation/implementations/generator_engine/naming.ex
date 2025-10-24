defmodule Singularity.CodeGeneration.Implementations.GeneratorEngine.Naming do
  @moduledoc false

  alias Singularity.CodeGeneration.Implementations.GeneratorEngine.Util

  @spec validate_naming_compliance(String.t(), atom()) :: boolean()
  def validate_naming_compliance(name, element_type) do
    case element_type do
      :module -> String.match?(name, ~r/^[A-Z][A-Za-z0-9_]*$/)
      :function -> String.match?(name, ~r/^[a-z_][a-z0-9_]*$/)
      :variable -> String.match?(name, ~r/^[a-z_][a-z0-9_]*$/)
      _ -> String.length(name) > 2
    end
  end

  @spec search_existing_names(String.t(), term(), atom()) :: {:ok, [map()]}
  def search_existing_names(query, _category, element_type) do
    {:ok, [%{name: Util.slug(query), element_type: element_type, description: "Stub result"}]}
  end

  @spec get_name_description(String.t()) :: {:ok, String.t()}
  def get_name_description(name), do: {:ok, "Stub description for #{name}"}

  @spec list_all_names(term()) :: {:ok, list()}
  def list_all_names(category), do: {:ok, [{"example_name", "Category: #{category}"}]}

  @spec get_language_specific_description(String.t(), String.t(), term()) :: {:ok, String.t()}
  def get_language_specific_description(name, language, _file_content),
    do: {:ok, "#{name} implemented in #{language}"}
end
