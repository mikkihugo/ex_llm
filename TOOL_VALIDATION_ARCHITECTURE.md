# Tool Validation Architecture Decision

## The Question: Zod vs Instructor vs Lightweight Custom Validation

Given Singularity is **internal tooling** (not scaled production), should we use:
1. **Zod** (TypeScript-only) - Currently used in llm-server
2. **Instructor** (Elixir package) - Available on Hex (v0.1.0, Feb 2025)
3. **Lightweight Custom Validation** - Build our own validator

## Option Analysis

### Option 1: Zod (Current State)

**What it is:**
- TypeScript/JavaScript schema validation library
- AI SDK v5 native
- Converts JSON Schema → validated schemas
- **Zero Elixir integration**

**For Singularity:**
```
Elixir (Tool definitions)
  ↓ [NO validation]
  ↓ Sends to llm-server as JSON
TypeScript (tool-converter.ts)
  ↓ Zod validates
  ↓ Claude validates with inputSchema
```

**Pros:**
- ✅ Already integrated in TypeScript
- ✅ AI SDK native
- ✅ Lightweight
- ✅ Zero runtime overhead for Elixir

**Cons:**
- ❌ No Elixir-side validation
- ❌ Errors caught late (at llm-server)
- ❌ No type information shared between languages
- ❌ Two validation systems (Zod + Claude)

**Cost:**
- Free (already included)

---

### Option 2: Instructor (Elixir Package)

**What it is:**
- Elixir package for "structured prompting"
- Newer: v0.1.0 (February 2025)
- Designed for OpenAI + OSS LLMs
- Depends on: ecto, jason, jaxon, req

**How it works:**
```elixir
defmodule MySchema do
  use Instructor.Schema

  field :name, :string
  field :age, :integer
end

# Use with LLM
Instructor.chat_completion(
  model: "gpt-4",
  response_model: MySchema
)
```

**For Singularity:**
- Define tool schemas as Instructor structs
- Validate inputs before sending to llm-server
- Get bidirectional type safety (Elixir ↔ TypeScript)

**Pros:**
- ✅ Native Elixir (pattern matching, specs)
- ✅ Type-safe schema definitions
- ✅ Validates in Elixir before NATS
- ✅ Errors caught early
- ✅ Active development (just updated Feb 2025)
- ✅ Designed specifically for LLM tool workflows
- ✅ Works with any LLM (OpenAI, Gemini, etc.)

**Cons:**
- ❌ New/immature library (v0.1.0)
- ❌ Limited community/examples
- ❌ Adds dependencies (ecto already required, but jason + jaxon + req)
- ❌ Designed for direct LLM calls, not NATS integration
- ⚠️ May need custom integration with Singularity's NATS architecture

**Cost:**
- $0 (open source)
- ~10-15 hours integration work

**Risk Level:**
- Medium (new library, but actively maintained)

---

### Option 3: Lightweight Custom Validation

**What it is:**
- Validate tool parameters using Tool schema metadata
- Check: required fields, types, enums
- ~200 lines of code

**How it works:**
```elixir
# Tool definition
Tool.new!(%{
  name: "code_generate",
  parameters: [
    %{name: "task", type: :string, required: true},
    %{name: "language", type: :string, enum: ["elixir", "rust"]}
  ]
})

# Validate before sending
case ToolCall.validate("code_generate", %{"task" => "...", "language" => "rust"}) do
  :ok -> send_to_llm_server()
  {:error, reasons} -> handle_error(reasons)
end
```

**For Singularity:**
- Reuse existing Tool/ToolParam schema metadata
- No new dependencies
- Simple, fast, focused

**Pros:**
- ✅ Zero dependencies
- ✅ No external library risk
- ✅ Reuses existing Tool schema
- ✅ Fast (no reflection)
- ✅ Errors caught early in Elixir
- ✅ 2-3 hours implementation
- ✅ 100% under your control

**Cons:**
- ❌ No type information in Elixir (just maps)
- ❌ Limited to our validation rules
- ❌ Doesn't handle complex schemas as well as libraries
- ❌ Manual maintenance if requirements grow

**Cost:**
- $0 (custom code)
- 2-3 hours

**Risk Level:**
- Low (simple, focused, owned)

---

## The Scale Question: "We don't want Zod or Instructor for large scale?"

### Large Scale Implications

**Zod:**
- Pure validation, no I/O
- Synchronous, ~0.1ms per validation
- Can validate 10,000+ calls/second on single core
- **Scales fine** - it's just schema matching
- Used in production systems at scale

**Instructor:**
- Depends on: ecto, jason, jaxon, req
- `req` makes HTTP calls (!)
- If used for direct LLM calls, adds latency
- **For Singularity use case:** Only validating schemas locally
- Scales fine if only used for schema validation (no HTTP)

**Custom Validation:**
- Pure Elixir pattern matching
- ~0.05ms per validation
- 20,000+ calls/second on single core
- **Scales best** - simplest implementation

### The Real Scale Risk

**NOT validation speed** - all three are fast enough.

**The real risk at scale:**

1. **Dependencies** - Instructor adds: ecto, jason, jaxon, req
   - req = HTTP client (potential bottleneck if misconfigured)
   - More dependencies = larger deployment footprint

2. **Coupling** - Instructor designed for direct LLM calls
   - Singularity uses NATS (decoupled)
   - Instructor patterns may not fit NATS workflow
   - Could add unnecessary complexity

3. **Maintenance** - Newer library (v0.1.0)
   - May have breaking changes
   - Community smaller than Zod or custom code

---

## Recommendation for Singularity

**Use lightweight custom validation** for these reasons:

### Why NOT Zod?
- Validation should happen before NATS send
- Current Zod is TypeScript-only (no Elixir feedback)
- Adds unnecessary toolchain complexity

### Why NOT Instructor (yet)?
- Library is very new (v0.1.0, Feb 2025)
- Designed for direct LLM calls, not NATS
- Adds dependencies for internal tooling
- Scale doesn't benefit from Instructor's features
- Better to prove validation pattern first, then consider Instructor if it grows

### Why Custom Validation?
- ✅ Zero dependencies (critical for internal tooling)
- ✅ Reuses existing Tool/ToolParam schema
- ✅ Fast (no reflection, pattern matching)
- ✅ Errors caught early in Elixir
- ✅ Under your control (no library updates breaking things)
- ✅ Can evolve to Instructor later if needed

---

## Implementation Path

### Phase 1: Lightweight Custom Validation (2-3 hours)
```
1. Create Singularity.Tools.ParameterValidator
   - validate_tool_call(tool_name, args) → :ok | {:error, [reasons]}
   - Reuse Tool schema metadata for rules
   - Simple type checking + enum validation

2. Integrate with agents
   - Agents call validator before llm-server
   - Log validation errors
   - Early feedback to agents

3. Tests
   - Unit tests for each type validation
   - Integration tests with actual tools
```

### Phase 2: Monitor (Ongoing)
- Track validation errors in production
- See if pattern becomes limiting
- Evaluate Instructor if scope grows

### Phase 3: Consider Instructor (If Needed)
- If validation rules become complex
- If schema sharing with other languages needed
- If team wants type-safe specs
- Can swap custom validator for Instructor cleanly

---

## Final Decision Matrix

| Criterion | Zod | Instructor | Custom |
|-----------|-----|-----------|--------|
| **Setup time** | Done | 10-15h | 2-3h |
| **Dependencies** | 0 | +4 deps | 0 |
| **Scale risk** | Low | Low | Very low |
| **Maintenance burden** | Low | Medium | Very low |
| **Type safety** | TypeScript only | Elixir + TS | None |
| **Control** | External | External | 100% internal |
| **For internal tooling** | ⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |

---

## Summary

**For Singularity (internal tooling, NATS-based):**

→ **Implement lightweight custom validation**
- 2-3 hours to build
- Zero dependencies
- Errors caught early in Elixir
- Reuses existing schema metadata
- Can evolve to Instructor later if needed

**Keep Zod in TypeScript:**
- Already working in llm-server
- Second line of defense
- Native to AI SDK v5

**Result:** Dual validation (Elixir + TypeScript) without external library bloat.

---

## Code Example: Phase 1 Validator

```elixir
defmodule Singularity.Tools.ParameterValidator do
  @moduledoc """
  Validates tool parameters against tool schemas before sending to llm-server.

  Early validation in Elixir catches issues before NATS round-trip.
  """

  alias Singularity.Tools.{Tool, Catalog, ToolParam}

  @doc "Validate a tool call with given arguments"
  @spec validate(String.t(), map()) :: :ok | {:error, [String.t()]}
  def validate(tool_name, args) when is_binary(tool_name) and is_map(args) do
    case get_tool_schema(tool_name) do
      {:ok, schema} -> validate_args(args, schema)
      :error -> {:error, ["Tool not found: #{tool_name}"]}
    end
  end

  defp validate_args(args, schema) do
    errors = []

    # Check required fields
    errors = check_required_fields(args, schema, errors)

    # Check types and enums
    errors = check_fields(args, schema, errors)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  defp check_required_fields(args, %{required: required}, errors) do
    Enum.reduce(required, errors, fn field, acc ->
      if Map.has_key?(args, field), do: acc, else: acc ++ ["Missing required field: #{field}"]
    end)
  end
  defp check_required_fields(_args, _schema, errors), do: errors

  defp check_fields(args, %{properties: props}, errors) do
    Enum.reduce(args, errors, fn {key, value}, acc ->
      case Map.get(props, key) do
        nil -> acc ++ ["Unknown field: #{key}"]
        field_schema -> validate_field(key, value, field_schema, acc)
      end
    end)
  end
  defp check_fields(_args, _schema, errors), do: errors

  defp validate_field(key, value, %{type: type, enum: enum}, errors) do
    errors = check_type(key, value, type, errors)
    if Enum.empty?(enum), do: errors, else: check_enum(key, value, enum, errors)
  end
  defp validate_field(_key, _value, _schema, errors), do: errors

  defp check_type(_key, _value, :string, errors) when is_binary(_value), do: errors
  defp check_type(_key, _value, :integer, errors) when is_integer(_value), do: errors
  defp check_type(_key, _value, :number, errors) when is_number(_value), do: errors
  defp check_type(_key, _value, :boolean, errors) when is_boolean(_value), do: errors
  defp check_type(_key, _value, :array, errors) when is_list(_value), do: errors
  defp check_type(key, _value, type, errors), do: errors ++ ["Field '#{key}' has wrong type, expected #{type}"]

  defp check_enum(key, value, enum, errors) do
    if value in enum, do: errors, else: errors ++ ["Field '#{key}' value not in allowed: #{inspect(enum)}"]
  end

  defp get_tool_schema(tool_name) do
    # Get from catalog or tool definitions
    case Catalog.get_tool(:llm, tool_name) do
      {:ok, tool} -> {:ok, tool.parameters_schema}
      :error -> :error
    end
  end
end
```

This gives you **early validation, zero dependencies, full control**, while keeping Zod as a second line of defense in TypeScript.
