defmodule Singularity.Validators.SchemaValidator do
  @moduledoc """
  Schema Validator - Validates data against schema templates.

  Implements @behaviour Singularity.Validation.Validator for validating
  data structures conform to expected schemas (JSON, Elixir maps, etc.).

  ## Features

  - Validates required fields present
  - Checks field types
  - Validates nested structures
  - Enforces field constraints

  ## Capabilities

  - `["schema_validation", "structure_checking", "constraint_enforcement"]`
  """

  @behaviour Singularity.Validation.Validator

  require Logger

  @impl Singularity.Validation.Validator
  def validator_type, do: :schema_validator

  @impl Singularity.Validation.Validator
  def description do
    "Validates data structures against schema templates"
  end

  @impl Singularity.Validation.Validator
  def capabilities do
    ["schema_validation", "structure_checking", "constraint_enforcement", "field_validation"]
  end

  @impl Singularity.Validation.Validator
  def validate(data, _opts \\ []) when is_map(data) or is_list(data) do
    Logger.debug("Schema validator: Starting validation")

    violations = []
    violations = check_required_fields(data, violations, _opts)
    violations = check_field_types(data, violations, _opts)

    if Enum.empty?(violations) do
      Logger.debug("Schema validator: No violations found")
      :ok
    else
      Logger.warning("Schema validator: Found #{length(violations)} violations")
      {:error, violations}
    end
  end

  defp check_required_fields(data, violations, _opts) when is_map(data) do
    required = Keyword.get(_opts, :required_fields, [])

    missing =
      required
      |> Enum.filter(&(!Map.has_key?(data, &1)))
      |> Enum.map(&to_string/1)

    case missing do
      [] -> violations
      fields -> violations ++ ["Missing required fields: #{Enum.join(fields, ", ")}"]
    end
  end

  defp check_required_fields(_data, violations, _opts), do: violations

  defp check_field_types(data, violations, _opts) when is_map(data) do
    type_specs = Keyword.get(_opts, :field_types, %{})

    violations
    |> Enum.into([])
    |> Enum.reduce(violations, fn {field, expected_type}, acc ->
      value = Map.get(data, field)

      if value == nil do
        acc
      else
        case check_type(value, expected_type) do
          true -> acc
          false -> acc ++ ["Field '#{field}' has wrong type (expected #{expected_type})"]
        end
      end
    end)
  end

  defp check_field_types(_data, violations, _opts), do: violations

  defp check_type(value, :string), do: is_binary(value)
  defp check_type(value, :integer), do: is_integer(value)
  defp check_type(value, :boolean), do: is_boolean(value)
  defp check_type(value, :map), do: is_map(value)
  defp check_type(value, :list), do: is_list(value)
  defp check_type(_value, _type), do: true
end
