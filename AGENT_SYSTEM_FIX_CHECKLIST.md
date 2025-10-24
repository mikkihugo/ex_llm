# Agent System Fix Checklist

**Goal**: Get agents running and self-evolution system operational
**Timeline**: 2-5 weeks depending on scope
**Current Status**: 0/16 components running (31% infrastructure only)

---

## Phase 1: Fix Oban (Week 1)

### Task 1.1: Diagnose Oban Config Issue (2 hours)
- [ ] Read `config/config.exs` completely
- [ ] Find duplicate Oban configurations (`:singularity` vs `:oban` keys)
- [ ] Document current config structure
- [ ] Identify which config is correct

**Files to check**:
- `singularity/config/config.exs`
- `singularity/config/dev.exs`
- `singularity/config/test.exs`
- `singularity/config/prod.exs`

**Expected issue**:
```elixir
# Duplicate config keys causing nil.config/0 error
config :singularity, Oban, [...]
config :oban, [...]  # Conflict!
```

### Task 1.2: Consolidate Oban Config (1 hour)
- [ ] Choose single config key (recommend `:singularity, Oban`)
- [ ] Merge all Oban settings into single config block
- [ ] Remove duplicate/conflicting configs
- [ ] Test config loads without errors

**Expected fix**:
```elixir
# Single, consolidated Oban config
config :singularity, Oban,
  repo: Singularity.Repo,
  queues: [
    training: [concurrency: 1],
    maintenance: [concurrency: 3],
    metrics: [concurrency: 1],
    default: [concurrency: 10]
  ],
  plugins: [
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Stalled, interval: 60},
    {Oban.Plugins.Cron, crontab: [...]}
  ]
```

### Task 1.3: Re-Enable Oban in Application (5 minutes)
- [ ] Open `singularity/lib/singularity/application.ex`
- [ ] Uncomment line 45: `# Oban,`
- [ ] Save file

**Change**:
```elixir
# Before
# Oban,

# After
Oban,
```

### Task 1.4: Test Oban Starts (1 hour)
- [ ] `cd singularity`
- [ ] `mix compile`
- [ ] `iex -S mix phx.server`
- [ ] Check Oban starts without nil.config/0 error
- [ ] Verify cron jobs scheduled: `Oban.check_queue(:default)`

**Success criteria**:
```elixir
iex> Oban.config()
# Returns config, not nil

iex> Oban.check_queue(:default)
# Returns queue info, not error
```

---

## Phase 2: Fix NATS (Week 2)

### Task 2.1: Diagnose NATS Test Issues (4 hours)
- [ ] Run test suite: `mix test`
- [ ] Identify tests failing when NATS unavailable
- [ ] Document which tests need NATS
- [ ] Determine if NATS should be mocked or conditionally started

**Common failures**:
```
** (exit) exited in: GenServer.call(Singularity.NATS.Client, ...)
** (EXIT) no process: the process is not alive
```

### Task 2.2: Add NATS Availability Check (4 hours)
- [ ] Create `test/support/nats_helpers.ex` with availability check
- [ ] Add `@tag :nats` to tests requiring NATS
- [ ] Update `test/test_helper.exs` to skip `:nats` tests if unavailable
- [ ] OR: Mock NATS client for tests

**Option A: Skip when unavailable**
```elixir
# test/test_helper.exs
nats_available = match?({:ok, _}, NATS.Client.health_check())
ExUnit.configure(exclude: [nats: !nats_available])
```

**Option B: Mock NATS**
```elixir
# test/support/mocks.ex
Mox.defmock(NATSClientMock, for: Singularity.NATS.ClientBehaviour)
```

### Task 2.3: Re-Enable NATS Supervisor (5 minutes)
- [ ] Open `application.ex`
- [ ] Uncomment line 53: `# Singularity.NATS.Supervisor,`
- [ ] Save file

**Change**:
```elixir
# Before
# Singularity.NATS.Supervisor,

# After
Singularity.NATS.Supervisor,
```

### Task 2.4: Test NATS Connectivity (1 hour)
- [ ] Ensure `nats-server -js` is running
- [ ] `iex -S mix phx.server`
- [ ] Verify NATS.Supervisor starts
- [ ] Test connectivity: `Singularity.NATS.Client.health_check()`

**Success criteria**:
```elixir
iex> Process.whereis(Singularity.NATS.Supervisor)
# Returns PID (not nil)

iex> Singularity.NATS.Client.health_check()
{:ok, :connected}
```

---

## Phase 3: Re-Enable Domain Supervisors (Week 3)

### Task 3.1: LLM Supervisor (1 day)
- [ ] Uncomment line 58 in `application.ex`
- [ ] Test LLM.RateLimiter starts
- [ ] Verify LLM service can route to providers
- [ ] Run related tests

### Task 3.2: Knowledge Supervisor (1 day)
- [ ] Uncomment line 61 in `application.ex`
- [ ] Test TemplateService, TemplatePerformanceTracker, CodeStore start
- [ ] Verify knowledge artifacts queryable
- [ ] Run related tests

### Task 3.3: Learning Supervisor (1 day)
- [ ] Uncomment line 64 in `application.ex`
- [ ] Test ExperimentResultConsumer starts
- [ ] Verify Genesis integration works
- [ ] Run related tests

### Task 3.4: Planning, SPARC, Todos Supervisors (2 days)
- [ ] Uncomment lines 72, 75, 78 in `application.ex`
- [ ] Test each supervisor starts independently
- [ ] Verify no circular dependencies
- [ ] Run integration tests

---

## Phase 4: Re-Enable Agents (Week 4)

### Task 4.1: Agents Supervisor (1 hour)
- [ ] Uncomment line 86 in `application.ex`: `# Singularity.Agents.Supervisor,`
- [ ] Test RuntimeBootstrapper starts
- [ ] Test AgentSupervisor (DynamicSupervisor) starts
- [ ] Verify agent lookup works via ProcessRegistry

**Change**:
```elixir
# Before
# Singularity.Agents.Supervisor,

# After
Singularity.Agents.Supervisor,
```

### Task 4.2: ApplicationSupervisor (1 hour)
- [ ] Uncomment line 89 in `application.ex`
- [ ] Test Control and Runner start
- [ ] Verify no duplicate supervision
- [ ] Run related tests

### Task 4.3: Test Agent Spawning (1 day)
- [ ] Try spawning SelfImprovingAgent
- [ ] Try spawning CostOptimizedAgent
- [ ] Try spawning other agent types
- [ ] Verify agents can execute tasks

**Test commands**:
```elixir
# Spawn self-improving agent
{:ok, pid} = Singularity.Agent.start_link(id: "test-agent-001")

# Check it's running
Process.alive?(pid)  # Should be true

# Update metrics
Singularity.Agent.update_metrics("test-agent-001", %{latency_ms: 100})

# Enqueue improvement
Singularity.Agent.improve("test-agent-001", %{type: :pattern_learning})
```

### Task 4.4: Re-Enable Documentation Agents (1 day)
- [ ] Uncomment lines 98-100 in `application.ex`
- [ ] Test DocumentationUpgrader starts
- [ ] Test QualityEnforcer starts
- [ ] Test DocumentationPipeline starts
- [ ] Run documentation system tests

### Task 4.5: Full System Test (2 days)
- [ ] Run complete test suite: `mix test`
- [ ] Verify all agents can be spawned
- [ ] Test agent lifecycle (spawn → execute → stop)
- [ ] Test metrics collection via telemetry
- [ ] Test Oban workers execute
- [ ] Test NATS messaging works
- [ ] Test self-evolution feedback loop

---

## Phase 5: Update Documentation (Week 5)

### Task 5.1: Update Status Warnings (2 hours)
- [ ] `AGENTS.md` - Remove "⚠️ NOT RUNNING" warning once agents work
- [ ] `AGENT_BRIEFING.md` - Update supervision status section
- [ ] `SELFEVOLVE.md` - Update Oban/NATS/agent status

### Task 5.2: Rename Aspirational Docs (1 hour)
- [ ] Rename `AGENT_SELF_EVOLUTION_2.3.0.md` → `AGENT_SELF_EVOLUTION_DESIGN.md`
- [ ] Rename `AGENT_DOCUMENTATION_SYSTEM.md` → `DOCUMENTATION_SYSTEM_DESIGN.md`
- [ ] Add "DESIGN DOCUMENT - NOT YET IMPLEMENTED" headers

### Task 5.3: Create Testing Guide (1 day)
- [ ] Document how to test agents
- [ ] Document how to verify self-evolution
- [ ] Document how to troubleshoot common issues
- [ ] Create example agent spawning scenarios

### Task 5.4: Update Architecture Diagrams (1 day)
- [ ] Update SYSTEM_FLOWS.md with working supervision tree
- [ ] Update agent lifecycle diagrams
- [ ] Update self-evolution flow diagrams
- [ ] Ensure all Mermaid diagrams reflect reality

---

## Verification Checklist (Final)

### System Health
- [ ] `iex -S mix phx.server` starts without errors
- [ ] All supervisors show as running: `Supervisor.which_children(Singularity.Supervisor)`
- [ ] Oban workers scheduled: `Oban.config().plugins`
- [ ] NATS connected: `Singularity.NATS.Client.health_check()`

### Agent System
- [ ] Agents.Supervisor running: `Process.whereis(Singularity.Agents.Supervisor)`
- [ ] Can spawn agents: `Singularity.Agent.start_link(id: "test")`
- [ ] RuntimeBootstrapper creates self-improving agent
- [ ] Agents show in dashboard: Visit http://localhost:4000/agents

### Self-Evolution
- [ ] Telemetry events collected
- [ ] Metrics aggregated (check `agent_metrics` table)
- [ ] Feedback analyzer runs (check logs for "FeedbackAnalysisWorker")
- [ ] Agent evolution runs (check logs for "AgentEvolutionWorker")
- [ ] Knowledge export runs daily (check `templates_data/learned/`)

### Documentation
- [ ] All docs have accurate status indicators
- [ ] No claims of active systems that aren't running
- [ ] Aspirational docs clearly labeled as designs
- [ ] New testing guide available

---

## Rollback Plan (If Something Breaks)

### Quick Rollback
1. Re-comment the supervisor that broke
2. `git checkout application.ex` to restore previous state
3. Investigate issue before re-attempting

### Safe Re-Enable Order
1. **Always** fix Oban first (nothing works without it)
2. **Then** fix NATS (most services need it)
3. **Then** re-enable services one at a time
4. **Test each step** before moving to next

---

## Success Metrics

**System Operational When**:
- ✅ All 16 major components supervised
- ✅ 6+ agents actively running
- ✅ Oban workers executing on schedule
- ✅ NATS messaging working
- ✅ Self-evolution loop operational (metrics → feedback → evolution)
- ✅ Documentation accurate (matches reality)

**Current**: 5/16 components = 31%
**Target**: 16/16 components = 100%

---

## Timeline Summary

| Phase | Duration | Key Deliverable |
|-------|----------|-----------------|
| **Phase 1: Oban** | Week 1 | Background workers running |
| **Phase 2: NATS** | Week 2 | Messaging operational |
| **Phase 3: Services** | Week 3 | LLM, Knowledge, Learning working |
| **Phase 4: Agents** | Week 4 | **AGENTS RUNNING** 🎉 |
| **Phase 5: Docs** | Week 5 | Documentation matches reality |

**Fast Track**: Weeks 1-2 + Agent re-enable = **2 weeks to agents running**
**Full System**: All 5 phases = **5 weeks to complete recovery**

---

## Quick Start (Minimum Viable)

**Just want agents running?**

1. Fix Oban config (2 hours)
2. Re-enable Oban in application.ex (5 min)
3. Fix NATS tests (4 hours)
4. Re-enable NATS.Supervisor (5 min)
5. Re-enable Agents.Supervisor (5 min)
6. Test: `Singularity.Agent.start_link(id: "test")`

**Total**: ~1-2 days for minimum viable agent system

---

## Notes

- **Don't skip Oban**: Everything depends on it
- **Don't skip NATS**: Agents need it for LLM calls
- **Test each phase**: Don't uncomment everything at once
- **Read logs**: They'll tell you what's broken
- **Ask for help**: This is complex, questions are expected

**For Questions**: See comprehensive analysis in `/AGENT_SYSTEM_REALITY_CHECK.md`
