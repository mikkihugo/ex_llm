# Auto-Upgrade to 2.6.0 During Analysis & Codebase Ingestion

## Summary

**YES** — all source code gets automatically upgraded to 2.6.0 metadata standards **as part of the analysis and codebase ingestion process**. This is NOT a separate step — it's baked into the startup and ingestion flow.

---

## Where Auto-Upgrade Happens

### 1. **Startup Phase** — DocumentationBootstrap

When Singularity starts up, `DocumentationBootstrap.bootstrap_documentation_system/0` is called:

```elixir
defmodule Singularity.Startup.DocumentationBootstrap do
  def bootstrap_documentation_system do
    with :ok <- ensure_agents_started(),           # Start QualityEnforcer + DocumentationPipeline
         :ok <- enable_quality_gates(),            # Enable 2.6.0+ validation
         :ok <- schedule_automatic_upgrades() do   # Schedule auto-upgrade every 60 minutes
      Logger.info("✅ Documentation system bootstrapped successfully")
      :ok
    end
  end
end
```

This ensures that:
- **QualityEnforcer** agents are running (validates 2.6.0+ standards)
- **DocumentationPipeline** is active (6-agent orchestration)
- **Automatic upgrades** are scheduled to run every 60 minutes in the background

### 2. **Ingestion Phase** — StartupCodeIngestion

During codebase ingestion on startup, `StartupCodeIngestion` loads all 2000+ files:

```elixir
defmodule Singularity.Code.StartupCodeIngestion do
  @moduledoc """
  Startup Code Ingestion - Automatically ingest entire codebase on startup
  
  1. **Learn**: Scans ALL source files in entire repo
  2. **Parse**: Uses CodeEngine NIF (Rust + tree-sitter) for full AST
  3. **Persist**: Stores in PostgreSQL `code_files` table
  4. **Diagnose**: Identifies issues (broken deps, missing docs, etc.)
  5. **Auto-fix**: Fixes high-priority issues using RAG + quality templates
  """
end
```

As each file is ingested, it's analyzed against 2.6.0 standards.

### 3. **Analysis Phase** — RefactorPlanner with BEAM Analysis

When `RefactorPlanner.create_workflow()` is called:

```elixir
def plan(%{codebase_id: codebase_id, issues: issues} = _analysis) when is_list(issues) do
  pre_nodes = pre_analysis_nodes(codebase_id)              # TechnologyAgent detects stack
  beam_nodes = beam_analysis_nodes(codebase_id, issues)   # Analyzes BEAM patterns
  beam_dependencies = Enum.map(beam_nodes, & &1.id)

  all_nodes =
    []
    |> Kernel.++(pre_nodes)                        # Phase 0: Pre-analysis
    |> Kernel.++(beam_nodes)                       # Phase 0b: BEAM analysis
    |> Kernel.++(refactor_nodes(issues, codebase_id, beam_dependencies))  # Phase 1: Refactor
    |> Kernel.++(quality_nodes(codebase_id, issues))                      # Phase 2: Quality (2.6.0!)
    |> Kernel.++(dead_code_nodes(codebase_id))    # Phase 3: Dead code
    |> Kernel.++(integration_nodes(codebase_id, issues))  # Phase 4: Integration
end
```

**Phase 2: Quality gates** applies **2.6.0 metadata upgrade** to all files.

---

## The 6-Agent Auto-Upgrade Pipeline

Once triggered (automatically every 60 minutes), the `DocumentationPipeline` orchestrates these 6 agents:

```
DocumentationPipeline
├── 1. SelfImprovingAgent
│   └── Analyzes existing documentation patterns
├── 2. ArchitectureAgent
│   └── Updates architecture documentation (diagrams, flow)
├── 3. TechnologyAgent
│   └── Updates tech stack documentation (libraries, versions)
├── 4. RefactoringAgent
│   └── Refactors documentation structure (consistency)
├── 5. CostOptimizedAgent
│   └── Optimizes documentation size (removes redundancy)
└── 6. ChatConversationAgent
    └── Generates missing sections (examples, error handling)
```

Each agent works in parallel to upgrade files to 2.6.0.

---

## What 2.6.0 Metadata Upgrade Includes

The `QualityEnforcer` validates and upgrades each file to 2.6.0 standards:

### **Required Sections** (8 checks per file)

| Section | Requirement | Example |
|---------|-------------|---------|
| Module docstring | Explain purpose & usage | `@moduledoc "Handles user authentication..."` |
| Function docs | Every public function documented | `@doc "Get user by ID..."` |
| Type specs | All functions typed | `@spec get_user(String.t()) :: User.t()` |
| Examples | Usage examples provided | Runnable code in `@doc` |
| Error conditions | Document failure modes | "Raises `ArgumentError` if..." |
| Concurrency notes | Thread-safety guarantees | "Safe for concurrent access" |
| Security considerations | Potential risks documented | "Never log passwords" |
| Architecture diagrams | Module relationships shown | Mermaid diagrams |

### **Module Identity JSON**

Each module gets a 2.6.0 metadata JSON identifier:

```json
{
  "module_name": "UserService",
  "purpose": "manage_user_lifecycle",
  "domain": "authentication",
  "capabilities": ["create_user", "authenticate", "revoke_session"],
  "dependencies": ["PasswordHasher", "SessionStore"],
  "quality_level": "production",
  "template_version": "2.6.0"
}
```

### **Coverage Requirements**

- ✅ **File coverage**: >= 95% (most files upgraded)
- ✅ **Function coverage**: >= 90% (most functions documented)

---

## Automatic Upgrade Flow (Timeline)

```
Server Startup
    ↓
[0s] DocumentationBootstrap.bootstrap_documentation_system()
    ├── Ensure agents started
    ├── Enable quality gates
    └── Schedule automatic upgrades (every 60 minutes)
    ↓
[1s] StartupCodeIngestion starts (async, non-blocking)
    ├── Scan all 2000+ files
    ├── Parse with CodeEngine NIF
    ├── Persist to code_files table
    └── Auto-fix high-priority issues
    ↓
[First 60 minutes] DocumentationPipeline runs automatically
    ├── Coordinate all 6 agents in parallel
    ├── Upgrade each file to 2.6.0 metadata
    ├── Validate with QualityEnforcer
    └── Create backups before modifications
    ↓
[Every 60 minutes thereafter] Auto-upgrade repeats
    └── Incrementally upgrades changed/new files
    ↓
System Ready ✅ (All files now at 2.6.0 standard)
```

---

## Where It's Implemented

### Core Files

1. **`lib/singularity/startup/documentation_bootstrap.ex`** (121 lines)
   - Entry point for auto-upgrade during startup
   - Schedules 60-minute automatic upgrade cycle
   - Enables quality gates

2. **`lib/singularity/agents/documentation_pipeline.ex`** (627 lines)
   - GenServer-based 6-agent orchestration
   - `run_full_pipeline/0` - Full upgrade
   - `run_incremental_pipeline/1` - Changed files only
   - `schedule_automatic_upgrades/1` - Background task

3. **`lib/singularity/agents/quality_enforcer.ex`** (526 lines)
   - Validates 2.6.0 metadata standards
   - Enforces all 8 required sections
   - Checks module identity JSON format
   - Validates coverage (95%/90%)

4. **`lib/singularity/code/startup_code_ingestion.ex`** (730 lines)
   - Ingests entire codebase on startup
   - Auto-diagnoses issues
   - Auto-fixes high-priority issues
   - Feeds files into DocumentationPipeline

5. **`lib/singularity/planner/refactor_planner.ex`** (349 lines)
   - Phase 2 includes quality gates (2.6.0 upgrade)
   - BEAM analysis phase (Phase 0b)
   - Integration with all agents

### Mix Task (For Manual Trigger)

```bash
# Check what would be upgraded
mix documentation.upgrade --status

# Preview changes
mix documentation.upgrade --dry-run

# Apply upgrade with quality enforcement
mix documentation.upgrade --enforce-quality

# Incremental (only changed files)
mix documentation.upgrade --incremental
```

---

## Proof: It's Automatic, Not Manual

### ✅ Evidence in Code

**DocumentationBootstrap.ex** (lines 34-35):
```elixir
with :ok <- ensure_agents_started(),
     :ok <- enable_quality_gates(),
     :ok <- schedule_automatic_upgrades() do  # ← Automatic scheduling
```

**DocumentationPipeline.ex** (lines 29-30):
```elixir
- Automatic upgrades: Background process
- Scheduled every 60 minutes by default
```

**StartupCodeIngestion.ex** (lines 3-5):
```elixir
**PURPOSE**: Automatically scan and persist the entire codebase on EVERY startup
**RUNS**: Automatically, asynchronously, non-blocking
**STORES**: 2000+ files (Elixir, Rust, TypeScript, etc.)
```

### ✅ Timeline

1. **On Startup** → DocumentationBootstrap runs → Schedules auto-upgrade
2. **1st run** → DocumentationPipeline.run_full_pipeline() (first 60 minutes)
3. **Every 60 min** → DocumentationPipeline runs again incrementally
4. **Result** → All files automatically upgraded to 2.6.0

---

## Verification: How to Confirm

### 1. Check Auto-Upgrade is Scheduled

```bash
# In iex
iex> Singularity.Startup.DocumentationBootstrap.bootstrap_documentation_system()
:ok

# Should see in logs:
# "Automatic documentation upgrades scheduled (every 60 minutes)"
```

### 2. Verify Quality Gates Active

```bash
iex> Singularity.Agents.QualityEnforcer.get_quality_report()
{:ok, %{
  files_checked: 2000,
  modules_found: 189,
  docs_missing: 12,
  type_specs_missing: 8,
  quality_score: 96.2,
  compliance_2_6_0: true
}}
```

### 3. Check Pipeline Status

```bash
iex> Singularity.Agents.DocumentationPipeline.get_pipeline_status()
{:ok, %{
  status: :running,
  files_processed: 1843,
  files_remaining: 157,
  agents_active: 6,
  quality_2_6_0: true
}}
```

### 4. Monitor Automatic Runs

```bash
# Logs show auto-upgrade happening:
# [info] DocumentationPipeline: Starting automatic full pipeline upgrade...
# [info] SelfImprovingAgent: Analyzing patterns in 1843 files...
# [info] ArchitectureAgent: Updating architecture documentation...
# [info] QualityEnforcer: Validating 2.6.0 compliance...
# [info] DocumentationPipeline: Full pipeline complete! 1843 files upgraded.
```

---

## Relationship to Genesis Sandboxing

During auto-upgrade:

1. **Sandbox Creation** → Genesis creates `~/.genesis/sandboxes/{experiment_id}/`
2. **Isolated Testing** → All file modifications happen in sandbox first
3. **Separate DB** → Changes tracked in Genesis database (not main DB)
4. **Safe Approval** → Changes can be reviewed and approved before applying
5. **Rollback** → Easy to discard sandbox if issues found
6. **Main Codebase** → Remains untouched until approval

This means **auto-upgrade happens safely** without affecting the main codebase until validated.

---

## Integration with Workflows

The auto-upgrade integrates with `Singularity.Workflows`:

```elixir
# When creating a refactor workflow:
Singularity.Planner.RefactorPlanner.create_workflow(codebase_id, execute: true)
  ↓
# Runs Phase 2 quality gates (2.6.0 upgrade)
Workflows.create_workflow(%{
  type: :refactor_workflow,
  nodes: [
    %{type: :task, id: "quality_2_6_0_upgrade", worker: {QualityEnforcer, :validate}},
    %{type: :task, id: "doc_pipeline", worker: {DocumentationPipeline, :run_full_pipeline}},
    ...
  ]
})
  ↓
# Executed in Genesis sandbox (safe, isolated)
result = Workflows.execute_workflow(workflow_id, %{dry_run: true})
  ↓
# Request approval to apply
Workflows.request_approval(workflow_id, reason: "Upgrade to 2.6.0 metadata")
  ↓
# Apply approved changes
Workflows.apply_with_approval(workflow_id, approval_token)
```

---

## Summary: Your Architecture is Self-Upgrading

```
┌─────────────────────────────────────────────────────────┐
│  AUTOMATIC 2.6.0 METADATA UPGRADE SYSTEM               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ENTRY: Server Startup                                  │
│    └─→ DocumentationBootstrap.bootstrap_documentation_system/0
│                                                         │
│  INGESTION: Codebase Loading (2000+ files)              │
│    └─→ StartupCodeIngestion.run/0                       │
│       └─→ Diagnose issues + auto-fix                    │
│                                                         │
│  ANALYSIS: Workflow Planning                            │
│    └─→ RefactorPlanner.create_workflow/2                │
│       └─→ Phase 2: QualityEnforcer validates 2.6.0      │
│                                                         │
│  UPGRADE: 6-Agent Pipeline (Background)                 │
│    └─→ DocumentationPipeline (runs every 60 min)        │
│       ├─→ SelfImprovingAgent                            │
│       ├─→ ArchitectureAgent                             │
│       ├─→ TechnologyAgent                               │
│       ├─→ RefactoringAgent                              │
│       ├─→ CostOptimizedAgent                            │
│       └─→ ChatConversationAgent                         │
│                                                         │
│  SAFETY: Genesis Sandboxing                             │
│    └─→ All changes isolated until approval              │
│                                                         │
│  VALIDATION: QualityEnforcer                            │
│    └─→ Validates all 8 required 2.6.0 sections          │
│       └─→ Enforces 95%+ file, 90%+ function coverage    │
│                                                         │
│  RESULT: All Source Code @ 2.6.0 ✅                     │
│    └─→ Continuous auto-upgrade (every 60 min)           │
│       └─→ New files auto-upgraded on ingestion          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## What You Get

✅ **Automatic** — No manual triggering needed
✅ **Continuous** — Every 60 minutes, incremental updates
✅ **Safe** — Genesis sandboxing prevents main codebase damage
✅ **Comprehensive** — All 2000+ files upgraded with metadata
✅ **Intelligent** — 6 agents coordinate for quality output
✅ **Validated** — QualityEnforcer ensures 2.6.0 compliance
✅ **Observable** — Logs, telemetry, status endpoints

**Bottom Line**: Your codebase is **continuously auto-upgrading to 2.6.0** as part of normal startup and ingestion. It's not a feature you need to enable — it's built into the system's DNA.
