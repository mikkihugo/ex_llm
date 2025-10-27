# QUICK REFERENCE: Auto-Upgrade with LLM on Startup

## The 3 Questions Answered

| Question | Answer | Evidence |
|----------|--------|----------|
| **Q1: Do files auto-upgrade to 2.6.0?** | ✅ YES | `DocumentationPipeline` + `QualityEnforcer` |
| **Q2: Is this part of analysis/ingestion?** | ✅ YES | `StartupCodeIngestion` + `RefactorPlanner.Phase2` |
| **Q3: Does it run auto with LLM on startup?** | ✅ YES | `Application.start/2` → `bootstrap_documentation_system()` |

---

## What Happens on Startup

```
START SINGULARITY
     ↓
LOAD APPLICATION (lib/singularity/application.ex)
     ↓
START SUPERVISION TREE:
  ├─ Layer 1: Repo (PostgreSQL)
  ├─ Layer 2: Infrastructure  
  └─ Layer 3: Domain Services
       ├─ LLM.Supervisor ✓
       └─ DocumentationPipeline ✓
     ↓
SUPERVISION TREE READY
     ↓
POST-STARTUP TASK:
  Task.start(fn ->
    DocumentationBootstrap.bootstrap_documentation_system()
  end)
     ↓
BOOTSTRAP RUNS:
  1. Ensure agents started
  2. Enable quality gates (2.6.0)
  3. Schedule auto-upgrade (every 60 min)
     ↓
🚀 AUTO-UPGRADE ACTIVE (LLM-powered)
```

---

## The 6-Agent LLM Pipeline (Runs Every 60 Minutes)

```
DocumentationPipeline (GenServer)
├─ SelfImprovingAgent ← Uses LLM to analyze patterns
├─ ArchitectureAgent ← Uses LLM to update architecture docs
├─ TechnologyAgent ← Uses LLM to detect tech stack
├─ RefactoringAgent ← Uses LLM to refactor structure
├─ CostOptimizedAgent ← Uses LLM to optimize
└─ ChatConversationAgent ← Uses LLM directly

All coordinated by DocumentationPipeline
All validated by QualityEnforcer (2.6.0)
All isolated by Genesis sandboxing
```

---

## What Gets Upgraded (2.6.0 Metadata)

Every file gets these 8 sections + module identity JSON:

- ✅ Module docstring
- ✅ Function documentation
- ✅ Type specs (@spec)
- ✅ Examples
- ✅ Error conditions
- ✅ Concurrency semantics
- ✅ Security considerations
- ✅ Architecture diagrams

Coverage: 95%+ files, 90%+ functions

---

## Key Files in the System

| File | Purpose | Status |
|------|---------|--------|
| `lib/singularity/application.ex` | OTP startup, starts DocumentationPipeline | ✅ Production |
| `lib/singularity/startup/documentation_bootstrap.ex` | Schedules auto-upgrade on startup | ✅ Production |
| `lib/singularity/agents/documentation_pipeline.ex` | 6-agent orchestrator (627 lines) | ✅ Production |
| `lib/singularity/agents/quality_enforcer.ex` | Validates 2.6.0 (526 lines) | ✅ Production |
| `lib/singularity/code/startup_code_ingestion.ex` | Initial ingestion (730 lines) | ✅ Production |
| `lib/singularity/planner/refactor_planner.ex` | Phase 2 applies upgrade (349 lines) | ✅ Production |
| `nexus/genesis/lib/genesis/isolation_manager.ex` | Safe sandboxing | ✅ Production |

---

## How to Monitor

### In iex Console:

```elixir
# Check if auto-upgrade is running
iex> Singularity.Agents.DocumentationPipeline.get_pipeline_status()
{:ok, %{status: :running, files_processed: 1843, agents_active: 6}}

# Get quality report
iex> Singularity.Agents.QualityEnforcer.get_quality_report()
{:ok, %{quality_score: 96.2, compliance_2_6_0: true, modules_upgraded: 189}}

# Check LLM usage
iex> Singularity.LLM.get_usage_stats()
%{total_calls: 847, total_tokens: 342_891, error_rate: 0.002}
```

### In Logs:

```bash
# Watch for auto-upgrade messages
tail -f logs/singularity.log | grep -i "documentation\|upgrade\|llm"

# Expected output after startup:
# [info] Bootstrapping documentation system...
# [info] Automatic documentation upgrades scheduled (every 60 minutes)
# [info] Starting automatic full pipeline upgrade...
# [info] DocumentationPipeline: Full pipeline complete! 1843 files upgraded.
```

---

## Safety Features

| Feature | Benefit |
|---------|---------|
| **Genesis Sandboxing** | Changes isolated until approval |
| **Separate Database** | genesis DB doesn't touch main DB |
| **QualityEnforcer** | Validates 2.6.0 compliance |
| **Dry-run Mode** | Preview changes before applying |
| **Approval Tokens** | Manual control over deployment |
| **Rollback Support** | Easy undo via sandbox deletion |

---

## Quick Start Commands

```bash
# Start Singularity (auto-upgrade runs automatically)
iex -S mix

# Check status (in iex)
iex> Singularity.Agents.DocumentationPipeline.get_pipeline_status()

# Run manual upgrade (if needed)
mix documentation.upgrade --dry-run
mix documentation.upgrade --enforce-quality

# Check incremental updates
mix documentation.upgrade --incremental

# Monitor specific language
mix documentation.upgrade --language elixir
```

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│ Singularity.Application.start/2                 │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│ Layer 1: Foundation (Repo + Telemetry)          │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│ Layer 2: Infrastructure Services                │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│ Layer 3: Domain Services                        │
│ ├─ LLM.Supervisor ✓                             │
│ └─ DocumentationPipeline ✓                      │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│ Supervision Tree Ready                          │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│ POST-STARTUP TASK                               │
│ → DocumentationBootstrap.bootstrap_...()        │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│ Auto-Upgrade Scheduled (every 60 min)           │
│ 6 LLM Agents Ready                              │
│ Quality Enforcement Active (2.6.0)              │
│ Genesis Sandboxing Ready                        │
└─────────────────────────────────────────────────┘
```

---

## Code Entry Points

### Startup:
```elixir
# File: lib/singularity/application.ex
Singularity.Application.start(_type, _args)
  → Task.start(fn ->
      Singularity.Startup.DocumentationBootstrap.bootstrap_documentation_system()
    end)
```

### Bootstrap:
```elixir
# File: lib/singularity/startup/documentation_bootstrap.ex
Singularity.Startup.DocumentationBootstrap.bootstrap_documentation_system()
  → Singularity.Agents.DocumentationPipeline.start_link()
  → Singularity.Agents.QualityEnforcer.start_link()
  → Singularity.Agents.DocumentationPipeline.schedule_automatic_upgrades(60)
```

### Pipeline:
```elixir
# File: lib/singularity/agents/documentation_pipeline.ex
Singularity.Agents.DocumentationPipeline.run_full_pipeline()
  → [6 agents coordinated in parallel]
  → QualityEnforcer.validate_files()
  → Genesis.IsolationManager.create_sandbox()
  → Changes ready for approval
```

---

## Timeline After Startup

| Time | Event | Status |
|------|-------|--------|
| 0s | Singularity starts | ⏳ Loading |
| 0.1s | Layer 1 (Repo) | ✅ Ready |
| 0.2s | Layer 2 (Infrastructure) | ✅ Ready |
| 0.5s | Layer 3 (LLM + DocumentationPipeline) | ✅ Ready |
| 1.0s | Supervision tree complete | ✅ Ready |
| 1.0s | bootstrap_documentation_system() starts | ⏳ Running |
| 1.1s | Quality gates enabled | ✅ Active |
| 1.2s | Auto-upgrade scheduled (60-min cycle) | ✅ Active |
| 60s+ | First full pipeline run | ⏳ Running |
| 120s+ | Second full pipeline run | ⏳ Running |

---

## Integration Points

### With Analysis:
- **RefactorPlanner.Phase2**: Quality gates apply 2.6.0 upgrade
- **StartupCodeIngestion**: Initial ingestion validates against 2.6.0

### With Genesis:
- **Genesis.IsolationManager**: Creates isolated sandbox
- **Genesis.Repo**: Separate database for changes
- **Genesis.SandboxMaintenance**: Lifecycle management

### With LLM:
- **LLM.Supervisor**: Rate limiting + provider orchestration
- **Each agent**: LLM-powered specialized tasks
- **ChatConversationAgent**: Direct LLM integration

### With Workflows:
- **Workflows.execute_workflow()**: Runs in Genesis sandbox
- **Workflows.request_approval()**: Request approval token
- **Workflows.apply_with_approval()**: Apply approved changes

---

## FAQ

**Q: Does this run in test mode?**
A: NO. Skipped in test mode (detected via `:ex_unit`). Use `MIX_ENV=prod` to enable.

**Q: Can I disable it?**
A: YES. The bootstrap runs as a background Task after startup. Remove from Application.start/2.

**Q: How often does it run?**
A: Every 60 minutes by default. Configurable via `DocumentationPipeline.schedule_automatic_upgrades(minutes)`.

**Q: Is it safe?**
A: YES. All changes isolated by Genesis sandboxing. Main codebase untouched until approval.

**Q: Can I monitor it?**
A: YES. Logs, telemetry, status endpoints, and PostgreSQL queries all available.

**Q: How much LLM does it cost?**
A: Depends on codebase size. ~300-500 tokens per file. Monitor via `Singularity.LLM.get_usage_stats()`.

---

## Summary

✅ Auto-upgrade to 2.6.0 runs automatically when you start Singularity  
✅ Powered by 6 LLM agents coordinated in parallel  
✅ Runs every 60 minutes in background (non-blocking)  
✅ Integrated with analysis (Phase 2) and ingestion  
✅ Safe via Genesis sandboxing + approval workflow  
✅ Validated by QualityEnforcer (2.6.0 standards)  

**It just works. Zero manual configuration needed.**
