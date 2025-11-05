# Task-Type-Aware Model Variant Selection

## Overview

The SingularityLLM TaskRouter now supports intelligent routing to the best model variants for specific task types. This answers the architectural question: **"How do we find the best model variant for a specific task type?"**

Instead of treating all models equally, the router:

1. **Identifies preferred models** for each task type (architecture, coding, analysis, etc.)
2. **Finds variants** across providers (same base model, different context/pricing)
3. **Applies hard filters** (context window, required capabilities)
4. **Soft scores** variants (win rate, pricing, speed)
5. **Returns the best variant** that satisfies all constraints

## The Problem Statement

### Context: Model Variants Across Providers

The same base model exists across multiple providers with different characteristics:

**Example: GPT-4o**
- **OpenRouter**: $0.005 input, 128k context
- **GitHub Models**: FREE (subscription), 128k context
- **Azure OpenAI**: Variable pricing, different context

**Example: Claude Sonnet**
- **Anthropic Direct**: $3/$15 pricing, 200k context
- **OpenRouter**: $0.003/$0.015 pricing, 200k context
- **AWS Bedrock**: Different pricing, different context

**Example: Codex (Code-focused)**
- **OpenRouter**: $0.1/token (most affordable 1M context option)
- Only available through OpenRouter (not from OpenAI directly)

### The Decision Problem

Given a task type (architecture, coding, customer support), how do we automatically select:
1. Which **base models** are best for this task?
2. Which **variants** (across providers) of those models exist?
3. Which **variant** best satisfies constraints (context, capabilities)?
4. Which **variant** optimizes for our preference (win rate, cost, speed)?

## Solution: Task-Type-Aware Routing

### Preferred Models by Task Type

Each task type has a ranked list of preferred models:

```elixir
TaskRouter.preferred_models_for_task(:architecture)
# => ["claude-opus", "gpt-4o", "google-julius"]

TaskRouter.preferred_models_for_task(:coding)
# => ["codex", "claude-sonnet", "gpt-4o"]

TaskRouter.preferred_models_for_task(:customer_support)
# => ["gpt-4o-mini", "claude-haiku", "gemini-2-5-flash"]
```

**Why each preference:**

| Task Type | Preferred Models | Reason |
|-----------|-----------------|--------|
| `:architecture` | claude-opus, gpt-4o | Need deep reasoning, long context, system design skills |
| `:coding` | codex, claude-sonnet | Need code expertise, function calling, fast execution |
| `:refactoring` | claude-opus, claude-sonnet | Need detail, code understanding, style suggestions |
| `:analysis` | claude-opus, gpt-4o | Need analytical depth, code review skills |
| `:research` | claude-opus, gpt-4o | Need broad knowledge, reasoning capability |
| `:planning` | claude-sonnet, gpt-4o | Need organization, decomposition ability |
| `:chat` | claude-sonnet, gpt-4o-mini | Need conversational ability, speed |
| `:customer_support` | gpt-4o-mini, claude-haiku | Need speed, low cost, adequate capability |

### The Routing Algorithm

#### Step 1: Get Preferred Models
```elixir
preferred = TaskRouter.preferred_models_for_task(:coding)
# => ["codex", "claude-sonnet", "gpt-4o"]
```

#### Step 2: Find Variants
```elixir
# Gets all models matching preferred base models across all providers
variants = TaskRouter.model_variants("gpt-4o")
# => [
#   %{name: "gpt-4o", provider: :openrouter, context_window: 128_000, ...},
#   %{name: "gpt-4o", provider: :github_models, context_window: 128_000, ...},
# ]
```

#### Step 3: Apply Hard Filters
```
Constraints MUST be satisfied (AND logic):
- Context window ≥ min_context_tokens (if specified)
- Has ALL required_capabilities (if specified)

Remaining models: [variant1, variant2, ...]
```

#### Step 4: Soft Score & Rank
```
Score = win_rate × 0.7 + cost_factor × 0.3  (if prefer: :cost)
     OR win_rate × 0.7 + speed_factor × 0.3 (if prefer: :speed)
     OR win_rate                             (if prefer: :win_rate)

Ranked: [best_variant, second_best, ...]
```

#### Step 5: Return Best
```elixir
{:ok, :openrouter, "gpt-4o"}
```

## API Reference

### Primary Function: `route_with_variants/2`

```elixir
@spec route_with_variants(atom(), Keyword.t()) :: {:ok, atom(), String.t()} | {:error, atom()}

def route_with_variants(task_type, opts \\ [])
```

**Parameters:**
- `task_type` (atom, required): `:architecture`, `:coding`, `:refactoring`, `:analysis`, `:research`, `:planning`, `:chat`, `:customer_support`
- `opts` (Keyword, optional):
  - `:complexity_level` (atom) - `:simple`, `:medium` (default), `:complex` - adjusts win rates
  - `:min_context_tokens` (integer) - minimum context window required
  - `:required_capabilities` (list) - capabilities that MUST be present (e.g., `[:vision, :function_calling]`)
  - `:prefer` (atom) - scoring preference: `:win_rate` (default), `:cost`, `:speed`

**Returns:**
- `{:ok, provider, model}` on success
- `{:error, :no_suitable_variants}` if no models meet constraints
- `{:error, :no_models_available}` if catalog is empty

### Helper Functions

#### Get Preferred Models
```elixir
TaskRouter.preferred_models_for_task(:architecture)
# => ["claude-opus", "gpt-4o", "google-julius"]
```

Returns list of model names that excel at this task type.

#### Get Model Variants
```elixir
TaskRouter.model_variants("gpt-4o")
# => [
#   %{name: "gpt-4o", provider: :openrouter, context_window: 128_000, ...},
#   %{name: "gpt-4o", provider: :github_models, context_window: 128_000, ...},
# ]
```

Returns all available providers/variants of a model.

## Usage Examples

### Basic Usage: Task Type Only
```elixir
# Simple routing - uses default preferences
{:ok, provider, model} = TaskRouter.route_with_variants(:coding)
# => {:ok, :openrouter, "codex"}  or best available coding model
```

### With Context Requirement
```elixir
# Architecture task needing large context for enterprise systems
{:ok, provider, model} = TaskRouter.route_with_variants(:architecture,
  min_context_tokens: 256_000
)
# => {:ok, :openrouter, "claude-opus"}  (has 200k context)
```

### With Capability Requirement
```elixir
# Analysis task that needs vision for code screenshots
{:ok, provider, model} = TaskRouter.route_with_variants(:analysis,
  required_capabilities: [:vision]
)
# => {:ok, :openrouter, "gpt-4-turbo"}  (supports vision)
```

### With Cost Preference
```elixir
# Chat where cost is primary concern (but must still be good)
{:ok, provider, model} = TaskRouter.route_with_variants(:customer_support,
  prefer: :cost
)
# => {:ok, :github_models, "gpt-4o-mini"}  (free or cheap)
```

### Complex: Multiple Constraints
```elixir
# Architecture task requiring:
# - Enterprise-grade reasoning (complex)
# - Large context for big systems (256k minimum)
# - Vision for diagram analysis
# - Cost optimization
{:ok, provider, model} = TaskRouter.route_with_variants(:architecture,
  complexity_level: :complex,
  min_context_tokens: 256_000,
  required_capabilities: [:vision],
  prefer: :cost
)
# => {:ok, provider, model} matching all constraints
```

### With Error Handling
```elixir
case TaskRouter.route_with_variants(:coding, min_context_tokens: 1_000_000) do
  {:ok, provider, model} ->
    # Use the selected model
    SingularityLLM.chat(provider, messages, model: model)

  {:error, :no_suitable_variants} ->
    # No models meet the constraints - try looser constraints
    TaskRouter.route_with_variants(:coding)

  {:error, :no_models_available} ->
    # Catalog empty - perhaps API is down
    handle_catalog_unavailable()
end
```

## Task Type Recommendations

### `:architecture` - System Design
Use when designing:
- Microservices architectures
- Database schemas
- Infrastructure planning
- API design
- Large system components

**Best for:** Deep reasoning, 200k+ context for big designs

```elixir
TaskRouter.route_with_variants(:architecture,
  min_context_tokens: 200_000,
  required_capabilities: [:vision]  # Show architecture diagrams
)
```

### `:coding` - Code Generation & Implementation
Use when:
- Generating new code
- Implementing features
- Writing functions/classes
- Debugging code issues

**Best for:** Code expertise, function calling

```elixir
TaskRouter.route_with_variants(:coding,
  complexity_level: :complex,
  required_capabilities: [:function_calling]
)
```

### `:refactoring` - Code Improvement
Use when:
- Improving existing code
- Optimizing performance
- Enhancing style/readability
- Reducing technical debt

**Best for:** Detailed code understanding

```elixir
TaskRouter.route_with_variants(:refactoring,
  required_capabilities: [:vision]  # Show code diff
)
```

### `:analysis` - Code Review & Debugging
Use when:
- Reviewing code quality
- Finding bugs
- Analyzing performance
- Root cause analysis

**Best for:** Analytical depth

```elixir
TaskRouter.route_with_variants(:analysis,
  required_capabilities: [:vision]  # Show error logs
)
```

### `:research` - Exploration & Learning
Use when:
- Exploring new technologies
- Learning about frameworks
- Researching solutions
- Finding alternatives

**Best for:** Broad knowledge, reasoning

```elixir
TaskRouter.route_with_variants(:research,
  complexity_level: :complex
)
```

### `:planning` - Strategy & Decomposition
Use when:
- Planning sprints
- Decomposing features
- Creating task lists
- Scheduling work

**Best for:** Organization, breaking down problems

```elixir
TaskRouter.route_with_variants(:planning)
```

### `:chat` - General Conversation
Use when:
- Answering questions
- General discussion
- Explaining concepts
- Interactive learning

**Best for:** Conversational ability, speed

```elixir
TaskRouter.route_with_variants(:chat,
  complexity_level: :simple,
  prefer: :speed  # Fast responses
)
```

### `:customer_support` - User-Facing Help
Use when:
- Helping customers
- Support tickets
- User guidance
- Answering FAQs

**Best for:** Speed, low cost, helpfulness

```elixir
TaskRouter.route_with_variants(:customer_support,
  prefer: :cost  # Optimize for affordability
)
```

## Hard Filters vs Soft Scoring

### Hard Filters (Must Have)
These are REQUIRED constraints. If no models meet them, routing fails:

```elixir
# Context window is HARD filter
:min_context_tokens => 256_000
# Model MUST have at least 256k context

# Capabilities are HARD filter
:required_capabilities => [:vision, :function_calling]
# Model MUST support BOTH vision AND function_calling
```

**Typical hard filters:**
- Context window: Required for large documents/codebases
- Vision: Needed for analyzing diagrams/screenshots
- Function calling: Needed for tool use / API integration

### Soft Scoring (Preference)
These rank models that already pass hard filters:

```elixir
:prefer => :cost          # Rank by cost_factor (cheap models first)
:prefer => :speed         # Rank by speed_factor (fast models first)
:prefer => :win_rate      # Rank by learned performance (default)
```

**Impact:** 30% of final score (70% is always win_rate)

## Implementation Details

### Task Type Preferences (Internal)
```elixir
defp task_type_preferences do
  %{
    :architecture => ["claude-opus", "gpt-4o", "google-julius"],
    :coding => ["codex", "claude-sonnet", "gpt-4o"],
    # ... more task types
  }
end
```

### Model Matching (Case Insensitive)
Models are matched by substring:
```elixir
# "gpt-4o" matches any of:
# - "gpt-4o"
# - "gpt-4o-mini"
# - "openrouter/gpt-4o"
# - "GPT-4O" (case insensitive)
```

### Capability Detection
```elixir
# Capabilities come from model metadata:
model.capabilities          # List field
model.vision               # Boolean field
model.image_input          # Alternative name for vision
model.function_calling     # Boolean field
model.streaming           # Boolean field
model.json_mode           # Boolean field
model.reasoning           # Boolean field
```

### Scoring Algorithm
```elixir
# Win rate from learned preferences
win_rate = 0.85

# Cost factor
cost_factor = 1.0 / (1.0 + avg_price)  # 0.9-1.0 range

# Final score depends on preference
case prefer do
  :cost -> win_rate * 0.7 + cost_factor * 0.3
  :speed -> win_rate * 0.7 + speed_factor * 0.3
  _ -> win_rate
end
```

## Testing

### Test Coverage: 34 Tests
- ✅ Task type preferences for all 8 task types
- ✅ Model variant finding and matching
- ✅ Hard filter enforcement (context window)
- ✅ Hard filter enforcement (capabilities)
- ✅ Soft scoring with different preferences
- ✅ Complex multi-constraint routing
- ✅ Error handling (no suitable variants)
- ✅ Type safety (correct return types)
- ✅ Edge cases (unrealistic constraints)

### Running Tests
```bash
mix test test/singularity_llm/routing/task_router_variants_test.exs
```

## Common Patterns

### Pattern 1: Cost-Optimized Routing
```elixir
def route_cost_optimized(task_type) do
  TaskRouter.route_with_variants(task_type, prefer: :cost)
end

route_cost_optimized(:chat)
# => Prefers cheapest capable model
```

### Pattern 2: Performance-Optimized
```elixir
def route_performance_optimized(task_type) do
  TaskRouter.route_with_variants(task_type, prefer: :speed)
end

route_performance_optimized(:coding)
# => Prefers fastest model for coding
```

### Pattern 3: Capability-Aware
```elixir
def route_with_capabilities(task_type, caps) do
  TaskRouter.route_with_variants(task_type, required_capabilities: caps)
end

route_with_capabilities(:analysis, [:vision, :function_calling])
# => Only models supporting both capabilities
```

### Pattern 4: Context-Aware
```elixir
def route_for_large_codebase(task_type, codebase_tokens) do
  TaskRouter.route_with_variants(task_type, min_context_tokens: codebase_tokens)
end

route_for_large_codebase(:refactoring, 200_000)
# => Only models with sufficient context
```

## Integration with Singularity

The variant routing integrates seamlessly with Singularity's agent system:

```elixir
# In SelfImprovingAgent or other agents:
def call_llm(task_type, complexity, opts \\ []) do
  with {:ok, provider, model} <- TaskRouter.route_with_variants(task_type, [
    complexity_level: complexity,
    prefer: :win_rate
  ] ++ opts),
       {:ok, response} <- SingularityLLM.chat(provider, messages, model: model) do
    {:ok, response}
  end
end
```

## Future Enhancements

Potential improvements for future versions:

1. **Dynamic Preference Learning**: Track which preferences users choose, adapt preferences
2. **Provider Fallback Chain**: If preferred provider unavailable, try next best
3. **Cost Budget Enforcement**: Hard filter on max acceptable cost
4. **Latency SLA**: Hard filter on maximum acceptable response time
5. **Model Deprecation Handling**: Automatically handle EOL models
6. **Custom Task Types**: Allow registration of custom task type preferences
7. **Provider-Specific Tuning**: Different preferences per provider

## Related Documentation

- [TaskRouter](./lib/singularity_llm/routing/task_router.ex) - Implementation
- [TaskMetrics](./lib/singularity_llm/routing/task_metrics.ex) - Win rate calculation
- [Model Catalog](./lib/singularity_llm/core/model_catalog.ex) - Model metadata
- [E2E Tests](./TEST_RESULTS_E2E.md) - Test results and coverage
