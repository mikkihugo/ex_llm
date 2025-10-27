# CentralCloud Engines: Config-Driven Framework Learning

## Overview

This document explains CentralCloud's transformation from **hard-coded framework learning** (templates → LLM fallback) to a **config-driven, extensible system** using the proven Behavior + Orchestrator pattern.

**Old approach:** Framework detection logic scattered across FrameworkLearningAgent with hard-coded fallback strategy

**New approach:** Config-driven learner orchestration with dynamic discovery and priority-ordered fallback

## Architecture

### Core Components

```
┌─────────────────────────────────────────────┐
│   FrameworkLearner Behavior (~170 LOC)      │
│                                             │
│   Defines contract for all learners:        │
│   - learner_type() → :atom               │
│   - description() → String                │
│   - capabilities() → [String]             │
│   - learn(package_id, code_samples)       │
│   - record_success(package_id, framework) │
└─────────────────────────────────────────────┘
           ▲                          ▲
           │                          │
        implements             implements
           │                          │
           │                          │
┌──────────┴────┐           ┌────────┴──────────┐
│ TemplateMatcher│           │   LLMDiscovery    │
│ (~115 LOC)     │           │   (~185 LOC)      │
│                │           │                   │
│ Priority: 10   │           │ Priority: 20      │
│ Offline        │           │ Online (LLM call) │
│ Fast           │           │ Thorough          │
└────────────────┘           └───────────────────┘
           ▲                          ▲
           └──────────┬───────────────┘
                      │
         discovered & loaded from
                      │
                      ▼
        ┌─────────────────────────┐
        │  Config (config.exs)    │
        │                         │
        │ :framework_learners ={  │
        │   template_matcher: %{  │
        │     module: ...,        │
        │     enabled: true,      │
        │     priority: 10        │
        │   },                    │
        │   llm_discovery: %{..}  │
        │ }                       │
        └─────────────────────────┘
           ▲
           │ controls
           │
           ▼
┌──────────────────────────────────────────┐
│ FrameworkLearningOrchestrator (~280 LOC) │
│                                          │
│ 1. Load enabled learners by priority     │
│ 2. Try each learner sequentially:        │
│    - {:ok, framework} → return           │
│    - :no_match → try next                │
│    - {:error, reason} → propagate        │
│ 3. Record success via learner callback   │
│ 4. Return {ok, framework, learner_type}  │
└──────────────────────────────────────────┘
           ▲
           │
        used by
           │
           ▼
┌──────────────────────────────────────────┐
│     IntelligenceHub (1,399 LOC)          │
│                                          │
│  trigger_framework_discovery/2           │
│  - Calls FrameworkLearningOrchestrator   │
│  - Stores result in Package schema       │
│  - Logs which learner succeeded          │
└──────────────────────────────────────────┘
```

## Configuration

### Location
`centralcloud/config/config.exs` (lines 50-64)

### Format
```elixir
config :centralcloud, :framework_learners,
  template_matcher: %{
    module: Centralcloud.FrameworkLearners.TemplateMatcher,
    enabled: true,
    priority: 10,
    description: "Fast template-based framework matching using dependency signatures"
  },
  llm_discovery: %{
    module: Centralcloud.FrameworkLearners.LLMDiscovery,
    enabled: true,
    priority: 20,
    description: "Intelligent framework detection using LLM analysis of code"
  },
  # Future learners can be added here without changing orchestrator code
  signature_analyzer: %{
    module: Centralcloud.FrameworkLearners.SignatureAnalyzer,
    enabled: false,
    priority: 5
  }
```

### Configuration Keys

| Key | Type | Required | Description |
|-----|------|----------|-------------|
| `module` | Atom | ✅ | Module implementing `@behaviour FrameworkLearner` |
| `enabled` | Boolean | ✅ | Whether learner is active in this environment |
| `priority` | Integer | ✅ | Execution order (ascending, lower = tries first) |
| `description` | String | ✓ | Human-readable description (optional in runtime) |

## How Framework Learning Works

### Sequential Execution Flow

```
Input: package_id, code_samples
   │
   ▼
Load enabled learners from config
Sort by priority (ascending)
   │
   ├─→ Try TemplateMatcher (priority 10)
   │   │
   │   ├─→ Success: {:ok, framework}
   │   │   └─→ Return framework + learner_type
   │   │
   │   ├─→ No match: :no_match
   │   │   └─→ Continue to next
   │   │
   │   └─→ Error: {:error, reason}
   │       └─→ Return error (stop)
   │
   ├─→ Try LLMDiscovery (priority 20)
   │   │
   │   ├─→ Success: {:ok, framework}
   │   │   └─→ Return framework + learner_type
   │   │
   │   ├─→ No match: :no_match
   │   │   └─→ Continue to next
   │   │
   │   └─→ Error: {:error, reason}
   │       └─→ Return error (stop)
   │
   ├─→ Try Additional Learners...
   │
   └─→ All learners exhausted
       └─→ Return {:error, :no_framework_found}
```

### Key Principles

1. **Config-Driven Learner Discovery** - Learners loaded from configuration, not hard-coded
2. **Priority-Ordered Execution** - Lower priority numbers try first (allows reordering without code changes)
3. **Sequential with Fallback** - Each learner tries in order until success or hard error
4. **Learner Independence** - Each learner is independently testable and deployable
5. **First-Match Wins** - First successful learner determines framework (analytics track which one)

## Learner Implementations

### TemplateMatcher

**File:** `lib/centralcloud/framework_learners/template_matcher.ex`

**Purpose:** Fast framework detection via dependency signature matching

**Process:**
1. Load framework templates from CentralCloud knowledge cache
2. Extract package dependencies from database
3. Match against `detector_signatures` in templates
4. Return first matching framework

**Performance:**
- ⚡ Fast - Pure pattern matching, no LLM calls
- ✅ Offline - Works without network (after templates loaded)
- 📦 Ecosystem-agnostic - Works for npm, cargo, hex, pypi, etc.

**Returns:**
- `{:ok, %{name, type, version, ecosystem, confidence: 0.95}}` if match found
- `:no_match` if no template matches (orchestrator tries next learner)
- `{:error, reason}` on hard error (orchestrator stops)

**Configuration:**
```elixir
template_matcher: %{
  module: Centralcloud.FrameworkLearners.TemplateMatcher,
  enabled: true,
  priority: 10  # Tries first
}
```

### LLMDiscovery

**File:** `lib/centralcloud/framework_learners/llm_discovery.ex`

**Purpose:** Intelligent framework detection using LLM analysis of code

**Process:**
1. Load framework discovery prompt from cache (or fetch from knowledge cache)
2. Format prompt with package info and code samples
3. Call LLM via NATS (`llm.request` subject)
4. Parse LLM response (JSON format expected)
5. Enrich with metadata (detected_by, confidence)

**Performance:**
- 🤖 Thorough - Analyzes actual code, not just dependencies
- 🌐 Online - Requires network and LLM availability
- ⏱️ Slower - LLM calls take 5-60 seconds

**Returns:**
- `{:ok, %{name, type, version, confidence, reasoning}}` if framework detected
- `:no_match` if LLM cannot determine (orchestrator tries next learner)
- `{:error, reason}` on LLM timeout or error (orchestrator stops)

**Configuration:**
```elixir
llm_discovery: %{
  module: Centralcloud.FrameworkLearners.LLMDiscovery,
  enabled: true,
  priority: 20  # Tries after TemplateMatcher
}
```

**Features:**
- Prompt caching via JetStream KV (1 hour TTL)
- Confidence scoring (default 0.85)
- Reasoning/explanation in response
- Timeout handling (120 seconds default)

## Usage Examples

### Basic Discovery (All Enabled Learners)

```elixir
alias Centralcloud.FrameworkLearningOrchestrator

# Try all enabled learners in priority order
case FrameworkLearningOrchestrator.learn("npm:react", ["package.json content"]) do
  {:ok, framework, learner} ->
    IO.puts("Discovered: #{framework["name"]} via #{learner}")
    # => "Discovered: React via template_matcher"

  {:error, :no_framework_found} ->
    IO.puts("Could not determine framework")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
end
```

### Targeted Discovery (Skip to LLM)

```elixir
# Skip templates, go straight to LLM
case FrameworkLearningOrchestrator.learn(
  "cargo:tokio",
  ["Cargo.toml content"],
  learners: [:llm_discovery]
) do
  {:ok, framework, learner} -> ...
  {:error, reason} -> ...
end
```

### Get Learner Information

```elixir
# List all configured learners
learners = FrameworkLearningOrchestrator.get_learners_info()

# => [
#   %{
#     name: :template_matcher,
#     enabled: true,
#     priority: 10,
#     description: "Fast template-based framework matching...",
#     module: Centralcloud.FrameworkLearners.TemplateMatcher,
#     capabilities: ["fast", "offline", "dependency_based", "high_confidence"]
#   },
#   %{
#     name: :llm_discovery,
#     enabled: true,
#     priority: 20,
#     ...
#   }
# ]
```

## Integration Points

### IntelligenceHub

**File:** `lib/centralcloud/intelligence_hub.ex`

**Integration:** `trigger_framework_discovery/2` (line 721)

```elixir
defp trigger_framework_discovery(framework_name, query) do
  package_id = Map.get(query, "package_id", framework_name)
  code_samples = Map.get(query, "code_samples", [])

  case Centralcloud.FrameworkLearningOrchestrator.learn(package_id, code_samples) do
    {:ok, framework, learner_type} ->
      Logger.info("Framework discovered via #{learner_type}", ...)
      store_discovered_framework(package_id, framework)

    {:error, :no_framework_found} ->
      Logger.warn("Could not determine framework for #{package_id}")

    {:error, reason} ->
      Logger.error("Framework discovery failed", reason: inspect(reason))
  end
end
```

**NATS Subject:** `framework.pattern.query`

**Message Format:**
```json
{
  "framework_name": "react",
  "package_id": "npm:react",
  "code_samples": ["content of files..."]
}
```

## Adding New Learners

### Step-by-Step Guide

#### 1. Create Learner Module

Create file: `lib/centralcloud/framework_learners/my_learner.ex`

```elixir
defmodule Centralcloud.FrameworkLearners.MyLearner do
  @moduledoc """
  MyLearner - Custom framework learning strategy.
  """

  @behaviour Centralcloud.FrameworkLearner

  require Logger

  @impl Centralcloud.FrameworkLearner
  def learner_type, do: :my_learner

  @impl Centralcloud.FrameworkLearner
  def description do
    "Custom framework detection using my approach"
  end

  @impl Centralcloud.FrameworkLearner
  def capabilities do
    ["custom", "specialized", "fast"]
  end

  @impl Centralcloud.FrameworkLearner
  def learn(package_id, code_samples) do
    # Your learning logic here
    # Return:
    # - {:ok, %{name: "Framework", type: "web_framework", ...}}
    # - :no_match
    # - {:error, reason}
    :no_match
  end

  @impl Centralcloud.FrameworkLearner
  def record_success(_package_id, _framework) do
    :ok
  end
end
```

#### 2. Update Configuration

Add to `config/config.exs`:

```elixir
config :centralcloud, :framework_learners,
  my_learner: %{
    module: Centralcloud.FrameworkLearners.MyLearner,
    enabled: true,
    priority: 15,  # Between TemplateMatcher (10) and LLMDiscovery (20)
    description: "Custom framework detection using my approach"
  }
```

#### 3. Test Learner

Create `test/centralcloud/framework_learners/my_learner_test.exs`:

```elixir
defmodule Centralcloud.FrameworkLearners.MyLearnerTest do
  use ExUnit.Case

  alias Centralcloud.FrameworkLearners.MyLearner

  test "learns framework successfully" do
    {:ok, framework} = MyLearner.learn("npm:react", ["code"])
    assert framework["name"] == "React"
  end

  test "returns no_match when cannot determine" do
    assert MyLearner.learn("unknown", []) == :no_match
  end
end
```

#### 4. Run Tests

```bash
mix test test/centralcloud/framework_learners/my_learner_test.exs
```

That's it! The orchestrator will automatically discover and use your new learner.

## Migration from Hard-Coded to Config-Driven

### Old Approach (Hard-Coded)

```elixir
# lib/centralcloud/framework_learning_agent.ex
def discover_framework(package_id, code_samples) do
  # Try templates first
  case match_templates(package_id) do
    {:ok, framework} -> {:ok, framework}
    :no_match ->
      # Fallback to LLM
      call_llm_discovery(package_id, code_samples)
    error -> error
  end
end
```

**Problems:**
- ❌ Strategy hard-coded in code
- ❌ Can't add new learners without code changes
- ❌ Can't reorder strategies without code changes
- ❌ Can't enable/disable in production
- ❌ Learning logic mixed with discovery logic

### New Approach (Config-Driven)

```elixir
# config/config.exs
config :centralcloud, :framework_learners,
  template_matcher: %{
    module: Centralcloud.FrameworkLearners.TemplateMatcher,
    enabled: true,
    priority: 10
  },
  llm_discovery: %{
    module: Centralcloud.FrameworkLearners.LLMDiscovery,
    enabled: true,
    priority: 20
  }

# Usage - same simple call, but now driven by config
FrameworkLearningOrchestrator.learn(package_id, code_samples)
```

**Benefits:**
- ✅ Strategy defined in configuration
- ✅ Add new learners via config only
- ✅ Reorder strategies without code changes
- ✅ Enable/disable in production (1 line change)
- ✅ Learning logic separate from orchestration

### Migration Checklist

- [x] Create `FrameworkLearner` behavior (~170 LOC)
- [x] Create `FrameworkLearningOrchestrator` (~280 LOC)
- [x] Extract `TemplateMatcher` learner (~115 LOC)
- [x] Extract `LLMDiscovery` learner (~185 LOC)
- [x] Add `framework_learners` to config
- [x] Update `IntelligenceHub` to use orchestrator
- [ ] Deprecate `FrameworkLearningAgent` (optional)
- [ ] Add comprehensive tests
- [ ] Update documentation

## Testing

### Unit Tests

Each learner has independent unit tests:

```bash
# Test TemplateMatcher
mix test test/centralcloud/framework_learners/template_matcher_test.exs

# Test LLMDiscovery
mix test test/centralcloud/framework_learners/llm_discovery_test.exs
```

### Integration Tests

Test orchestrator with multiple learners:

```bash
# Test orchestrator
mix test test/centralcloud/framework_learning_orchestrator_test.exs
```

### Configuration Tests

Verify configuration loading:

```elixir
test "loads enabled learners in priority order" do
  learners = Centralcloud.FrameworkLearner.load_enabled_learners()

  # Should be sorted by priority
  assert [type1, type2 | _] = learners
  assert elem(type1, 1) <= elem(type2, 1)  # priority1 <= priority2
end
```

## Performance Characteristics

### TemplateMatcher
- **Time:** < 100ms (pure pattern matching)
- **Network:** Optional (after templates cached)
- **Cost:** No LLM cost

### LLMDiscovery
- **Time:** 5-60 seconds (LLM call)
- **Network:** Required
- **Cost:** LLM token cost

### Overall Strategy
1. Fast path: Try TemplateMatcher first (< 100ms)
2. Fallback: LLM if needed (5-60 seconds)
3. Result: Quick discovery for known frameworks, thorough analysis for custom

## Monitoring

### Logs

Framework discovery is logged at multiple levels:

```
INFO: "Triggering framework discovery for: react"
INFO: "Framework discovered via template_matcher", framework_name: "React"
DEBUG: "Template matcher: Loaded 45 framework templates"
```

### Metrics

Track learner effectiveness:

```elixir
# In FrameworkLearningOrchestrator.record_learner_success/3
# Could add metrics tracking here:
# - Success rate per learner
# - Average time per learner
# - Which learner wins most often
```

### Analytics (Future)

The orchestrator returns `learner_type` for analytics:

```elixir
{:ok, framework, learner_type} = FrameworkLearningOrchestrator.learn(...)
# learner_type = :template_matcher or :llm_discovery

# Use this to track:
# - Which learner is most effective
# - Average discovery time per learner
# - Cost per discovery method
```

## FAQ

### Q: Can I disable a learner?

**A:** Yes, set `enabled: false` in config:

```elixir
llm_discovery: %{
  module: ...,
  enabled: false,  # Disabled
  priority: 20
}
```

### Q: Can I change execution order?

**A:** Yes, adjust priority values:

```elixir
# Try LLM first (priority 5), then templates (priority 10)
llm_discovery: %{..., priority: 5},
template_matcher: %{..., priority: 10}
```

### Q: Can I have multiple learners at same priority?

**A:** Technically yes, but not recommended. They execute in order of appearance in map, which is unpredictable. Use different priorities instead.

### Q: How do I test a new learner?

**A:** Create a test file and run:

```bash
mix test test/centralcloud/framework_learners/my_learner_test.exs
```

The orchestrator will automatically use it once configured.

### Q: What if a learner throws an exception?

**A:** The orchestrator catches exceptions and logs them:

```elixir
rescue
  e ->
    Logger.error("Learner execution failed for #{learner_type}", error: inspect(e))
    try_learners(rest, package_id, code_samples, opts)
```

It continues to the next learner (doesn't stop on exception).

## Related Documentation

- [FrameworkLearner Behavior](lib/centralcloud/framework_learner.ex) - Behavior contract
- [FrameworkLearningOrchestrator](lib/centralcloud/framework_learning_orchestrator.ex) - Orchestration engine
- [TemplateMatcher](lib/centralcloud/framework_learners/template_matcher.ex) - Fast learner
- [LLMDiscovery](lib/centralcloud/framework_learners/llm_discovery.ex) - Thorough learner
- [IntelligenceHub Integration](lib/centralcloud/intelligence_hub.ex) - Usage point

## Summary

The config-driven framework learning system provides:

1. **Flexibility** - Add/remove/reorder learners via configuration
2. **Extensibility** - New learners don't require orchestrator changes
3. **Simplicity** - Single API: `FrameworkLearningOrchestrator.learn/2`
4. **Testability** - Each learner independently testable
5. **Production-Ready** - Enable/disable strategies without code changes
6. **Analytics-Ready** - Track which learner succeeded for optimization

This follows the proven **Behavior + Orchestrator** pattern used throughout Singularity for SearchOrchestrator and JobOrchestrator, ensuring consistency and maintainability.
