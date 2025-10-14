# Lua Agent Behaviors - Design Document

## Overview

Hot-reload agent personalities, response styles, and behaviors via Lua scripts stored in the database - without recompiling Elixir!

**Similar to**: Lua Rules Engine (P0 - completed)
**Priority**: P1 - High Impact
**Estimated Time**: 6 hours

---

## Problem Statement

**Current System:**
- Agent roles hardcoded in `agent_roles.ex`
- Tool assignments are static
- Response style changes require recompile
- A/B testing agent personalities = deploy new code
- Personality tuning = code + test + deploy cycle

**What We Want:**
- Hot-reload agent personalities from database
- A/B test different response styles instantly
- Configure agent behavior per-task without recompile
- Dynamic tool selection based on context
- Iterate on agent UX in minutes, not hours

---

## Architecture

### Database Schema

**Table: `agent_behaviors`**
```sql
CREATE TABLE agent_behaviors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identity
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  role_type TEXT NOT NULL,  -- matches agent_roles.ex roles

  -- Lua script for behavior
  lua_script TEXT NOT NULL,

  -- Metadata
  status TEXT DEFAULT 'active',
  version INTEGER DEFAULT 1,
  created_by TEXT,

  -- Performance tracking
  usage_count INTEGER DEFAULT 0,
  success_rate FLOAT DEFAULT 1.0,
  avg_response_time_ms FLOAT DEFAULT 0.0,

  -- Evolution
  parent_behavior_id UUID REFERENCES agent_behaviors(id),
  evolution_notes TEXT,

  -- Timestamps
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX agent_behaviors_role_type_index ON agent_behaviors(role_type);
CREATE INDEX agent_behaviors_status_index ON agent_behaviors(status);
```

### Module Structure

**1. AgentBehavior Schema** (`agent_behavior.ex`)
- Ecto schema for database
- Validation: Lua script must be valid
- Changesets for create/update/evolution

**2. AgentBehaviorLoader** (`agent_behavior_loader.ex`)
- GenServer with ETS cache
- Loads behaviors from database
- Refreshes cache periodically (5 min)
- `get_behavior/1`, `get_behaviors_by_role/1`

**3. AgentBehaviorRunner** (`agent_behavior_runner.ex`)
- Executes Lua behavior scripts
- Similar API to `LuaRunner.execute_rule/2`
- Returns response configuration

**4. Integration** (update `agent_roles.ex` or create wrapper)
- Fetch Lua behavior for role
- Execute before generating response
- Apply behavior config to response

---

## Lua Behavior Contract

### Input Context

```lua
-- Global variable `context` contains:
context = {
  -- Agent identity
  agent_id = "agent-12345",
  role = "code_developer",  -- or architect_analyst, etc.

  -- Task info
  task_type = "code_review",  -- or "planning", "refactoring", etc.
  task_description = "Review PR #123 for security issues",

  -- User info
  user_id = "user-789",
  user_preferences = {
    verbosity = "detailed",  -- or "concise"
    style = "friendly"  -- or "formal", "technical"
  },

  -- Agent state
  cycles_completed = 42,
  success_rate = 0.92,
  recent_failures = 2,

  -- Environment
  time_of_day = "morning",  -- or "afternoon", "evening"
  urgency = "normal",  -- or "high", "low"

  -- Available tools (from role)
  available_tools = {
    "codebase_search",
    "code_quality",
    "fs_read_file"
  }
}
```

### Return Format

```lua
return {
  -- Response style
  personality = {
    tone = "friendly",  -- "formal", "casual", "technical"
    verbosity = "detailed",  -- "concise", "normal", "detailed"
    emoji_use = true,  -- false
    code_examples = true  -- Include code examples
  },

  -- Tool selection (override role defaults if needed)
  tools = {
    "codebase_search",
    "code_quality",
    "security_scan"  -- Add security_scan for this task
  },

  -- Decision thresholds
  confidence_threshold = 0.8,  -- For autonomous actions
  ask_human_below = 0.6,  -- Ask for confirmation

  -- Message formatting
  response_template = [[
Hello! I'll review PR #123 for security issues. 🔒

Let me start by scanning the codebase...
]],

  -- Metadata
  reasoning = "Security review requires formal tone and security tools",
  applied_rules = {"security_review_rule", "pr_review_standards"}
}
```

---

## Example Lua Behaviors

### 1. Friendly Code Reviewer

```lua
-- behaviors/friendly_code_reviewer.lua
local task_type = context.task_type
local urgency = context.urgency

-- Friendly tone for code reviews
if task_type == "code_review" then
  return {
    personality = {
      tone = "friendly",
      verbosity = "detailed",
      emoji_use = true,
      code_examples = true
    },
    tools = context.available_tools,  -- Use role defaults
    confidence_threshold = 0.85,
    response_template = [[
Hey! Let me take a look at this code for you. 👀

I'll check for:
- Code quality ✓
- Security issues 🔒
- Best practices 📚

Give me a moment...
]],
    reasoning = "Friendly code reviewer - detailed feedback with examples"
  }
end

-- Default behavior
return {
  personality = {tone = "casual", verbosity = "normal", emoji_use = false},
  tools = context.available_tools,
  confidence_threshold = 0.8,
  response_template = "I'll help you with that task.",
  reasoning = "Default friendly behavior"
}
```

### 2. Formal Architecture Analyst

```lua
-- behaviors/formal_architect.lua
local role = context.role
local task_type = context.task_type

if role == "architecture_analyst" then
  local tools = context.available_tools

  -- Add specific architecture tools
  table.insert(tools, "codebase_architecture")
  table.insert(tools, "codebase_dependencies")

  return {
    personality = {
      tone = "formal",
      verbosity = "detailed",
      emoji_use = false,
      code_examples = true
    },
    tools = tools,
    confidence_threshold = 0.9,  -- Higher threshold for architecture
    response_template = [[
## Architecture Analysis

I will analyze the system architecture focusing on:

1. Component relationships
2. Dependency structure
3. Design patterns

Initiating analysis...
]],
    reasoning = "Formal architecture analysis with high confidence threshold"
  }
end

return {
  personality = {tone = "formal", verbosity = "detailed", emoji_use = false},
  tools = context.available_tools,
  confidence_threshold = 0.85,
  response_template = "Initiating analysis.",
  reasoning = "Formal analyst default"
}
```

### 3. Context-Aware Personality

```lua
-- behaviors/context_aware.lua
local time_of_day = context.time_of_day
local urgency = context.urgency
local success_rate = context.success_rate

-- Morning = energetic
if time_of_day == "morning" then
  return {
    personality = {
      tone = "energetic",
      verbosity = "normal",
      emoji_use = true,
      code_examples = true
    },
    tools = context.available_tools,
    confidence_threshold = 0.8,
    response_template = "Good morning! ☀️ Let's tackle this task together!",
    reasoning = "Morning energy boost"
  }
end

-- High urgency = concise
if urgency == "high" then
  return {
    personality = {
      tone = "direct",
      verbosity = "concise",
      emoji_use = false,
      code_examples = false
    },
    tools = context.available_tools,
    confidence_threshold = 0.7,  -- Lower for speed
    response_template = "Urgent task detected. Starting immediately.",
    reasoning = "High urgency - concise and fast"
  }
end

-- Low success rate = cautious
if success_rate < 0.7 then
  return {
    personality = {
      tone = "cautious",
      verbosity = "detailed",
      emoji_use = false,
      code_examples = true
    },
    tools = context.available_tools,
    confidence_threshold = 0.95,  -- Very high threshold
    ask_human_below = 0.8,
    response_template = "I want to be extra careful with this task. Let me analyze thoroughly...",
    reasoning = "Recent failures - being cautious"
  }
end

-- Default
return {
  personality = {tone = "friendly", verbosity = "normal", emoji_use = true},
  tools = context.available_tools,
  confidence_threshold = 0.8,
  response_template = "I'm on it!",
  reasoning = "Standard behavior"
}
```

---

## Integration Points

### Option A: Agent Role Wrapper (Cleaner)

Create new module that wraps existing `agent_roles.ex`:

```elixir
defmodule Singularity.Agents.BehaviorEngine do
  alias Singularity.Agents.{AgentBehaviorLoader, AgentBehaviorRunner}
  alias Singularity.Tools.AgentRoles

  def get_behavior_for_task(role, task_context) do
    # 1. Try to load Lua behavior
    case AgentBehaviorLoader.get_active_behavior(role) do
      {:ok, behavior} ->
        execute_lua_behavior(behavior, task_context)

      {:error, :not_found} ->
        # 2. Fallback to hardcoded role
        get_default_behavior(role)
    end
  end

  defp execute_lua_behavior(behavior, context) do
    case AgentBehaviorRunner.execute(behavior.lua_script, context) do
      {:ok, config} -> {:ok, config}
      {:error, _} -> get_default_behavior(context.role)
    end
  end

  defp get_default_behavior(role) do
    {:ok, tools} = AgentRoles.get_tools_for_role(role)

    {:ok, %{
      personality: %{tone: "neutral", verbosity: "normal"},
      tools: tools,
      confidence_threshold: 0.8,
      response_template: "Processing task...",
      reasoning: "Default hardcoded behavior"
    }}
  end
end
```

### Option B: Direct Integration (Modify `agent_roles.ex`)

Add Lua behavior execution directly into `agent_roles.ex`:

```elixir
# In agent_roles.ex
def get_tools_for_role(role, context \\ %{}) do
  # Try Lua behavior first
  case load_lua_behavior(role, context) do
    {:ok, config} -> {:ok, config.tools}
    {:error, _} -> {:ok, Map.get(@agent_roles, role).tools}  # Fallback
  end
end

defp load_lua_behavior(role, context) do
  # Load from database via AgentBehaviorLoader
  AgentBehaviorLoader.execute_for_role(role, context)
end
```

**Recommendation**: **Option A** - cleaner separation, easier testing, no modification to existing code.

---

## Migration Path

### Phase 1: Coexistence (Week 1)
- Database migration
- AgentBehavior*, AgentBehaviorLoader, AgentBehaviorRunner modules
- BehaviorEngine wrapper
- Example Lua behaviors
- Hardcoded roles still work (fallback)

### Phase 2: Gradual Adoption (Week 2-3)
- Create Lua behaviors for each role
- A/B test Lua vs hardcoded
- Collect performance metrics
- Iterate based on feedback

### Phase 3: Full Migration (Week 4+)
- All roles use Lua behaviors
- Deprecate hardcoded roles
- Agent roles = Lua scripts only
- Remove `@agent_roles` map

---

## A/B Testing Example

```elixir
# Test two personalities for code_developer role
%AgentBehavior{}
|> AgentBehavior.changeset(%{
  name: "code_developer_friendly_v1",
  role_type: "code_developer",
  lua_script: friendly_script,
  status: "active"
})
|> Repo.insert()

%AgentBehavior{}
|> AgentBehavior.changeset(%{
  name: "code_developer_formal_v1",
  role_type: "code_developer",
  lua_script: formal_script,
  status: "active"
})
|> Repo.insert()

# Load balancer selects randomly
# Track success_rate for each
# Winner becomes primary after 100 uses
```

---

## Performance Expectations

### Lua Behavior Execution

- **Cold start**: 10-30ms (first Lua VM init)
- **Warm execution**: 1-3ms (reusing Lua state)
- **Cached config**: <1ms (ETS lookup)

### Caching Strategy

```elixir
# Cache behavior config per (role, task_type) for 5 minutes
cache_key = "behavior:#{role}:#{task_type}"

case Cachex.get(:behavior_cache, cache_key) do
  {:ok, nil} ->
    config = execute_lua_behavior(...)
    Cachex.put(:behavior_cache, cache_key, config, ttl: :timer.minutes(5))
    config

  {:ok, cached} ->
    cached
end
```

---

## Benefits

### 1. Rapid Iteration ⚡
- Update agent personality in database
- Reload cache (1 second)
- No recompile, no deploy, no downtime

### 2. A/B Testing 🧪
- Multiple behaviors per role
- Track success_rate automatically
- Winner selection based on metrics

### 3. User Preferences 🎨
- Different users get different personalities
- Context-aware behavior (time of day, urgency)
- Personalized agent experience

### 4. Evolution 🧬
- Track which behaviors work best
- Create child behaviors from parents
- Version history in database

### 5. Debugging 🐛
- Lua scripts easier to read than Elixir modules
- Faster to test in IEx
- Clear reasoning field explains decisions

---

## Next Steps

1. **Create migration** - `agent_behaviors` table
2. **Implement core modules** - Schema, Loader, Runner
3. **Create BehaviorEngine wrapper** - Integration point
4. **Write example behaviors** - 3 production-ready scripts
5. **Add tests** - Unit + integration
6. **Document usage** - README with examples

**Estimated Time**: 6 hours (as per expansion analysis)

---

## Questions to Consider

1. **Should behaviors be role-specific or task-specific?**
   - Hybrid: Behaviors have `role_type` but can override per-task

2. **How to handle multiple active behaviors per role?**
   - Load balancer (random selection)
   - User preference
   - A/B test tracking

3. **Should we expose tool execution to Lua?**
   - No (security) - only configuration
   - Lua configures, Elixir executes

4. **Validation before inserting Lua script?**
   - Yes - compile check via `LuaRunner.validate/1`
   - Sandbox execution with test context

5. **Evolution triggers?**
   - Manual (developer creates variant)
   - Automatic (low success_rate triggers review)
   - Hybrid (system suggests, human approves)

---

## Summary

Lua Agent Behaviors enable **hot-reload of agent personalities** without recompiling Elixir!

**Similar to**: Rules Engine (P0) - database-backed Lua scripts
**Different from**: Rules Engine focused on decisions, this focuses on UX/personality

**Ready to implement?** Estimated 6 hours for full P1 implementation.

**Want to proceed?** Say "implement agent behaviors" and I'll start building!
