# Dynamic Tool Limits

**Date:** 2025-10-07
**Status:** ✅ Complete

## Summary

Tool limits are now **dynamic based on model context window size**, replacing the previous fixed limit of 6 tools.

## Motivation

Different AI models have vastly different context windows:
- **Tiny models** (Copilot): 12k tokens → Can handle 4 tools
- **Small models** (GPT-4): 128k tokens → Can handle 12 tools
- **Large models** (Claude): 200k tokens → Can handle 20 tools
- **Huge models** (Gemini 2.5 Pro): 2M tokens → Can handle 30 tools!

The old fixed limit of 6 tools wasted the capacity of large models.

## Implementation

### Tool Limit Tiers

Context Window → Max Tools mapping:

| Tier | Context Window | Max Tools | Score (1-10) | Examples |
|------|---------------|-----------|--------------|----------|
| **Tiny** | < 16k | 4 | 2 | Copilot (12k) |
| **Small** | 16k-64k | 8 | 4 | GPT-3.5 (16k) |
| **Medium** | 64k-200k | 12 | 6 | GPT-4 (128k) |
| **Large** | 200k-1M | 20 | 8 | Claude Sonnet (200k) |
| **Huge** | 1M+ | 30 | 10 | Gemini 2.5 Pro (2M) |

### Code Changes

**Elixir** ([lib/singularity/tools/tool_selector.ex](singularity_app/lib/singularity/tools/tool_selector.ex)):
```elixir
@tool_limits_by_context %{
  {0, 16_000} => 4,
  {16_000, 64_000} => 8,
  {64_000, 200_000} => 12,
  {200_000, 1_000_000} => 20,
  {1_000_000, :infinity} => 30
}

@default_max_tools 12  # Default for unknown models
```

**TypeScript** ([ai-server/src/model-registry.ts](ai-server/src/model-registry.ts)):
```typescript
export function calculateToolCapacityScore(contextWindow: number): number {
  if (contextWindow < 16_000) return 2;      // Tiny: 4 tools
  if (contextWindow < 64_000) return 4;      // Small: 8 tools
  if (contextWindow < 200_000) return 6;     // Medium: 12 tools
  if (contextWindow < 1_000_000) return 8;   // Large: 20 tools
  return 10;                                 // Huge: 30 tools
}

export function getMaxToolsForModel(contextWindow: number): number {
  if (contextWindow < 16_000) return 4;
  if (contextWindow < 64_000) return 8;
  if (contextWindow < 200_000) return 12;
  if (contextWindow < 1_000_000) return 20;
  return 30;
}
```

## Usage

### Automatic (Recommended)

Pass `model_context_window` in context:

```elixir
# Gemini 2.5 Pro (2M context)
{:ok, result} = ToolSelector.select_tools(
  "complex refactoring task",
  :code_developer,
  %{model_context_window: 2_000_000}
)

result.max_tools_allowed  # => 30
result.selected_tools     # => Up to 30 tools!
```

### Manual Override

Explicitly set `max_tools`:

```elixir
{:ok, result} = ToolSelector.select_tools(
  "simple task",
  :code_developer,
  %{max_tools: 5}  # Force limit
)

result.max_tools_allowed  # => 5
```

### Default (No Context)

Falls back to medium tier:

```elixir
{:ok, result} = ToolSelector.select_tools(
  "implement feature",
  :code_developer
)

result.max_tools_allowed  # => 12 (default)
```

## Model Capability Scoring

Added `tool_capacity` score to model capability matrix:

```typescript
interface ModelInfo {
  contextWindow: number;
  capabilityScores?: {
    code: number;          // 1-10: Code quality
    reasoning: number;     // 1-10: Analysis
    creativity: number;    // 1-10: Novel solutions
    speed: number;         // 1-10: Response latency
    cost: number;          // 1-10: Cost (10=FREE)
    tool_capacity: number; // 1-10: Max tools (NEW!)
  };
}
```

This allows **model selection based on tool capacity**:
- Need many tools? Choose Gemini 2.5 Pro (score: 10, 30 tools)
- Simple task? Choose Copilot (score: 2, 4 tools)

## Testing

Comprehensive tests verify dynamic limits:

```bash
nix develop . -c elixir test_dynamic_tools.exs
```

**Results:**
```
Test 1: Default (no model)       → 12 tools max ✅
Test 2: Tiny (12k)               → 4 tools max  ✅
Test 3: Small (128k)             → 12 tools max ✅
Test 4: Large (200k)             → 20 tools max ✅
Test 5: Huge (2M)                → 30 tools max ✅
Test 6: Manual override (max: 5) → 5 tools max  ✅
```

## Benefits

✅ **Maximizes model capacity** - Gemini 2.5 Pro can use 30 tools instead of 6
✅ **Prevents overload** - Copilot limited to 4 tools (respects 12k context)
✅ **Automatic scaling** - No manual configuration needed
✅ **Scoreable capability** - Can rank models by tool capacity
✅ **Manual override** - Can force limits when needed

## Migration

**Old code (fixed 6 tools):**
```elixir
{:ok, result} = ToolSelector.select_tools(task, role)
# Always got 6 tools max
```

**New code (dynamic):**
```elixir
# Automatically adapts to model
{:ok, result} = ToolSelector.select_tools(
  task,
  role,
  %{model_context_window: model.contextWindow}
)
# Gets 4-30 tools based on model capacity!
```

**Backwards compatible:** Old code still works, defaults to 12 tools.

## Future Improvements

1. **Learn optimal tool count per model** from agent success rates
2. **Dynamic adjustment based on task complexity** (simple tasks need fewer tools)
3. **Tool compatibility scoring** (some tools work better together)
4. **Model-specific tool preferences** (Claude prefers certain tools over others)

## Related Files

- [lib/singularity/tools/tool_selector.ex](singularity_app/lib/singularity/tools/tool_selector.ex) - Elixir implementation
- [ai-server/src/model-registry.ts](ai-server/src/model-registry.ts) - TypeScript scoring functions
- [test_dynamic_tools.exs](test_dynamic_tools.exs) - Test suite
- [TOOL_SELECTOR_CONSOLIDATION.md](TOOL_SELECTOR_CONSOLIDATION.md) - Original consolidation docs
