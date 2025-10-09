# How Engine Registry Helps Singularity

## The Problem It Solves

**Before:** Hard-coded capability checks scattered everywhere
```elixir
# Agent needs to know what it can do - HARD-CODED everywhere!
defmodule MyAgent do
  def can_i_do_this? do
    # Hard-coded knowledge of what exists
    if Code.ensure_loaded?(Singularity.PromptEngine) do
      if function_exported?(Singularity.PromptEngine, :optimize_prompt, 2) do
        # Check if NATS is available
        # Check if NIF is loaded
        # Check if health is OK
        # ... lots of brittle checking
      end
    end
  end
end
```

**After:** Dynamic capability discovery via NATS
```elixir
defmodule MyAgent do
  def can_i_do_this? do
    # Ask the system what it can do RIGHT NOW
    {:ok, %{capabilities: caps}} =
      Gnat.request(nats, "system.capabilities.available", "{}")

    # Find what you need
    Enum.find(caps, &(&1.id == :optimize_prompt))
  end
end
```

---

## Real Use Cases in Singularity

### 1. **Autonomous Agent Task Planning**

**Scenario:** Agent receives task "optimize this code"

```elixir
defmodule Singularity.Autonomy.TaskPlanner do
  def plan_task(task) do
    # Discover what capabilities are ACTUALLY available right now
    {:ok, response} = Gnat.request(nats, "system.capabilities.available", "{}")

    available_caps = response.capabilities

    # Build execution plan based on REAL capabilities
    plan = cond do
      has_capability?(available_caps, :code_quality_check) &&
      has_capability?(available_caps, :generate_code) ->
        [:analyze_code, :identify_issues, :generate_fixes, :validate]

      has_capability?(available_caps, :architecture_analysis) ->
        [:architecture_analysis, :suggest_patterns]

      true ->
        [:fallback_to_llm]
    end

    Logger.info("Task plan: #{inspect(plan)}",
      available_capabilities: length(available_caps))

    plan
  end
end
```

**Benefit:** Agent adapts to what's ACTUALLY available (e.g., if PromptEngine NIF fails to load, agent knows not to try it)

---

### 2. **MCP Tool Federation (Claude Desktop/Cursor)**

**Scenario:** Expose Singularity capabilities to external AI tools

```elixir
defmodule Singularity.Interfaces.MCP do
  @moduledoc """
  Model Context Protocol - Expose capabilities to Claude Desktop, Cursor, etc.
  """

  def list_tools do
    # Dynamically generate MCP tool definitions from Engine Registry
    {:ok, response} = Gnat.request(nats, "system.capabilities.available", "{}")

    Enum.map(response.capabilities, fn cap ->
      %{
        name: "singularity_#{cap.engine}_#{cap.id}",
        description: cap.description,
        inputSchema: %{
          type: "object",
          properties: infer_properties(cap),
          required: infer_required(cap)
        }
      }
    end)
  end
end
```

**Result:** Claude Desktop sees:
```json
{
  "tools": [
    {"name": "singularity_code_parse_ast", "description": "Parse code into AST"},
    {"name": "singularity_prompt_optimize", "description": "Optimize prompts"},
    {"name": "singularity_quality_check", "description": "Run quality checks"}
  ]
}
```

**Benefit:** MCP tools stay in sync with actual capabilities - no manual maintenance!

---

### 3. **Health-Based Failover**

**Scenario:** PromptEngine NIF fails (OpenSSL issue), system auto-adapts

```elixir
defmodule Singularity.Autonomy.AdaptiveRouter do
  def route_prompt_request(request) do
    # Check engine health in real-time
    {:ok, health} = Gnat.request(nats, "system.health.engines", "{}")

    prompt_engine = Enum.find(health.engines, &(&1.id == :prompt))

    case prompt_engine.health do
      :ok ->
        # Use fast NIF-based prompt optimization
        PromptEngine.optimize(request)

      {:error, _reason} ->
        # Fallback to NATS-based or LLM-based optimization
        Logger.warning("PromptEngine unhealthy, using fallback")
        LLMService.optimize_via_claude(request)
    end
  end
end
```

**Benefit:** System self-heals - agents automatically route around broken engines

---

### 4. **Runtime Feature Discovery**

**Scenario:** New engine added, agents discover it automatically

```elixir
# Developer adds new VectorEngine
defmodule Singularity.VectorEngine do
  @behaviour Singularity.Engine

  def id, do: :vector
  def label, do: "Vector Search Engine"

  def capabilities do
    [
      %{
        id: :semantic_search,
        label: "Semantic Search",
        description: "pgvector-based semantic code search",
        available?: pgvector_available?(),
        tags: [:search, :embeddings]
      }
    ]
  end
end

# Add to Registry in application.ex
config :singularity, Singularity.Engine.Registry,
  engine_modules: [Singularity.VectorEngine]
```

**Agents discover it automatically:**
```elixir
# Agent queries capabilities
{:ok, caps} = Gnat.request(nats, "system.capabilities.list", "{}")

# NEW capability appears!
%{
  id: :semantic_search,
  engine: :vector,
  label: "Semantic Search",
  available?: true,
  tags: [:search, :embeddings]
}
```

**Benefit:** Zero code changes needed in agents - they discover new capabilities automatically!

---

### 5. **Development Introspection**

**Scenario:** Developer debugging "why isn't X working?"

```bash
# CLI introspection
mix engines.enumerate

# Output shows REAL state:
🔧 Singularity Engines
================================================================================

PromptEngine
  ID:          prompt
  Module:      Singularity.PromptEngine
  Description: Prompt optimization and generation
  Health:      ERROR: NIF failed to load (OpenSSL version mismatch)
  Capabilities: 3
    ✗ NIF-based optimization  # ← Developer sees it's unavailable!
    ✓ NATS-based optimization
    ✓ Template catalog
```

**Benefit:** Instant visibility into what's working/broken without digging through logs

---

### 6. **Agent Learning from Experience**

**Scenario:** Agent tracks which capabilities succeed/fail

```elixir
defmodule Singularity.Autonomy.LearningAgent do
  def execute_with_learning(task) do
    # Get available capabilities
    {:ok, caps} = Gnat.request(nats, "system.capabilities.available", "{}")

    # Try each capability, track success
    results = Enum.map(caps, fn cap ->
      case try_capability(cap, task) do
        {:ok, result} ->
          # Record success
          record_success(cap.id, task.type)
          {:ok, result}

        {:error, reason} ->
          # Record failure, try next
          record_failure(cap.id, task.type, reason)
          {:error, reason}
      end
    end)

    # Next time, prioritize capabilities that succeeded
    best_capability = get_best_capability_for(task.type)
  end
end
```

**Benefit:** Agent learns "PromptEngine works 95% of time, QualityEngine only 60%" and adapts

---

### 7. **Capability-Based Access Control**

**Scenario:** Different agents get different capabilities

```elixir
defmodule Singularity.Autonomy.AccessControl do
  def capabilities_for_agent(agent_id) do
    # Get all available capabilities
    {:ok, all_caps} = Gnat.request(nats, "system.capabilities.available", "{}")

    # Filter based on agent permissions
    case agent_role(agent_id) do
      :admin ->
        all_caps  # Full access

      :developer ->
        # No destructive operations
        Enum.reject(all_caps, &(:destructive in &1.tags))

      :learner ->
        # Only read operations
        Enum.filter(all_caps, &(:read_only in &1.tags))
    end
  end
end
```

**Benefit:** Fine-grained capability control per agent

---

## Key Benefits Summary

### 1. **No Hard-Coding**
- Agents discover capabilities at runtime
- No brittle `if module_exists?()` checks
- System adapts to actual state

### 2. **Self-Healing**
- Engines fail? Agents route around them
- Health checks → automatic failover
- Zero manual intervention

### 3. **Zero-Touch Integration**
- Add new engine → agents discover it
- MCP tools auto-update
- No coordination needed

### 4. **Autonomous Agent Foundation**
- Agents know "what can I do?"
- Task planning based on real capabilities
- Learning which capabilities work best

### 5. **Developer Experience**
- `mix engines.enumerate` → instant visibility
- Health monitoring built-in
- Easy debugging ("which engine is broken?")

### 6. **Internal Tooling Philosophy**
- Everything via NATS (no HTTP API needed)
- Self-describing system
- Rich introspection for learning

---

## Architecture Pattern

```
┌─────────────────────────────────────────────────────┐
│              Autonomous Agents                      │
│   "What can I do? What's healthy? What's best?"     │
└─────────────────┬───────────────────────────────────┘
                  │
                  ↓ NATS request
┌─────────────────────────────────────────────────────┐
│         system.capabilities.available                │
│         system.health.engines                        │
│         system.engines.list                          │
└─────────────────┬───────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────┐
│       Nats.EngineDiscoveryHandler                   │
│   (Routes introspection requests)                    │
└─────────────────┬───────────────────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────────────────┐
│           Engine.Registry                            │
│   (Centralizes all engine metadata)                  │
└─────────────────┬───────────────────────────────────┘
                  │
                  ↓
┌──────────────┬──────────┬──────────┬──────────┬─────┐
│Architecture  │   Code   │  Prompt  │ Quality  │Gen  │
│   Engine     │  Engine  │  Engine  │  Engine  │Eng  │
└──────────────┴──────────┴──────────┴──────────┴─────┘
     Each implements Singularity.Engine behaviour
```

---

## The Big Win: Singularity Knows Itself

**Before Engine Registry:**
- "I have these 5 engines" ← hard-coded in docs
- "Agent can use PromptEngine" ← hard-coded in agent code
- "MCP exposes these tools" ← manually maintained list

**After Engine Registry:**
- "What do I have?" → Query `system.engines.list`
- "What can I do?" → Query `system.capabilities.available`
- "What's working?" → Query `system.health.engines`

**Result:** Self-aware system that adapts to its own state in real-time.

This is the foundation for true autonomous operation! 🚀
