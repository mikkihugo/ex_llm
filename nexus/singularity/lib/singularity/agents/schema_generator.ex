defmodule Singularity.Agents.AgentConfigurationSchemaGenerator do
  @moduledoc """
  Agent Configuration Schema Generator - Generates JSON Schema for agent-related configurations.

  Convenience wrapper around `Singularity.Schemas.EctoSchemaToJsonSchemaGenerator` specifically
  for agent schemas. Provides pre-built schemas for common agent configuration patterns.

  ## Purpose

  **What it does:** Generates JSON Schema definitions for agent configurations and capabilities

  **Why it exists:** Ensures agent configs (from Lua, YAML, JSON) conform to expected schemas
  before spawning agents or registering capabilities

  **Integration:** Used by AgentSpawner and CapabilityRegistry for config validation

  ## Module Identity (JSON)

  ```json
  {
    "module": "Singularity.Agents.AgentConfigurationSchemaGenerator",
    "purpose": "Generate JSON Schema for agent configurations and validate agent configs",
    "role": "agent_schema_generator",
    "layer": "agents",
    "criticality": "MEDIUM",
    "prevents_duplicates": [
      "Manual agent config schemas",
      "Duplicate validation logic",
      "Config validation scattered across modules"
    ],
    "relationships": {
      "uses": ["Singularity.Schemas.EctoSchemaToJsonSchemaGenerator"],
      "used_by": ["AgentSpawner", "CapabilityRegistry"],
      "generates_schemas_for": ["AgentCapability", "AgentConfig"]
    }
  }
  ```

  ## Architecture Diagram (Mermaid)

  ```mermaid
  graph LR
    A[AgentSpawner] -->|validate config| B[AgentConfigurationSchemaGenerator]
    C[CapabilityRegistry] -->|validate capability| B
    B -->|uses| D[EctoSchemaToJsonSchemaGenerator]
    D -->|introspects| E[AgentCapability Schema]
    B -->|returns| F[JSON Schema]
    F -->|validates| G[YAML/JSON/Lua Config]
  ```

  ## Call Graph (YAML)

  ```yaml
  calls_out:
    - module: EctoSchemaToJsonSchemaGenerator
      functions: [generate/1, require_list_of/2]
      purpose: Generate schemas from Ecto modules
      critical: true

  called_by:
    - module: AgentSpawner
      function: spawn/1
      purpose: Validate agent config before spawning
    - module: CapabilityRegistry
      function: register/2
      purpose: Validate capability definition
  ```

  ## Anti-Patterns (Prevents Duplicates)

  - ? **DO NOT** manually define agent config schemas - use this generator
  - ? **DO NOT** validate configs without schemas - always validate
  - ? **DO NOT** duplicate schema generation logic
  - ? **DO** use this for all agent config validation
  - ? **DO** extend with new schema types as needed

  ## Search Keywords

  `agent schema`, `agent config validation`, `agent capability schema`, `agent spawn validation`, `configuration schema`

  ## Usage Examples

      alias Singularity.Agents.AgentConfigurationSchemaGenerator

      # Generate schema for agent capability
      schema = AgentConfigurationSchemaGenerator.agent_capability_schema()

      # Generate schema for agent configuration (Lua format)
      schema = AgentConfigurationSchemaGenerator.agent_config_schema()

      # Validate agent config before spawning
      case ExJsonSchema.Validator.validate(schema, agent_config) do
        :ok -> AgentSpawner.spawn(agent_config)
        {:error, errors} -> {:error, {:invalid_config, errors}}
      end
  """

  alias Singularity.Schemas.EctoSchemaToJsonSchemaGenerator

  @doc """
  Generate JSON Schema for AgentCapability embedded schema.

  Validates agent capability definitions with all fields:
  - role, domains, input_types, output_types
  - complexity_level, estimated_cost, availability
  - success_rate, preferred_model, tags, metadata

  Returns JSON Schema with `$schema` and `definitions` keys.

  ## Examples

      schema = AgentConfigurationSchemaGenerator.agent_capability_schema()
      # => %{"$schema" => "...", "definitions" => %{"AgentCapability" => {...}}}

      # Validate capability definition
      capability = %{
        "role" => "architect",
        "domains" => ["architecture"],
        "input_types" => ["code", "design"]
      }
      :ok = ExJsonSchema.Validator.validate(schema, capability)
  """
  def agent_capability_schema do
    EctoSchemaToJsonSchemaGenerator.generate([
      Singularity.Agents.Coordination.AgentCapability
    ])
  end

  @doc """
  Generate JSON Schema for agent configuration (Lua strategy config format).

  Validates agent spawn configurations from Lua scripts with structure:
  - `role` (required): Agent role string
  - `behavior_id` (optional): Behavior identifier
  - `config` (optional): Configuration map with:
    - `tools`: Array of tool names
    - `confidence_threshold`: Number between 0.0 and 1.0

  Returns JSON Schema that validates the structure used by AgentSpawner.spawn/1.

  ## Examples

      schema = AgentConfigurationSchemaGenerator.agent_config_schema()

      # Valid config
      config = %{
        "role" => "code_developer",
        "behavior_id" => "code-gen-v1",
        "config" => %{
          "tools" => ["read_file", "write_file"],
          "confidence_threshold" => 0.85
        }
      }
      :ok = ExJsonSchema.Validator.validate(schema, config)

      # Invalid config (missing required role)
      invalid = %{"behavior_id" => "test"}
      {:error, errors} = ExJsonSchema.Validator.validate(schema, invalid)
  """
  def agent_config_schema do
    # Agent config is a map with role, behavior_id, config
    %{
      "$schema" => "http://json-schema.org/draft-07/schema#",
      "type" => "object",
      "properties" => %{
        "role" => %{"type" => "string"},
        "behavior_id" => %{"type" => "string"},
        "config" => %{
          "type" => "object",
          "properties" => %{
            "tools" => %{
              "type" => "array",
              "items" => %{"type" => "string"}
            },
            "confidence_threshold" => %{"type" => "number", "minimum" => 0.0, "maximum" => 1.0}
          }
        }
      },
      "required" => ["role"]
    }
  end

  @doc """
  Generate JSON Schema for all agent-related schemas.

  Convenience function that generates schemas for all agent-related Ecto schemas
  in a single call. Currently includes AgentCapability; extend as needed.

  Returns unified JSON Schema with definitions for all agent schemas.

  ## Examples

      schema = AgentConfigurationSchemaGenerator.all_agent_schemas()
      # => %{"$schema" => "...", "definitions" => %{"AgentCapability" => {...}}}

      # Use specific definition
      capability_schema = schema["definitions"]["AgentCapability"]
  """
  def all_agent_schemas do
    EctoSchemaToJsonSchemaGenerator.generate([
      Singularity.Agents.Coordination.AgentCapability
    ])
  end

  @doc """
  Validate agent configuration against schema.

  Convenience wrapper that validates config and returns normalized error format.

  Returns:
  - `:ok` if config is valid
  - `{:error, :invalid_config, errors}` if validation fails

  ## Examples

      config = %{"role" => "architect", "config" => %{}}
      case AgentConfigurationSchemaGenerator.validate_agent_config(config) do
        :ok -> AgentSpawner.spawn(config)
        {:error, :invalid_config, errors} -> handle_validation_errors(errors)
      end
  """
  def validate_agent_config(config) when is_map(config) do
    if schema_validation_available?() do
      schema = agent_config_schema()

      case ExJsonSchema.Validator.validate(schema, config) do
        :ok -> :ok
        {:error, errors} -> {:error, :invalid_config, errors}
      end
    else
      # Validation unavailable - log warning but allow config through
      require Logger
      Logger.debug("Schema validation skipped - ExJsonSchema not available")
      :ok
    end
  end

  @doc """
  Validate agent capability definition against schema.

  Convenience wrapper for validating capability definitions before registration.

  Returns:
  - `:ok` if capability is valid (or validation unavailable)
  - `{:error, :invalid_capability, errors}` if validation fails

  ## Examples

      capability = %{
        "role" => "architect",
        "domains" => ["architecture"],
        "input_types" => ["code"]
      }
      case AgentConfigurationSchemaGenerator.validate_capability(capability) do
        :ok -> CapabilityRegistry.register(:architect, capability)
        {:error, :invalid_capability, errors} -> handle_errors(errors)
      end
  """
  def validate_capability(capability) when is_map(capability) do
    if schema_validation_available?() do
      schema = agent_capability_schema()

      case ExJsonSchema.Validator.validate(schema, capability) do
        :ok -> :ok
        {:error, errors} -> {:error, :invalid_capability, errors}
      end
    else
      require Logger
      Logger.debug("Schema validation skipped - ExJsonSchema not available")
      :ok
    end
  end

  # Check if ExJsonSchema is available at runtime
  defp schema_validation_available? do
    Code.ensure_loaded?(ExJsonSchema.Validator) and
      function_exported?(ExJsonSchema.Validator, :validate, 2)
  end

end
