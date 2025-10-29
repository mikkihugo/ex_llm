defmodule Singularity.Schemas.EctoSchemaToJsonSchemaGenerator do
  @moduledoc """
  Ecto Schema to JSON Schema Generator - Auto-generates JSON Schema (Draft 07) from Ecto embedded schemas.

  Works by introspecting Ecto schemas via `__schema__/1` and converting Ecto types to JSON Schema types.
  This eliminates manual JSON Schema definitions and keeps schemas in sync automatically.

  ## Purpose

  **What it does:** Converts any Ecto embedded schema module into a JSON Schema definition

  **Why it exists:** Provides automatic schema validation for YAML/JSON configs without maintaining
  separate schema definitions

  **Key differences:**
  - **ToolParam.to_schema/1**: Domain-specific for tool parameter schemas only
  - **EctoSchemaToJsonSchemaGenerator**: General-purpose for ANY Ecto schema module

  Both are complementary - use ToolParam for tool definitions, use this for configuration validation,
  agent schemas, workflow definitions, etc.

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Schemas.EctoSchemaToJsonSchemaGenerator",
    "purpose": "Auto-generate JSON Schema from Ecto schemas for config validation and API documentation",
    "role": "schema_generator",
    "layer": "schemas",
    "criticality": "MEDIUM",
    "prevents_duplicates": [
      "Manual JSON Schema definitions",
      "Separate schema validation code",
      "Schema drift between Ecto and JSON Schema"
    ],
    "relationships": {
      "uses": ["Ecto.Schema introspection"],
      "generates": ["JSON Schema Draft 07"],
      "complements": ["Singularity.Schemas.Tools.ToolParam.to_schema/1"]
    }
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph LR
    A[Ecto Schema Module] -->|introspect __schema__/1| B[EctoSchemaToJsonSchemaGenerator]
    B -->|generate| C[JSON Schema Draft 07]
    C -->|validate| D[YAML/JSON Config]
    C -->|document| E[API Documentation]
    
    F[ToolParam.to_schema/1] -.complementary.-> B
  ```

  ## Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Ecto.Schema
      function: __schema__/1
      purpose: Introspect schema fields and types
      critical: true

  called_by:
    - module: AgentConfigurationSchemaGenerator
      purpose: Generate agent config schemas
    - module: AgentCapability
      purpose: Validate capability definitions
    - module: AgentSpawner
      purpose: Validate agent spawn configs
  ```

  ## Anti-Patterns (Prevents Duplicates)

  - ❌ **DO NOT** manually write JSON Schema if you have an Ecto schema
  - ❌ **DO NOT** maintain separate schema definitions (causes drift)
  - ❌ **DO NOT** use this for ToolParam schemas (use ToolParam.to_schema/1)
  - ✅ **DO** use this for agent configs, workflow definitions, capability schemas
  - ✅ **DO** extend `ecto_type_to_json_type/3` for custom Ecto types

  ## Search Keywords

  `json schema`, `schema generation`, `ecto schema`, `config validation`, `yaml validation`, `schema introspection`, `automatic schema`

  ## Supported Ecto Types

  - `:string`, `:integer`, `:float`, `:boolean`
  - `{:array, type}` - Arrays of any type
  - `:map` - JSON objects
  - `Ecto.Enum` - Enums with values
  - `Ecto.Embedded` - Embedded schemas (nested objects/arrays)
  - `{:parameterized, Ecto.Embedded, ...}` - Parameterized embeds

  ## Anti-Patterns

  - ❌ DO NOT manually write JSON Schema if you have an Ecto schema
  - ❌ DO NOT skip virtual fields in required list (they're skipped automatically)
  - ✅ DO use this for configuration validation
  - ✅ DO extend `ecto_type_to_json_type/3` for custom types
  """

  @doc """
  Generate JSON Schema from a list of Ecto schema modules.

  Returns a JSON Schema map with `$schema` and `definitions` keys.

  ## Examples

      iex> EctoSchemaToJsonSchemaGenerator.generate([AgentCapability])
      %{
        "$schema" => "http://json-schema.org/draft-07/schema#",
        "definitions" => %{
          "AgentCapability" => %{
            "type" => "object",
            "properties" => %{...},
            "required" => [...]
          }
        }
      }
  """
  def generate(modules) when is_list(modules) do
    definitions =
      modules
      |> Enum.map(&schema/1)
      |> Map.new()

    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "definitions" => definitions
    }
  end

  @doc """
  Generate JSON Schema with top-level array validation.

  Validates that the top-level YAML/JSON is an array of the specified schema.

  ## Example

      # Validates: [{role: "...", ...}, ...]
      schema = EctoSchemaToJsonSchemaGenerator.require_list_of(
        EctoSchemaToJsonSchemaGenerator.generate([AgentCapability]),
        AgentCapability
      )
  """
  def require_list_of(schema, required_module) do
    module_name = module_name(required_module)

    requirements = %{
      "type" => "array",
      "items" => %{
        "$ref" => "#/definitions/#{module_name}"
      }
    }

    Map.merge(schema, requirements)
  end

  @doc """
  Generate JSON Schema for a single module.

  Returns `{module_name, schema_definition}` tuple.
  """
  def schema(module) do
    # Get all non-virtual fields
    fields = module.__schema__(:fields)
    virtual_fields = module.__schema__(:virtual_fields) || []

    # Convert fields to JSON Schema properties
    properties =
      fields
      |> Enum.reject(&(&1 in virtual_fields))
      |> Enum.map(&to_json_spec(module, &1))
      |> Enum.filter(& &1)
      |> Map.new()

    # Get embed definitions for nested schemas
    embeds = module.__schema__(:embeds) || []

    # Generate schemas for embedded modules recursively
    embed_definitions =
      embeds
      |> Enum.flat_map(fn embed_name ->
        embed_ref = module.__schema__(:embed, embed_name)
        [embed_ref.related]
      end)
      |> Enum.uniq()
      |> Enum.map(&schema/1)
      |> Map.new()

    # Required fields (all non-virtual fields by default)
    required_fields = Map.keys(properties)

    module_name = module_name(module)

    schema_def = %{
      "type" => "object",
      "properties" => properties,
      "required" => required_fields,
      "additionalProperties" => false
    }

    # Merge in nested definitions if any
    definitions = if map_size(embed_definitions) > 0, do: embed_definitions, else: %{}

    {module_name, schema_def |> Map.put("definitions", definitions)}
  end

  # Convert a single field to JSON Schema property spec
  defp to_json_spec(module, field) do
    ecto_type = ecto_type(module, field)
    json_type = ecto_type_to_json_type(module, field, ecto_type)

    if json_type do
      {"#{field}", json_type}
    else
      nil
    end
  end

  # Get Ecto type for a field
  defp ecto_type(module, field) do
    module.__schema__(:type, field)
  end

  # Convert Ecto type to JSON Schema type
  defp ecto_type_to_json_type(_module, _field, :string), do: %{"type" => "string"}
  defp ecto_type_to_json_type(_module, _field, :integer), do: %{"type" => "integer"}
  defp ecto_type_to_json_type(_module, _field, :float), do: %{"type" => "number"}
  defp ecto_type_to_json_type(_module, _field, :boolean), do: %{"type" => "boolean"}
  defp ecto_type_to_json_type(_module, _field, :map), do: %{"type" => "object"}

  # Arrays
  defp ecto_type_to_json_type(_module, _field, {:array, item_type}) do
    item_schema = simple_type_to_json_type(item_type)
    %{"type" => "array", "items" => item_schema}
  end

  # Ecto.Enum - extract values
  defp ecto_type_to_json_type(_module, _field, {:parameterized, Ecto.Enum, enum_opts}) do
    values = enum_opts[:values] || []
    %{"type" => "string", "enum" => Enum.map(values, &Atom.to_string/1)}
  end

  # Embedded schemas (nested objects)
  defp ecto_type_to_json_type(_module, _field, {:parameterized, Ecto.Embedded, ecto_embedded}) do
    embedded_module = ecto_embedded.related
    cardinality = ecto_embedded.cardinality

    embedded_name = module_name(embedded_module)

    case cardinality do
      :one ->
        %{"$ref" => "#/definitions/#{embedded_name}"}

      :many ->
        %{
          "type" => "array",
          "items" => %{"$ref" => "#/definitions/#{embedded_name}"}
        }
    end
  end

  # Default: treat as string if unknown
  defp ecto_type_to_json_type(_module, _field, _unknown_type) do
    %{"type" => "string"}
  end

  # Helper for simple types in arrays
  defp simple_type_to_json_type(:string), do: %{"type" => "string"}
  defp simple_type_to_json_type(:integer), do: %{"type" => "integer"}
  defp simple_type_to_json_type(:float), do: %{"type" => "number"}
  defp simple_type_to_json_type(:boolean), do: %{"type" => "boolean"}
  defp simple_type_to_json_type(:map), do: %{"type" => "object"}
  defp simple_type_to_json_type(_), do: %{"type" => "string"}

  # Extract module name for JSON Schema references
  defp module_name(module) do
    module
    |> Atom.to_string()
    |> String.trim_leading("Elixir.")
    |> String.replace(".", "_")
  end
end
