# Schema Generators - Documentation

## Overview

Two complementary schema generators for automatic JSON Schema generation and validation:

1. **`EctoSchemaToJsonSchemaGenerator`** - General-purpose Ecto schema → JSON Schema converter
2. **`AgentConfigurationSchemaGenerator`** - Agent-specific config validation

## Quick Reference

### Generate Schema from Ecto Module

```elixir
alias Singularity.Schemas.EctoSchemaToJsonSchemaGenerator

# Generate JSON Schema for any Ecto schema
schema = EctoSchemaToJsonSchemaGenerator.generate([
  Singularity.Agents.Coordination.AgentCapability
])
```

### Validate Agent Config

```elixir
alias Singularity.Agents.AgentConfigurationSchemaGenerator

# Validate before spawning
case AgentConfigurationSchemaGenerator.validate_agent_config(config) do
  :ok -> AgentSpawner.spawn(config)
  {:error, :invalid_config, errors} -> handle_errors(errors)
end
```

### Validate Capability Definition

```elixir
# Validate before registration
case AgentConfigurationSchemaGenerator.validate_capability(capability) do
  :ok -> CapabilityRegistry.register(:agent_name, capability)
  {:error, :invalid_capability, errors} -> handle_errors(errors)
end
```

## Integration Points

### ✅ Integrated

- **AgentSpawner.spawn/1** - Validates agent configs before spawning
- **CapabilityRegistry.register/2** - Validates capability definitions before registration

### 🔄 Usage Flow

```
Lua/YAML/JSON Config
  ↓
AgentConfigurationSchemaGenerator.validate_agent_config/1
  ↓ (uses)
EctoSchemaToJsonSchemaGenerator.generate/1
  ↓ (introspects)
Ecto Schema Module
  ↓ (validates)
ExJsonSchema.Validator.validate/2
  ↓
:ok or {:error, errors}
```

## Key Differences

| Feature | ToolParam.to_schema/1 | EctoSchemaToJsonSchemaGenerator |
|---------|----------------------|----------------------------------|
| **Scope** | Tool parameters only | Any Ecto schema |
| **Type** | Domain-specific | General-purpose |
| **Auto-introspection** | No (manual conversion) | Yes (via `__schema__/1`) |
| **Use Case** | Tool definitions | Config validation, agent schemas |

## Self-Documenting Names

- **`EctoSchemaToJsonSchemaGenerator`** - Clearly indicates: converts Ecto schemas to JSON Schema
- **`AgentConfigurationSchemaGenerator`** - Clearly indicates: generates schemas for agent configurations

Both names follow Singularity's self-documenting naming convention.
