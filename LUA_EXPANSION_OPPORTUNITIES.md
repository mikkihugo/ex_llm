# Lua Expansion Opportunities - Beyond Prompts

**Date:** 2025-01-14
**Current Usage:** Prompt building only (19 scripts)
**Potential:** Much more! 🚀

---

## TL;DR

**You're ONLY using Lua for prompt building**, but Lua could power:
1. **Rules & Policies** - Replace hardcoded business logic
2. **Agent Behavior** - Configure agents without recompiling
3. **Workflow Scripts** - SPARC/HTDAG step logic
4. **Configuration** - Dynamic system config
5. **Data Transforms** - ETL pipelines
6. **Testing** - Test scenarios as Lua scripts

**Impact:** 10x more flexible, hot-reload everything, no recompiles!

---

## Current State

### ✅ What's Using Lua Now

**1. LLM Service - Prompt Building (ONLY USE CASE)**
- `LLM.Service.call_with_script/3` - Line 645
- Executes Lua to build dynamic prompts
- 19 production scripts in `templates_data/prompt_library/`

**That's it!** Lua is MASSIVELY underutilized.

---

## Massive Opportunities

### 1. Rules Engine → Lua Rules 🔥 **HIGH IMPACT**

**Current Problem:**
```elixir
# lib/singularity/execution/autonomy/rule_engine_core.ex
# Rules are HARDCODED in Elixir
def execute_rule(rule, context) do
  # Complex pattern matching in Elixir
  # Need recompile to change rules
  # Can't hot-reload business logic
end
```

**With Lua:**
```lua
-- rules/epic_validation.lua
function validate_epic(epic)
  local wsjf = epic.wsjf_score or 0
  local business_value = epic.business_value or 0

  -- Complex business logic in Lua
  if wsjf > 50 and business_value > 70 then
    return {
      decision = "autonomous",
      confidence = 0.95,
      reasoning = "High WSJF and business value"
    }
  elseif wsjf > 30 then
    return {
      decision = "collaborative",
      confidence = 0.75,
      reasoning = "Moderate WSJF, needs review"
    }
  else
    return {
      decision = "escalated",
      confidence = 0.5,
      reasoning = "Low WSJF, human decision required"
    }
  end
end
```

**Benefits:**
- ✅ Hot-reload rules without recompiling
- ✅ Store rules in database (evolve via consensus!)
- ✅ A/B test rules (different Lua scripts)
- ✅ User-defined rules (safe sandboxing)
- ✅ Version rules in Git

**Implementation:**
```elixir
# Add to rule_engine.ex
defp do_execute(rule_id, context, correlation_id, state) do
  case RuleLoader.get_rule(rule_id) do
    {:ok, %{type: :lua, script: lua_code}} ->
      # Execute Lua rule!
      {:ok, result} = LuaRunner.execute(lua_code, context)
      classify_result(result)

    {:ok, %{type: :elixir, module: mod}} ->
      # Fall back to Elixir rules
      mod.execute(context)
  end
end
```

**Use Cases:**
- Epic/Feature validation rules
- Code quality gates
- Approval workflows
- Budget allocation
- Resource scheduling
- Priority calculations

---

### 2. Agent Behavior Configuration 🔥 **HIGH IMPACT**

**Current Problem:**
```elixir
# lib/singularity/agents/cost_optimized_agent.ex
# Agent behavior is HARDCODED
defp build_llm_prompt(task, rule_result, specialization) do
  # Fixed prompt building logic
  # Need recompile to change agent behavior
end
```

**With Lua:**
```lua
-- agents/behaviors/cost_optimizer.lua
function build_task_prompt(task, rule_result, specialization)
  local prompt = Prompt.new()

  -- Dynamic agent behavior!
  if task.cost_sensitive then
    -- Use cheaper models, simpler prompts
    prompt:section("Budget Constraint", task.max_cost_cents)
    prompt:instruction("Optimize for cost over quality")
  else
    -- Full quality, no restrictions
    prompt:section("Task", task.description)
    prompt:instruction("Optimize for quality")
  end

  -- Read similar tasks for learning
  local similar = workspace.glob("history/**/task-" .. task.id .. "-*.json")
  for _, file in ipairs(similar) do
    local past = json.decode(workspace.read_file(file))
    if past.success then
      prompt:section("Success Pattern", past.approach)
    end
  end

  return prompt
end
```

**Benefits:**
- ✅ Configure agent personalities without code
- ✅ A/B test agent behaviors
- ✅ Hot-reload agent logic
- ✅ Store behaviors in DB
- ✅ Agents learn by updating Lua scripts!

**Implementation:**
```elixir
# Add to agents/
defmodule Singularity.Agent do
  def execute_task(task, opts) do
    # Load agent behavior from Lua
    behavior_script = Keyword.get(opts, :behavior, "default.lua")
    {:ok, lua_code} = File.read("agent_behaviors/#{behavior_script}")

    # Execute Lua to get prompt
    {:ok, prompt_messages} = LuaRunner.execute(lua_code, %{
      task: task,
      project_root: File.cwd!(),
      agent_id: self()
    })

    # Call LLM with dynamic prompt
    LLM.Service.call(:medium, prompt_messages)
  end
end
```

---

### 3. SPARC Workflow Steps → Lua Scripts 🔥 **HIGH IMPACT**

**Current Problem:**
```elixir
# SPARC steps are hardcoded Elixir functions
# Can't customize without code changes
```

**With Lua:**
```lua
-- workflows/sparc/specification_phase.lua
function execute_specification(requirements, context)
  local prompt = Prompt.new()

  -- Read existing architecture
  if workspace.file_exists("docs/ARCHITECTURE.md") then
    prompt:section("Current Architecture", workspace.read_file("docs/ARCHITECTURE.md"))
  end

  -- Get recent changes
  local commits = git.log({max_count = 10})
  prompt:section("Recent Work", table.concat(commits, "\n"))

  -- Check for similar features
  local similar_features = workspace.glob("features/**/*" .. requirements.domain .. "*.ex")
  if #similar_features > 0 then
    prompt:section("AVOID DUPLICATION", "Similar features exist")
    for _, file in ipairs(similar_features) do
      prompt:bullet(file)
    end
  end

  -- Build specification request
  prompt:section("Requirements", requirements.description)
  prompt:instruction("Create SPARC specification following:")
  prompt:bullet("Clear acceptance criteria")
  prompt:bullet("Technical constraints")
  prompt:bullet("Integration points")

  return prompt
end
```

**Benefits:**
- ✅ Customize SPARC phases per project
- ✅ Hot-reload workflow logic
- ✅ Team-specific workflows
- ✅ Domain-specific SPARC variants

---

### 4. Configuration as Lua 🟡 **MEDIUM IMPACT**

**Current Problem:**
```elixir
# config/config.exs
# Static configuration, need recompile
config :singularity, :llm,
  complexity_thresholds: %{
    simple: 1000,
    medium: 5000,
    complex: 10000
  }
```

**With Lua:**
```lua
-- config/runtime.lua
function get_llm_config(env)
  if env == "production" then
    return {
      complexity_thresholds = {
        simple = 500,   -- Stricter in prod
        medium = 3000,
        complex = 8000
      },
      cost_limit_cents = 1000,
      enable_caching = true
    }
  else
    return {
      complexity_thresholds = {
        simple = 2000,  -- Looser in dev
        medium = 10000,
        complex = 50000
      },
      cost_limit_cents = nil,  -- No limit in dev
      enable_caching = false   -- Fresh calls in dev
    }
  end
end
```

**Benefits:**
- ✅ Dynamic config without restart
- ✅ Environment-specific logic
- ✅ Feature flags in Lua
- ✅ A/B test configs

**Implementation:**
```elixir
defmodule Singularity.Config do
  def get(key) do
    # Load config from Lua
    {:ok, lua_code} = File.read("config/runtime.lua")
    {:ok, config} = LuaRunner.execute(lua_code, %{env: Mix.env()})
    Map.get(config, key)
  end
end
```

---

### 5. Data Transformations 🟡 **MEDIUM IMPACT**

**Use Case:** ETL pipelines, data cleanup, migrations

```lua
-- transforms/clean_code_chunks.lua
function transform_chunk(chunk)
  -- Clean up code chunk data
  local cleaned = {
    path = chunk.path:gsub("^./", ""),  -- Remove leading ./
    language = detect_language(chunk.path),
    content = chunk.content:gsub("[\r\n]+$", ""),  -- Trim trailing newlines
    size_bytes = #chunk.content
  }

  -- Extract metadata
  if cleaned.language == "elixir" then
    cleaned.module = chunk.content:match("defmodule%s+([%w%.]+)")
  end

  return cleaned
end
```

**Implementation:**
```elixir
def transform_data(data, transform_script) do
  {:ok, lua_code} = File.read("transforms/#{transform_script}")

  Enum.map(data, fn item ->
    {:ok, [transformed]} = LuaRunner.execute(lua_code, %{item: item})
    transformed
  end)
end
```

---

### 6. Test Scenarios 🟢 **LOW IMPACT (but cool!)**

**Current:** Tests in Elixir (need recompile)

**With Lua:**
```lua
-- tests/scenarios/agent_workflow.lua
function test_agent_task_execution()
  local agent = Agent.new("cost_optimizer")

  local task = {
    description = "Generate authentication module",
    cost_sensitive = true,
    max_cost_cents = 50
  }

  local result = agent:execute(task)

  assert(result.success == true, "Task should succeed")
  assert(result.cost_cents <= 50, "Should stay under budget")
  assert(string.find(result.code, "defmodule"), "Should generate valid code")

  return {passed = true, duration_ms = 150}
end
```

---

## Implementation Priority

### P0 - Critical (Do This Month)

**1. Rules Engine with Lua Rules**
- **Impact:** MASSIVE - hot-reload business logic
- **Effort:** 4 hours
- **Files to change:**
  - `rule_engine.ex` - Add Lua rule execution
  - `rule_loader.ex` - Load Lua scripts from DB
  - Create `rules/*.lua` examples

**Steps:**
```bash
# 1. Add rule type to schema
ALTER TABLE rules ADD COLUMN type VARCHAR(10) DEFAULT 'elixir';
ALTER TABLE rules ADD COLUMN lua_script TEXT;

# 2. Update RuleEngine to support Lua
vim lib/singularity/execution/autonomy/rule_engine.ex

# 3. Create example Lua rules
mkdir -p rules/examples
vim rules/examples/epic_validation.lua

# 4. Test hot-reload
# Save new Lua script → DB → Execute immediately!
```

### P1 - High Priority (Next Quarter)

**2. Agent Behavior Configuration**
- **Impact:** HIGH - customize agents without code
- **Effort:** 6 hours
- **Create:** `agent_behaviors/*.lua`

**3. SPARC Workflow Lua Steps**
- **Impact:** HIGH - team-specific workflows
- **Effort:** 8 hours
- **Create:** `workflows/sparc/*.lua`

### P2 - Medium Priority (When Needed)

**4. Configuration as Lua**
- **Impact:** MEDIUM - dynamic config
- **Effort:** 3 hours

**5. Data Transforms**
- **Impact:** MEDIUM - flexible ETL
- **Effort:** 2 hours

### P3 - Low Priority (Nice to Have)

**6. Test Scenarios**
- **Impact:** LOW - interesting but not critical
- **Effort:** 4 hours

---

## Comparison: Current vs Full Lua Usage

### Current (Prompts Only)

```
Lua Usage: 5%
└── LLM Prompts (19 scripts)
    └── Dynamic prompt building with file reading

Everything else: Hardcoded Elixir
└── Rules → Need recompile
└── Agent behavior → Need recompile
└── Workflows → Need recompile
└── Config → Need restart
```

### With Full Lua Usage

```
Lua Usage: 60%
├── LLM Prompts (19 scripts) ✅
├── Rules (Lua in DB) 🔥
│   └── Hot-reload business logic
├── Agent Behaviors (Lua files) 🔥
│   └── Configure without code
├── SPARC Workflows (Lua steps) 🔥
│   └── Team-specific variants
├── Configuration (runtime.lua) 🟡
│   └── Dynamic feature flags
└── Data Transforms (ETL) 🟡
    └── Flexible pipelines

Only Core Logic: Elixir (40%)
└── NIF engines (Rust)
└── Database layer
└── OTP supervision
└── NATS messaging
```

---

## Benefits of Expanding Lua Usage

### 1. Hot Reload Everything

**Before:**
```elixir
# Change rule logic
vim lib/rules/epic_validator.ex
mix compile
# Restart server
```

**After:**
```lua
# Change rule logic
vim rules/epic_validator.lua
# Save to DB
# ✅ IMMEDIATELY ACTIVE (no restart!)
```

### 2. Database-Backed Logic

**Rules evolve via consensus:**
```elixir
# Store Lua script in Postgres
RuleEvolutionManager.propose_rule(%{
  category: :epic,
  lua_script: File.read!("rules/epic_validator.lua"),
  version: "v2.0",
  proposed_by: "agent_123"
})

# Vote on rule
RuleEvolutionManager.vote(rule_id, :approve)

# When consensus reached → deployed automatically!
```

### 3. A/B Testing

**Test different behaviors:**
```elixir
# 50% traffic gets aggressive optimizer
# 50% traffic gets conservative optimizer
behavior = if :rand.uniform() < 0.5 do
  "cost_optimizer_aggressive.lua"
else
  "cost_optimizer_conservative.lua"
end

Agent.execute_task(task, behavior: behavior)
```

### 4. User-Defined Logic

**Let users customize (safely sandboxed):**
```lua
-- User uploads custom rule
function my_team_epic_validation(epic)
  -- Team-specific logic
  if epic.team == "infrastructure" then
    return {decision = "autonomous"}  -- Trust infra team
  else
    return {decision = "collaborative"}  -- Review others
  end
end
```

### 5. Learning System

**Agents improve by evolving their Lua scripts:**
```elixir
# Agent completes task
result = Agent.execute_task(task, behavior: "optimizer_v1.lua")

# Track success
if result.success and result.cost_cents < budget do
  # Generate improved behavior via LLM
  improved_lua = LLM.Service.call(:complex, [
    %{role: "user", content: "Improve this Lua script based on success: ..."}
  ])

  # Save as v2
  File.write!("agent_behaviors/optimizer_v2.lua", improved_lua)

  # A/B test v1 vs v2
end
```

---

## Quick Wins (< 1 Hour Each)

### Win 1: Template Renderer with Lua

**Add to TemplateService:**
```elixir
def render_template_with_lua(template_id, variables) do
  lua_path = "templates/#{template_id}.lua"

  if File.exists?(lua_path) do
    {:ok, lua_code} = File.read(lua_path)
    LuaRunner.execute(lua_code, variables)
  else
    # Fall back to Handlebars
    render_template_with_solid(template_id, variables)
  end
end
```

### Win 2: Agent Prompt Customization

**Add to Agent:**
```elixir
def build_prompt(task, opts) do
  custom_lua = Keyword.get(opts, :prompt_builder)

  if custom_lua do
    {:ok, lua_code} = File.read("prompts/#{custom_lua}")
    {:ok, messages} = LuaRunner.execute(lua_code, %{task: task})
    messages
  else
    # Default prompt building
    default_prompt(task)
  end
end
```

### Win 3: Config Overrides

**Add to Config:**
```elixir
def get_with_lua_override(key) do
  lua_config = "config/overrides.lua"

  if File.exists?(lua_config) do
    {:ok, lua_code} = File.read(lua_config)
    {:ok, overrides} = LuaRunner.execute(lua_code, %{env: Mix.env()})
    Map.get(overrides, key) || Application.get_env(:singularity, key)
  else
    Application.get_env(:singularity, key)
  end
end
```

---

## Architecture: Lua-First Design

### Core Principle

**"If it can change without breaking the system, it should be in Lua."**

### Decision Matrix

| Logic Type | Use Elixir? | Use Lua? | Why |
|------------|-------------|----------|-----|
| OTP supervision | ✅ | ❌ | Core infrastructure |
| Database queries | ✅ | ❌ | Type safety critical |
| NATS messaging | ✅ | ❌ | Performance critical |
| Rust NIF calls | ✅ | ❌ | FFI boundary |
| **Business rules** | ❌ | ✅ | Changes frequently |
| **Agent behavior** | ❌ | ✅ | Needs customization |
| **Workflow steps** | ❌ | ✅ | Team-specific |
| **Prompt building** | ❌ | ✅ | **Already doing this!** |
| **Config logic** | ❌ | ✅ | Environment-specific |
| **Data transforms** | ❌ | ✅ | Pipeline flexibility |

---

## Migration Path

### Phase 1: Rules Engine (1 month)
1. Add Lua support to RuleEngine
2. Migrate 5 critical rules to Lua
3. Test hot-reload in production
4. Measure performance impact

### Phase 2: Agent Behaviors (1 month)
1. Extract agent prompt building to Lua
2. Create behavior library
3. A/B test behaviors
4. Implement learning loop

### Phase 3: SPARC Workflows (2 months)
1. Move SPARC steps to Lua
2. Create team-specific variants
3. Enable user customization
4. Track workflow success rates

### Phase 4: Full Adoption (ongoing)
1. New features default to Lua-first
2. Migrate remaining hardcoded logic
3. Build library of reusable Lua modules
4. Community contributions

---

## Summary

### Current Reality

**You're using Lua for only 5% of what it could do:**
- ✅ 19 prompt scripts in `templates_data/prompt_library/`
- ❌ Everything else hardcoded in Elixir

### The Opportunity

**Lua could power 60% of your system:**
1. 🔥 **Rules Engine** - Hot-reload business logic (HUGE!)
2. 🔥 **Agent Behaviors** - Configure without recompile (HUGE!)
3. 🔥 **SPARC Workflows** - Team-specific customization (HUGE!)
4. 🟡 **Configuration** - Dynamic feature flags
5. 🟡 **Data Transforms** - Flexible ETL
6. 🟢 **Test Scenarios** - Nice to have

### Recommended Action

**Start with Rules Engine (P0):**
1. Spend 4 hours this week
2. Add Lua rule execution to RuleEngine
3. Migrate 1 rule as proof-of-concept
4. Hot-reload it (mind = blown 🤯)
5. Expand from there!

**Impact:** Your system becomes 10x more flexible without sacrificing performance!

---

**Want me to implement the Rules Engine Lua integration first?** It's the highest-impact change and only takes ~4 hours! 🚀
