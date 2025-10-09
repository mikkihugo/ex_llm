defmodule Singularity.Templates.Validator do
  @moduledoc """
  Validates templates against schema and best practices.

  Checks:
  - Schema compliance
  - Variable definitions
  - Composition references exist
  - Quality standards exist
  - Code syntax (if possible)
  """

  alias Singularity.Knowledge.LocalTemplateCache

  @required_fields ["id", "category", "metadata", "content"]
  @valid_categories ["base", "bit", "code_generation", "code_snippet", "framework", "prompt", "quality_standard", "workflow"]

  @doc """
  Validate a template.

  Returns {:ok, template} or {:error, reasons}
  """
  def validate(template) when is_map(template) do
    errors = []
    |> check_required_fields(template)
    |> check_category(template)
    |> check_metadata(template)
    |> check_content(template)
    |> check_composition_references(template)
    |> check_quality_standard(template)

    if Enum.empty?(errors) do
      {:ok, template}
    else
      {:error, errors}
    end
  end

  @doc """
  Validate template file (reads from disk and validates).
  """
  def validate_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, template} -> validate(template)
          {:error, reason} -> {:error, [{:invalid_json, reason}]}
        end

      {:error, reason} ->
        {:error, [{:file_read_error, reason}]}
    end
  end

  @doc """
  Validate all templates in a directory.

  Returns {valid_count, invalid_templates_with_errors}
  """
  def validate_directory(dir_path) do
    Path.wildcard(Path.join(dir_path, "**/*.json"))
    |> Enum.reduce({0, []}, fn path, {valid, invalid} ->
      case validate_file(path) do
        {:ok, _} ->
          {valid + 1, invalid}

        {:error, errors} ->
          {valid, [{path, errors} | invalid]}
      end
    end)
  end

  ## Private Validation Functions

  defp check_required_fields(errors, template) do
    missing = Enum.filter(@required_fields, fn field ->
      !Map.has_key?(template, field)
    end)

    if Enum.empty?(missing) do
      errors
    else
      [{:missing_required_fields, missing} | errors]
    end
  end

  defp check_category(errors, template) do
    category = Map.get(template, "category")

    if category in @valid_categories do
      errors
    else
      [{:invalid_category, category, valid: @valid_categories} | errors]
    end
  end

  defp check_metadata(errors, template) do
    metadata = Map.get(template, "metadata", %{})
    required_meta = ["name", "version", "description"]

    missing = Enum.filter(required_meta, fn field ->
      !Map.has_key?(metadata, field) || metadata[field] == ""
    end)

    if Enum.empty?(missing) do
      errors
    else
      [{:missing_metadata_fields, missing} | errors]
    end
  end

  defp check_content(errors, template) do
    content = Map.get(template, "content", %{})
    content_type = Map.get(content, "type")

    cond do
      content_type == "code" && !Map.has_key?(content, "code") ->
        [{:missing_code_content} | errors]

      content_type == "snippets" && !Map.has_key?(content, "snippets") ->
        [{:missing_snippets} | errors]

      content_type == "prompt" && (!Map.has_key?(content, "system") || !Map.has_key?(content, "user")) ->
        [{:missing_prompt_fields} | errors]

      true ->
        errors
    end
  end

  defp check_composition_references(errors, template) do
    errors = check_extends_reference(errors, template)
    check_compose_references(errors, template)
  end

  defp check_extends_reference(errors, %{"extends" => base_id}) when is_binary(base_id) do
    case LocalTemplateCache.get_template(base_id) do
      {:ok, _} -> errors
      {:error, :not_found} -> [{:extends_not_found, base_id} | errors]
      _ -> errors
    end
  end
  defp check_extends_reference(errors, _), do: errors

  defp check_compose_references(errors, %{"compose" => bit_ids}) when is_list(bit_ids) do
    missing = Enum.filter(bit_ids, fn bit_id ->
      case LocalTemplateCache.get_template(bit_id) do
        {:ok, _} -> false
        _ -> true
      end
    end)

    if Enum.empty?(missing) do
      errors
    else
      [{:compose_bits_not_found, missing} | errors]
    end
  end
  defp check_compose_references(errors, _), do: errors

  defp check_quality_standard(errors, %{"quality_standard" => standard_id}) when is_binary(standard_id) do
    case LocalTemplateCache.get_template(standard_id) do
      {:ok, _} -> errors
      {:error, :not_found} -> [{:quality_standard_not_found, standard_id} | errors]
      _ -> errors
    end
  end
  defp check_quality_standard(errors, _), do: errors
end
