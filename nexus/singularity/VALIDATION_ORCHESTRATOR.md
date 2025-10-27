# Validation Orchestrator: Config-Driven Validation System

## Overview

This document explains Singularity's transformation from **scattered validators** to a **config-driven, unified validation system** using the Behavior + Orchestrator pattern.

**Old approach:** Multiple validators in different locations with inconsistent interfaces and no orchestration

**New approach:** Config-driven validator orchestration with all-must-pass semantics, priority ordering, and violation collection

## Architecture

### Core Components

```
┌──────────────────────────────────────────┐
│   Validator Behavior (~150 LOC)          │
│                                          │
│   Defines contract for all validators:   │
│   - validator_type() → :atom           │
│   - description() → String              │
│   - capabilities() → [String]           │
│   - validate(input, opts)               │
└──────────────────────────────────────────┘
           ▲                    ▲
        implements          implements
           │                    │
           │                    │
┌──────────┴────┐      ┌────────┴──────────┐
│  TypeChecker   │      │ SchemaValidator   │
│  (~75 LOC)     │      │   (~90 LOC)       │
│                │      │                   │
│ Priority: 10   │      │ Priority: 20      │
│ Type specs     │      │ Structure check   │
└────────────────┘      └───────────────────┘
           ▲                    ▲
           │          implements
           │                    │
           │         ┌──────────┘
           │         │
           └─────────┴──────────────────────┐
                                            │
                         ┌──────────────────┴──────────┐
                         │                             │
                    implements              implements
                         │                             │
            ┌────────────┴────────────┐   ┌───────────┴──────────┐
            │ SecurityValidator       │   │ (Future validators)  │
            │     (~85 LOC)           │   │                      │
            │                         │   │ Priority: 30+        │
            │ Priority: 15            │   │                      │
            │ Security policies       │   │ Custom validation    │
            └────────────────────────┘   └──────────────────────┘
           ▲
           │
           └─────────────────┬──────────────────────────┐
                             │                          │
                      discovered & loaded              controlled
                             │                          │
                             ▼                          ▼
                ┌─────────────────────────┐  ┌────────────────────┐
                │  Config (config.exs)    │  │ ValidationOrchestrator
                │                         │  │ (~250 LOC)
                │ :validators = {         │  │
                │   type_checker: %{      │  │ 1. Load validators
                │     module: ...,        │  │    from config
                │     enabled: true,      │  │
                │     priority: 10        │  │ 2. Run in priority
                │   },                    │  │    order
                │   ...                   │  │
                │ }                       │  │ 3. Collect all
                └─────────────────────────┘  │    violations
                                             │
                                             │ 4. Return :ok or
                                             │    {:error, violations}
                                             └────────────────────┘
```

## Configuration

### Location
`singularity/config/config.exs`

### Format
```elixir
config :singularity, :validators,
  type_checker: %{
    module: Singularity.Validators.TypeChecker,
    enabled: true,
    priority: 10,
    description: "Validates type specifications and type safety"
  },
  security_validator: %{
    module: Singularity.Validators.SecurityValidator,
    enabled: true,
    priority: 15,
    description: "Enforces security policies and access control"
  },
  schema_validator: %{
    module: Singularity.Validators.SchemaValidator,
    enabled: true,
    priority: 20,
    description: "Validates data structures against schema templates"
  }
```

### Configuration Keys

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `module` | Atom | ✅ | Module implementing `@behaviour Validator` |
| `enabled` | Boolean | ✅ | Whether validator is active in this environment |
| `priority` | Integer | ✅ | Execution order (ascending, lower = runs first) |
| `description` | String | ✓ | Human-readable description (optional in runtime) |

## How Validation Works

### All-Must-Pass Semantics

```
Input: code, data, or other input
   │
   ▼
Load enabled validators from config
Sort by priority (ascending)
   │
   ├─→ Run TypeChecker (priority 10)
   │   │
   │   ├─→ :ok → Continue
   │   │
   │   └─→ {:error, ["violation 1", ...]}
   │       Collect violations and continue
   │
   ├─→ Run SecurityValidator (priority 15)
   │   │
   │   ├─→ :ok → Continue
   │   │
   │   └─→ {:error, ["violation 2", ...]}
   │       Collect violations and continue
   │
   ├─→ Run SchemaValidator (priority 20)
   │   │
   │   ├─→ :ok → Continue
   │   │
   │   └─→ {:error, ["violation 3", ...]}
   │       Collect violations and continue
   │
   └─→ All validators run
       │
       ├─→ If no violations collected → Return :ok
       │
       └─→ If violations collected → Return {:error, [all violations]}
```

**Key Difference from FrameworkLearningOrchestrator:**
- FrameworkLearningOrchestrator: First-match-wins (stops on success)
- ValidationOrchestrator: All-must-pass (runs all, collects violations)

## Validator Implementations

### TypeChecker

**File:** `lib/singularity/validators/type_checker.ex`

**Purpose:** Validates type specifications and type safety

**Process:**
1. Check for @spec declarations in functions
2. Verify type annotation completeness
3. Check for proper type definitions

**Returns:**
- `:ok` if all type checks pass
- `{:error, ["violation 1", "violation 2", ...]}` with list of violations

**Configuration:**
```elixir
type_checker: %{
  module: Singularity.Validators.TypeChecker,
  enabled: true,
  priority: 10
}
```

**Capabilities:** `["type_safe", "ast_based", "fast", "spec_checking"]`

### SecurityValidator

**File:** `lib/singularity/validators/security_validator.ex`

**Purpose:** Enforces security policies and access control

**Process:**
1. Check for hardcoded secrets/credentials
2. Validate secure function usage
3. Detect dangerous patterns (eval, sudo, etc.)

**Returns:**
- `:ok` if no security issues found
- `{:error, ["hardcoded password found", ...]}` with violations

**Configuration:**
```elixir
security_validator: %{
  module: Singularity.Validators.SecurityValidator,
  enabled: true,
  priority: 15
}
```

**Capabilities:** `["security_enforcement", "policy_checking", "secret_detection"]`

### SchemaValidator

**File:** `lib/singularity/validators/schema_validator.ex`

**Purpose:** Validates data structures against schema templates

**Process:**
1. Check required fields present
2. Verify field types
3. Validate nested structures
4. Enforce constraints

**Returns:**
- `:ok` if schema validation passes
- `{:error, ["missing field: id", "wrong type for field: count", ...]}` with violations

**Configuration:**
```elixir
schema_validator: %{
  module: Singularity.Validators.SchemaValidator,
  enabled: true,
  priority: 20
}
```

**Capabilities:** `["schema_validation", "structure_checking", "constraint_enforcement"]`

## Usage Examples

### Basic Validation

```elixir
alias Singularity.Validation.ValidationOrchestrator

# Validate code with all enabled validators
case ValidationOrchestrator.validate(code, type: :code) do
  :ok ->
    IO.puts("Code passed all validations")

  {:error, violations} ->
    IO.puts("Validation failed:")
    Enum.each(violations, &IO.puts("  - #{&1}"))
end
```

### Targeted Validation

```elixir
# Skip security checks, only type and schema
case ValidationOrchestrator.validate(data, [
  type: :schema,
  validators: [:type_checker, :schema_validator]
]) do
  :ok -> IO.puts("Valid")
  {:error, v} -> IO.inspect(v, label: "Violations")
end
```

### Get Validator Information

```elixir
validators = ValidationOrchestrator.get_validators_info()

Enum.each(validators, fn v ->
  IO.puts("#{v.name}: #{v.description}")
  IO.puts("  Priority: #{v.priority}")
  IO.puts("  Capabilities: #{Enum.join(v.capabilities, ", ")}")
end)
```

## Adding New Validators

### Step-by-Step Guide

#### 1. Create Validator Module

Create file: `lib/singularity/validators/my_validator.ex`

```elixir
defmodule Singularity.Validators.MyValidator do
  @moduledoc """
  My Validator - Custom validation strategy.
  """

  @behaviour Singularity.Validation.Validator

  require Logger

  @impl Singularity.Validation.Validator
  def validator_type, do: :my_validator

  @impl Singularity.Validation.Validator
  def description do
    "Custom validation using my approach"
  end

  @impl Singularity.Validation.Validator
  def capabilities do
    ["custom", "specialized", "fast"]
  end

  @impl Singularity.Validation.Validator
  def validate(input, opts) do
    # Your validation logic here
    violations = []
    
    # Add violations as you find them
    # violations = violations ++ ["violation 1", "violation 2"]

    if Enum.empty?(violations) do
      :ok
    else
      {:error, violations}
    end
  end
end
```

#### 2. Update Configuration

Add to `config/config.exs`:

```elixir
config :singularity, :validators,
  my_validator: %{
    module: Singularity.Validators.MyValidator,
    enabled: true,
    priority: 25,  # After existing validators
    description: "Custom validation using my approach"
  }
```

#### 3. Test Validator

```bash
iex> ValidationOrchestrator.validate(test_data, type: :custom)
:ok
```

That's it! The orchestrator will automatically discover and use your new validator.

## Integration Points

### Current Integrations

The ValidationOrchestrator can be integrated into:

1. **Code Generation** - Validate generated code before storing
2. **Hot Reload** - Validate code before hot reload
3. **Template Import** - Validate templates before processing
4. **API Handlers** - Validate incoming requests
5. **Mix Tasks** - Validate during development tasks

### Example Integration

```elixir
# In code generation
case ValidationOrchestrator.validate(generated_code, type: :code) do
  :ok ->
    store_code(generated_code)

  {:error, violations} ->
    IO.puts("Code generation produced invalid code:")
    Enum.each(violations, &IO.puts("  - #{&1}"))
    {:error, :invalid_generated_code}
end
```

## Performance Characteristics

### TypeChecker
- **Time:** < 50ms (regex + pattern matching)
- **Memory:** Minimal
- **Cost:** None

### SecurityValidator
- **Time:** < 100ms (pattern scanning)
- **Memory:** Minimal
- **Cost:** None

### SchemaValidator
- **Time:** < 50ms (map traversal)
- **Memory:** Minimal
- **Cost:** None

### Overall Strategy

All validators run (unlike SearchOrchestrator):
1. Fast execution (< 300ms total for all three)
2. Comprehensive validation (catches all issues)
3. All-must-pass semantic (ensures quality)

## Testing

### Unit Tests

Each validator has independent unit tests:

```bash
# Test TypeChecker
mix test test/singularity/validators/type_checker_test.exs

# Test SecurityValidator
mix test test/singularity/validators/security_validator_test.exs

# Test SchemaValidator
mix test test/singularity/validators/schema_validator_test.exs
```

### Integration Tests

```bash
# Test orchestrator with multiple validators
mix test test/singularity/validation/validation_orchestrator_test.exs
```

## Monitoring

### Logs

Validation runs are logged at multiple levels:

```
DEBUG: "Type checker: Starting validation"
WARNING: "Type checker: Found 2 violations"
ERROR: "Security validator returned error" reason: "timeout"
```

### Metrics (Future)

Track validator effectiveness:
- Success rate per validator
- Average time per validator
- Which violations are most common
- Which validators are most active

## Comparison: Old vs New

### Old (Scattered)

```elixir
# lib/singularity/hot_reload/code_validator.ex
CodeValidator.validate(code)

# lib/singularity/templates/validator.ex
Templates.Validator.validate(template)

# lib/singularity/tools/security_policy.ex
SecurityPolicy.validate_code_access(request)

# All different interfaces, no orchestration
```

### New (Config-Driven)

```elixir
# Single unified API
ValidationOrchestrator.validate(input, type: :code)

# All validators run automatically
# All-must-pass semantics
# Violations collected from all
# Priority-ordered execution
# Easy to add new validators
```

## FAQ

### Q: Can I disable a validator?

**A:** Yes, set `enabled: false` in config:

```elixir
security_validator: %{
  module: ...,
  enabled: false,  # Disabled
  priority: 15
}
```

### Q: Can I change execution order?

**A:** Yes, adjust priority values:

```elixir
# Run security first (priority 5), then type (priority 10)
security_validator: %{..., priority: 5},
type_checker: %{..., priority: 10}
```

### Q: Why collect violations instead of fail-fast?

**A:** To catch ALL issues at once, not just the first one. Users see complete error list, not partial feedback.

### Q: What if a validator crashes?

**A:** The orchestrator catches exceptions, logs them, and continues:

```elixir
rescue
  e ->
    Logger.error("Validator execution failed", error: inspect(e))
    run_validators_recursive(rest, ...)  # Continue
```

### Q: Can validators have dependencies?

**A:** Not directly, but ordering via priority helps (run TypeChecker before SchemaValidator).

## Related Documentation

- [Validator Behavior](lib/singularity/validation/validator.ex) - Behavior contract
- [ValidationOrchestrator](lib/singularity/validation/validation_orchestrator.ex) - Orchestration engine
- [TypeChecker](lib/singularity/validators/type_checker.ex) - Type validation
- [SecurityValidator](lib/singularity/validators/security_validator.ex) - Security checks
- [SchemaValidator](lib/singularity/validators/schema_validator.ex) - Schema validation
- [VALIDATOR_CONSOLIDATION_REPORT.md](VALIDATOR_CONSOLIDATION_REPORT.md) - Full validator inventory

## Summary

The config-driven validation system provides:

1. **Unified Interface** - All validators implement same contract
2. **Orchestration** - All-must-pass with violation collection
3. **Configuration** - Enable/disable/reorder via config
4. **Extensibility** - Add new validators without code changes
5. **Consistency** - Same return types across all validators
6. **Reliability** - Error handling and exception recovery

This follows the proven **Behavior + Orchestrator** pattern used for SearchOrchestrator, JobOrchestrator, and FrameworkLearningOrchestrator, ensuring consistency across Singularity's internal tooling.
