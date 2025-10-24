# Agent System Fix Checklist
**Status:** All agents DISABLED - Fix to re-enable
**Estimated Total Time:** 7-12 hours
**Priority:** CRITICAL

---

## Phase 1: Critical Blockers (4-6 hours)

### ✅ Task 1: Fix RuntimeBootstrapper Undefined Module
**Priority:** CRITICAL
**Estimated Time:** 1-2 hours
**File:** `singularity/lib/singularity/agents/runtime_bootstrapper.ex`

**Current Code (Line 62):**
```elixir
child_spec = Singularity.SelfImprovingAgent.child_spec(spec_opts)
```

**Fix:**
```elixir
child_spec = Singularity.Agent.child_spec(spec_opts)
```

**Test:**
```bash
# Should compile without errors
mix compile

# Should show agent starting
iex -S mix
# In IEx:
Process.whereis(Singularity.Agents.RuntimeBootstrapper)
```

**Checklist:**
- [ ] Update line 62 in runtime_bootstrapper.ex
- [ ] Run `mix compile`
- [ ] Verify no undefined module errors
- [ ] Test agent startup in iex

---

### ✅ Task 2: Resolve Agent Namespace Collision
**Priority:** CRITICAL
**Estimated Time:** 2-3 hours
**Files:**
- `singularity/lib/singularity/agents/agent.ex` (rename)
- `singularity/lib/singularity/agent.ex` (new alias)

**Step 1: Rename base class**
```bash
cd singularity/lib/singularity/agents
git mv agent.ex base.ex
```

**Step 2: Update module definition**
```elixir
# In agents/base.ex
defmodule Singularity.Agents.Base do
  @moduledoc """
  Base GenServer for all agent implementations.

  IMPORTANT: This is Singularity.Agents.Base (NOT Singularity.Agent)
  Use Singularity.Agent alias for backwards compatibility.
  """
  # ... rest of code
end
```

**Step 3: Create alias module**
```elixir
# New file: singularity/lib/singularity/agent.ex
defmodule Singularity.Agent do
  @moduledoc """
  Alias to Singularity.Agents.Base for backwards compatibility.

  This module exists to prevent namespace collisions.
  All implementations should use Singularity.Agents.Base directly.
  """

  defdelegate child_spec(opts), to: Singularity.Agents.Base
  defdelegate start_link(opts), to: Singularity.Agents.Base
  defdelegate via_tuple(id), to: Singularity.Agents.Base
  defdelegate improve(agent_id, payload), to: Singularity.Agents.Base
  defdelegate update_metrics(agent_id, metrics), to: Singularity.Agents.Base
  defdelegate record_outcome(agent_id, outcome), to: Singularity.Agents.Base
  defdelegate force_improvement(agent_id, reason), to: Singularity.Agents.Base
  defdelegate execute_task(agent_id, task, context), to: Singularity.Agents.Base
end
```

**Step 4: Update references**
```bash
# Update runtime_bootstrapper.ex
# Update agent_spawner.ex (if needed)
# Update any other files referencing Singularity.Agent
```

**Test:**
```bash
mix compile
# Should compile without warnings

# Test alias works
iex -S mix
alias Singularity.Agent
Agent.execute_task("test", "task", %{})
```

**Checklist:**
- [ ] Rename agents/agent.ex → agents/base.ex
- [ ] Update module name to Singularity.Agents.Base
- [ ] Create new singularity/agent.ex with alias
- [ ] Add all delegations to alias
- [ ] Update runtime_bootstrapper.ex references
- [ ] Update agent_spawner.ex references
- [ ] Run `mix compile`
- [ ] Verify no warnings
- [ ] Test alias in iex
- [ ] Update tests if needed

---

### ✅ Task 3: Make NATS/Oban Optional
**Priority:** HIGH
**Estimated Time:** 2-3 hours
**Files:**
- `singularity/config/config.exs`
- `singularity/lib/singularity/agents/runtime_bootstrapper.ex`
- `singularity/lib/singularity/jobs/agent_evolution_worker.ex`

**Step 1: Add config flags**
```elixir
# In config/config.exs
config :singularity, :agents,
  enable_nats: System.get_env("ENABLE_NATS") == "true",
  enable_oban: System.get_env("ENABLE_OBAN") == "true",
  enable_evolution: System.get_env("ENABLE_EVOLUTION", "false") == "true",
  enable_feeders: System.get_env("ENABLE_FEEDERS", "false") == "true"
```

**Step 2: Update RuntimeBootstrapper**
```elixir
# In agents/runtime_bootstrapper.ex
@impl true
def init(opts) do
  state = %{
    agent_id: Keyword.get(opts, :agent_id, "task_graph-runtime"),
    agent_opts: Keyword.get(opts, :agent_opts, []),
    enabled: Application.get_env(:singularity, :agents)[:enable_evolution]
  }

  if state.enabled do
    {:ok, state, {:continue, :bootstrap}}
  else
    Logger.info("Agent evolution disabled - skipping bootstrap")
    {:ok, state}
  end
end
```

**Step 3: Update Agents.Supervisor**
```elixir
# In agents/supervisor.ex
@impl true
def init(_opts) do
  Logger.info("Starting Agents Supervisor...")

  children =
    if Application.get_env(:singularity, :agents)[:enable_evolution] do
      [
        Singularity.Agents.RuntimeBootstrapper,
        Singularity.AgentSupervisor
      ]
    else
      [
        Singularity.AgentSupervisor  # Only start DynamicSupervisor
      ]
    end

  Supervisor.init(children, strategy: :one_for_one)
end
```

**Test:**
```bash
# Test without NATS/Oban
ENABLE_NATS=false ENABLE_OBAN=false ENABLE_EVOLUTION=false mix compile
mix test

# Test with evolution enabled
ENABLE_EVOLUTION=true iex -S mix
```

**Checklist:**
- [ ] Add config flags to config.exs
- [ ] Update RuntimeBootstrapper.init/1
- [ ] Update Agents.Supervisor.init/1
- [ ] Test compilation without flags
- [ ] Test compilation with flags
- [ ] Run tests
- [ ] Verify agent spawning works
- [ ] Document flags in README

---

## Phase 2: Consolidation (3-6 hours)

### ✅ Task 4: Consolidate Health Modules
**Priority:** MEDIUM
**Estimated Time:** 2-4 hours
**Files:**
- `singularity/lib/singularity/infrastructure/health_agent.ex` (delete)
- `singularity/lib/singularity/health/agent_health.ex` (expand)

**Step 1: Review both modules**
```bash
# Check what Infrastructure.HealthAgent does
cat singularity/lib/singularity/infrastructure/health_agent.ex

# Check what Health.AgentHealth does
cat singularity/lib/singularity/health/agent_health.ex
```

**Step 2: Merge functionality**
```elixir
# In health/agent_health.ex - add service monitoring functions
defmodule Singularity.Health.AgentHealth do
  @moduledoc """
  Unified health monitoring for both agents and services.

  ## Agent Health
  - get_agent_status/1 - Get single agent status
  - get_all_agents_status/0 - Get all agents

  ## Service Health
  - check_service_status/0 - Check all services
  - detect_service_failures/0 - Find failures
  - restart_failed_services/0 - Auto-recovery
  - monitor_service_performance/0 - Performance metrics
  """

  # Existing agent health functions...

  # Add service health functions from Infrastructure.HealthAgent
  def check_service_status() do
    # Merge implementation
  end

  def detect_service_failures() do
    # Merge implementation
  end

  # ... etc
end
```

**Step 3: Update references**
```bash
# Find all references to Infrastructure.HealthAgent
grep -r "Infrastructure.HealthAgent" singularity/lib/
grep -r "infrastructure/health_agent" singularity/lib/

# Update to Health.AgentHealth
```

**Step 4: Delete duplicate**
```bash
git rm singularity/lib/singularity/infrastructure/health_agent.ex
```

**Test:**
```bash
mix compile
mix test

# Manual test
iex -S mix
Singularity.Health.AgentHealth.check_service_status()
Singularity.Health.AgentHealth.get_all_agents_status()
```

**Checklist:**
- [ ] Review both health modules
- [ ] Copy service functions to Health.AgentHealth
- [ ] Test merged functionality
- [ ] Update all references
- [ ] Delete infrastructure/health_agent.ex
- [ ] Run tests
- [ ] Update documentation
- [ ] Verify no regressions

---

### ✅ Task 5: Move Test Feeders
**Priority:** LOW
**Estimated Time:** 1 hour
**Files:**
- `singularity/lib/singularity/agents/metrics_feeder.ex`
- `singularity/lib/singularity/agents/real_workload_feeder.ex`

**Step 1: Create test/support directory**
```bash
mkdir -p singularity/test/support/agents
```

**Step 2: Move files**
```bash
git mv singularity/lib/singularity/agents/metrics_feeder.ex \
         singularity/test/support/agents/
git mv singularity/lib/singularity/agents/real_workload_feeder.ex \
         singularity/test/support/agents/
```

**Step 3: Update module docs**
```elixir
# In test/support/agents/metrics_feeder.ex
defmodule Singularity.Agents.MetricsFeeder do
  @moduledoc """
  TEST SUPPORT ONLY - Feeds synthetic metrics to agents.

  This module is for testing self-improvement cycles.
  DO NOT use in production.
  """
end
```

**Step 4: Update test helper**
```elixir
# In test/test_helper.exs
Code.require_file("support/agents/metrics_feeder.ex", __DIR__)
Code.require_file("support/agents/real_workload_feeder.ex", __DIR__)
```

**Step 5: Remove from supervision**
```elixir
# Ensure NOT in Agents.Supervisor children list
```

**Test:**
```bash
mix test
# Feeders should still work in tests
```

**Checklist:**
- [ ] Create test/support/agents directory
- [ ] Move metrics_feeder.ex
- [ ] Move real_workload_feeder.ex
- [ ] Update moduledocs
- [ ] Add to test_helper.exs
- [ ] Remove from supervision tree
- [ ] Run tests
- [ ] Verify feeders work in tests

---

## Phase 3: Verification (1-2 hours)

### ✅ Task 6: Full System Test
**Priority:** HIGH
**Estimated Time:** 1-2 hours

**Checklist:**
- [ ] Run `mix compile` - no errors
- [ ] Run `mix test` - all pass
- [ ] Run `mix dialyzer` - no new warnings
- [ ] Run `mix credo --strict` - no new issues
- [ ] Start iex: `iex -S mix`
- [ ] Test agent spawning:
  ```elixir
  config = %{"role" => "cost_optimized", "config" => %{}}
  {:ok, agent} = Singularity.Agents.AgentSpawner.spawn(config)
  ```
- [ ] Test agent execution:
  ```elixir
  Singularity.Agent.execute_task(agent.id, "test_task", %{})
  ```
- [ ] Verify no undefined module errors
- [ ] Check supervision tree:
  ```elixir
  Supervisor.which_children(Singularity.Agents.Supervisor)
  ```
- [ ] Test health monitoring:
  ```elixir
  Singularity.Health.AgentHealth.get_all_agents_status()
  ```

---

## Phase 4: Documentation (1 hour)

### ✅ Task 7: Update Documentation
**Priority:** MEDIUM
**Estimated Time:** 1 hour

**Files to Update:**
- [ ] AGENTS.md - Reflect current state
- [ ] SELFEVOLVE.md - Update evolution status
- [ ] README.md - Update agent system section
- [ ] CLAUDE.md - Update agent documentation section

**Update Checklist:**
- [ ] Document all 23 agent modules
- [ ] Document fix history
- [ ] Document config flags
- [ ] Document testing approach
- [ ] Add troubleshooting section
- [ ] Update architecture diagrams

---

## Success Criteria

### Compilation
- [ ] `mix compile` succeeds
- [ ] No undefined module errors
- [ ] No compiler warnings
- [ ] Dialyzer passes

### Startup
- [ ] Application starts without NATS/Oban
- [ ] Agents.Supervisor starts
- [ ] AgentSupervisor ready
- [ ] No RuntimeBootstrapper errors

### Functionality
- [ ] Can spawn agents dynamically
- [ ] Can execute tasks via agents
- [ ] Agent health monitoring works
- [ ] ProcessRegistry lookups work

### Tests
- [ ] All existing tests pass
- [ ] New tests for fixes pass
- [ ] Integration tests work
- [ ] No test failures

---

## Rollback Plan

If fixes fail, rollback:

```bash
# Revert all changes
git checkout main

# Or revert specific files
git checkout HEAD -- singularity/lib/singularity/agents/runtime_bootstrapper.ex
git checkout HEAD -- singularity/lib/singularity/agents/agent.ex
```

---

## After Completion

Once all tasks complete:

1. **Create PR** with changes
2. **Run CI** to verify
3. **Update AGENTS.md** with current state
4. **Enable agents** in config
5. **Monitor startup** for issues
6. **Test in development** before production

---

## Questions/Blockers

Track any blockers here:

- [ ] Question 1: Which module should RuntimeBootstrapper use?
- [ ] Question 2: Should we consolidate all agent implementations?
- [ ] Question 3: Keep test feeders or delete?
- [ ] Question 4: Make evolution optional permanently?

---

**Next:** Start with Task 1 (RuntimeBootstrapper fix) - CRITICAL blocker
