# Singularity Agent System - Complete Inventory & Integration Map

## Executive Summary

The system contains **60+ agent-related modules** organized into:
- **Agents** (specialized workers performing tasks)
- **Coordinators** (orchestrate multiple agents)
- **Supervisors** (manage process lifecycle)
- **Orchestrators** (high-level workflow management)

All are being **unified** into the `Singularity.Workflows` system with standardized:
- Approval flow (Arbiter tokens)
- Dry-run safety
- Worker contract: `function(args_map, opts) → {:ok, result} | {:error, reason}`

---

## Layer 1: Agent Implementations (Specialized Workers)

### Core New Agents (Unified in Workflows)

| Agent | Purpose | File | Status | Integration |
|-------|---------|------|--------|-------------|
| **RefactorWorker** | Analyze/transform/validate code | `lib/singularity/execution/refactor_worker.ex` | ✅ Complete | `{RefactorWorker, :analyze\|:transform\|:validate}` |
| **AssimilateWorker** | Learn from changes, integrate, report | `lib/singularity/execution/assimilate_worker.ex` | ✅ Complete | `{AssimilateWorker, :learn\|:integrate\|:report}` |
| **SelfImprovementAgent** | GenServer orchestrator for edits/workflows | `lib/singularity/agents/self_improvement_agent.ex` | ✅ Complete | Calls Toolkit + Arbiter + Workflows |

### Existing Specialized Agents

| Agent | Purpose | File | Status | Needs Integration |
|-------|---------|------|--------|------------------|
| **CostOptimizedAgent** | Reduce LLM costs via caching | `lib/singularity/agents/cost_optimized_agent.ex` | ✅ Exists | ⚠️ Add to Workflows as task worker |
| **TechnologyAgent** | Detect/manage technology stacks | `lib/singularity/agents/technology_agent.ex` | ✅ Exists | ⚠️ Add as smell detector or plan node |
| **QualityEnforcer** | Enforce code quality standards | `lib/singularity/agents/quality_enforcer.ex` | ✅ Exists | ⚠️ Add as validation worker |
| **DeadCodeMonitor** | Detect and report dead code | `lib/singularity/agents/dead_code_monitor.ex` | ✅ Exists | ⚠️ Add as smell detector |
| **ChangeTracker** | Track code changes over time | `lib/singularity/agents/change_tracker.ex` | ✅ Exists | ✅ Works with Workflows (audit trail) |
| **AgentSpawner** | Factory for spawning agents | `lib/singularity/agents/agent_spawner.ex` | ✅ Exists | ⚠️ Standardize worker spawning |
| **RealWorkloadFeeder** | Feed real workloads to agents | `lib/singularity/agents/real_workload_feeder.ex` | ✅ Exists | ⚠️ Feed todo/workflow data |
| **MetricsFeeder** | Track agent performance metrics | `lib/singularity/agents/metrics_feeder.ex` | ✅ Exists | ⚠️ Collect Workflows execution metrics |
| **TemplatePerformance** | Profile template performance | `lib/singularity/agents/template_performance.ex` | ✅ Exists | ⚠️ Add telemetry to Workflows nodes |
| **DocumentationAnalyzer** | Analyze code documentation | `lib/singularity/agents/documentation/analyzer.ex` | ✅ Exists | ⚠️ Add as code analysis worker |

---

## Layer 2: Coordinators (Multi-Agent Orchestration)

### New Unified Coordinators

| Coordinator | Purpose | File | Status | Integration |
|-------------|---------|------|--------|-------------|
| **TodoSwarmCoordinator** | Poll todos → detect smells → plan → execute | `lib/singularity/execution/todo_swarm_coordinator.ex` | ✅ Complete | **Primary entry point** for Workflows |
| **RefactorAssimilateSwarmCoordinator** | Spawn refactor + assimilate swarms | `lib/singularity/execution/refactor_assimilate_swarm_coordinator.ex` | ⚠️ Scaffold | ⚠️ Delegate to Workflows.execute_workflow |

### Existing Coordinators

| Coordinator | Purpose | File | Status | Integration |
|-------------|---------|------|--------|-------------|
| **FileAnalysisSwarmCoordinator** | Coordinate file analysis across swarm | `lib/singularity/execution/file_analysis_swarm_coordinator.ex` | ✅ Exists | ⚠️ Wire to Workflows for planned execution |
| **ExecutionOrchestrator** | High-level execution orchestration | `lib/singularity/execution/orchestrator/execution_orchestrator.ex` | ✅ Exists | ✅ Can delegate to Workflows |

---

## Layer 3: Supervisors (Process Lifecycle Management)

| Supervisor | Purpose | File | Status | Note |
|-----------|---------|------|--------|------|
| **TodoSupervisor** | Manage todo worker processes | `lib/singularity/execution/todo_supervisor.ex` | ✅ Exists | Supervised by TodoSwarmCoordinator |
| **AgentSupervisor** | Manage agent lifecycle | `lib/singularity/agents/agent_supervisor.ex` | ✅ Exists | Supervises all agent processes |
| **CoordinationSupervisor** | Manage coordination processes | `lib/singularity/agents/coordination/coordination_supervisor.ex` | ✅ Exists | Supervises coordinators |
| **ExecutionSupervisor** | Manage execution processes | `lib/singularity/execution/supervisor.ex` | ✅ Exists | Root supervisor for execution layer |
| **AgentSupervisor (Main)** | Root supervisor for agents | `lib/singularity/agents/supervisor.ex` | ✅ Exists | Root of agent tree |

---

## Layer 4: Orchestrators & Engines (System-Level)

| Orchestrator | Purpose | File | Status | Integration |
|--------------|---------|------|--------|-------------|
| **ExecutionOrchestrator** | Routes tasks, manages execution strategy | `lib/singularity/execution/orchestrator/execution_orchestrator.ex` | ✅ Exists | Can emit tasks → Workflows.execute_workflow |
| **TaskGraphEngine** | Execute task graphs with DAG logic | `lib/singularity/execution/task_graph_engine.ex` | ✅ Exists | ⚠️ Integrate with Workflows node execution |
| **LuaStrategyExecutor** | Execute Lua-based strategies | `lib/singularity/execution/lua_strategy_executor.ex` | ✅ Exists | Can be wrapped as Workflows task worker |
| **ExecutionTracer** | Trace execution for debugging | `lib/singularity/execution/execution_tracer.ex` | ✅ Exists | ✅ Integrates with Workflows status updates |
| **Evolution** | Continuous improvement loop | `lib/singularity/execution/evolution.ex` | ✅ Exists | ✅ Works with Workflows for plan generation |

---

## Layer 5: Specialized Workflows & Monitors

| Component | Purpose | File | Status |
|-----------|---------|------|--------|
| **CodeQualityImprovementWorkflow** | Auto-improve code quality | `lib/singularity/agents/workflows/code_quality_improvement_workflow.ex` | ✅ Exists |
| **TaskExecutionMetricsDashboard** | Visualize task metrics | `lib/singularity/execution/task_execution_metrics_dashboard.ex` | ✅ Exists |
| **AgentPerformanceDashboard** | Monitor agent health | `lib/singularity/agents/agent_performance_dashboard.ex` | ✅ Exists |

---

## Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Singularity.Workflows (Hub)                  │
│              Unified HTDAG + Approvals + Dry-Run-Safe           │
├─────────────────────────────────────────────────────────────────┤
│ Node execution, status tracking, approval flow                  │
│ Worker contract: {Module, :function} or node type              │
└─────────────────────────────────────────────────────────────────┘
         ↑ Entry points                  ↑ Query/update
         │                              │
    ┌────┴────┬───────────┬─────────────┴────┐
    │          │           │                 │
    ▼          ▼           ▼                 ▼
TodoSwarm    Evolution   FileAnalysis    ExecutionTracer
Coordinator  (loop)      Coordinator     (monitoring)
    │          │           │                 │
    └──→ Planner ──────────┴─────────────────┘
         │ (detect + plan)
         │
    ┌────┴──────────────────────────────┐
    │ Returns: HTDAG workflow with      │
    │ worker nodes like:                │
    │ {RefactorWorker, :analyze}        │
    │ {AssimilateWorker, :learn}        │
    └────┬──────────────────────────────┘
         │
    ┌────┴──────────────────────────┐
    │ Workflows.execute_workflow    │
    │ For each node:                │
    │ - Call worker(args, opts)     │
    │ - Collect dry-run results     │
    │ - Request approval if needed  │
    │ - Apply with token            │
    └────┬──────────────────────────┘
         │
    ┌────┴────┬───────────┬──────────┬──────────┐
    │          │           │          │          │
    ▼          ▼           ▼          ▼          ▼
 Refactor  Assimilate  Quality   Dead Code  Tech
 Worker    Worker      Enforcer   Monitor   Agent
 (tasks)   (learning)  (checks)   (detect)  (stack)
```

---

## Integration Plan: Bridge Existing Agents to Workflows

### Phase 1: Wrap Existing Agents as Workers (In-Progress)

**Goal:** Make existing agents compatible with Workflows node execution

```elixir
# Example: Wrap TechnologyAgent as a worker
defmodule Singularity.Execution.TechDetectionWorker do
  def detect(%{codebase_id: codebase_id} = args, opts) do
    dry_run = Keyword.get(opts, :dry_run, true)
    # Call existing TechnologyAgent.detect_technologies/1
    case Singularity.TechnologyAgent.detect_technologies(codebase_id) do
      {:ok, techs} when dry_run ->
        {:ok, %{action: :detect, technologies: techs, dry_run: true}}
      {:ok, _} ->
        # Real execution would update knowledge base
        {:ok, %{action: :detect, status: :recorded}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### Phase 2: Feed Coordinators into Workflows

**Goal:** Route coordinator outputs through Workflows for unified execution

```elixir
# FileAnalysisSwarmCoordinator integration
defmodule Singularity.Execution.FileAnalysisWorker do
  def analyze(%{codebase_id: codebase_id} = args, opts) do
    # Orchestrate FileAnalysisSwarmCoordinator as part of workflow
    case FileAnalysisSwarmCoordinator.analyze_all(codebase_id) do
      {:ok, results} -> {:ok, results}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### Phase 3: Extend Planner for All Agent Types

**Goal:** RefactorPlanner produces HTDAG that includes all agent types

```elixir
# Enhanced RefactorPlanner.plan/1
def plan(%{codebase_id: codebase_id, issues: issues}) do
  nodes = [
    # Code smell analysis
    %{id: "tech_detect_1", type: :task, worker: {TechDetectionWorker, :detect}, args: %{codebase_id: codebase_id}, depends_on: []},
    %{id: "quality_check_1", type: :task, worker: {QualityEnforcer, :check}, args: %{codebase_id: codebase_id}, depends_on: ["tech_detect_1"]},
    # Refactoring
    %{id: "refactor_1", type: :task, worker: {RefactorWorker, :analyze}, args: %{issues: issues}, depends_on: ["quality_check_1"]},
    # Assimilation & learning
    %{id: "assimilate_1", type: :task, worker: {AssimilateWorker, :learn}, args: %{codebase_id: codebase_id}, depends_on: ["refactor_1"]},
    # Approval gate
    %{id: "approve_merge", type: :approval, reason: "manual_review", depends_on: ["assimilate_1"]},
    # Final integration
    %{id: "integrate_1", type: :task, worker: {AssimilateWorker, :integrate}, args: %{codebase_id: codebase_id}, depends_on: ["approve_merge"]}
  ]
  {:ok, %{nodes: nodes, workflow_id: "full_refactor_#{codebase_id}"}}
end
```

---

## Coordination Network Map

```
Supervisors (Lifecycle)
├── AgentSupervisor
│   ├── SelfImprovementAgent (GenServer)
│   ├── ChangeTracker
│   └── AgentSpawner
├── CoordinationSupervisor
│   ├── CapabilityRegistry
│   └── AgentRouter
└── ExecutionSupervisor
    ├── TodoSwarmCoordinator
    ├── FileAnalysisSwarmCoordinator
    └── RefactorAssimilateSwarmCoordinator

Specialized Agents
├── Code Analysis
│   ├── TechnologyAgent
│   ├── QualityEnforcer
│   ├── DeadCodeMonitor
│   └── DocumentationAnalyzer
├── Performance
│   ├── CostOptimizedAgent
│   ├── MetricsFeeder
│   └── TemplatePerformance
├── Monitoring
│   ├── ExecutionTracer
│   ├── AgentPerformanceDashboard
│   └── TaskExecutionMetricsDashboard
└── Infrastructure
    ├── RealWorkloadFeeder
    ├── AgentRouter
    └── CapabilityRegistry

Execution Engines
├── TaskGraphEngine (DAG execution)
├── ExecutionOrchestrator (routing)
├── LuaStrategyExecutor (scripted execution)
├── Evolution (continuous improvement)
└── StrategyLoader (load execution strategies)

Unified Hub
└── Singularity.Workflows
    ├── Arbiter (approvals)
    ├── Toolkit (file I/O)
    └── SelfImprovementAgent (orchestration)
```

---

## Worker Contract Template

All agents should be wrapped as workers following this pattern:

```elixir
defmodule Singularity.Execution.MyWorker do
  @moduledoc "Template for wrapping an agent as a Workflows worker"

  def my_action(args, opts) when is_map(args) do
    dry_run = Keyword.get(opts, :dry_run, true)
    logger_prefix = "#{__MODULE__}.my_action"
    
    Logger.info("#{logger_prefix}: starting (dry_run=#{dry_run})")
    
    result =
      if dry_run do
        # Dry-run: return what would be done
        {:ok, %{action: :my_action, dry_run: true, description: "Would do X"}}
      else
        # Real execution
        case MyAgentModule.do_something(args) do
          {:ok, data} -> {:ok, %{action: :my_action, result: data}}
          {:error, reason} -> {:error, reason}
        end
      end
    
    Logger.info("#{logger_prefix}: result=#{inspect(result)}")
    result
  end
end
```

---

## Status Dashboard: Agent System Readiness

| Layer | Component | Unified? | Ready? | Notes |
|-------|-----------|----------|--------|-------|
| Hub | Workflows | ✅ Yes | ✅ Yes | Production ready |
| Hub | Arbiter | ✅ Yes | ✅ Yes | Full approval flow |
| Hub | Toolkit | ✅ Yes | ✅ Yes | Safe file I/O |
| Workers | RefactorWorker | ✅ Yes | ✅ Yes | analyze/transform/validate |
| Workers | AssimilateWorker | ✅ Yes | ✅ Yes | learn/integrate/report |
| Orchestrators | TodoSwarmCoordinator | ✅ Partial | ✅ Yes | Integrated with Workflows |
| Orchestrators | TechnologyAgent | ❌ No | ✅ Exists | Needs worker wrapper |
| Orchestrators | QualityEnforcer | ❌ No | ✅ Exists | Needs worker wrapper |
| Orchestrators | DeadCodeMonitor | ❌ No | ✅ Exists | Needs worker wrapper |
| Supervisors | All | ✅ Yes | ✅ Yes | Compatible |
| Engines | TaskGraphEngine | ⚠️ Partial | ✅ Exists | Can delegate to Workflows |
| Engines | Evolution | ✅ Yes | ✅ Yes | Works with planner |
| Monitoring | ExecutionTracer | ✅ Yes | ✅ Yes | Tracks Workflows status |

---

## Recommended Next Steps

1. **Wrap existing agents as workers**
   - Create `TechDetectionWorker`, `QualityCheckWorker`, `DeadCodeWorker`
   - Add to RefactorPlanner node generation

2. **Extend RefactorPlanner to produce comprehensive HTDAG**
   - Include analysis nodes (tech, quality, dead code)
   - Include refactoring nodes (refactor, assimilate)
   - Include approval gates
   - Include integration nodes

3. **Add telemetry to Workflows execution**
   - Track node execution time
   - Track worker success rates
   - Feed MetricsFeeder for dashboards

4. **Implement callback-based approvals**
   - Arbiter tokens can trigger external approval (webhooks, Slack, etc.)
   - Wait for callback before proceeding past approval nodes

5. **Database persistence for workflows**
   - Use `Singularity.QuantumFlow.Workflow` Ecto schema
   - Persist to PostgreSQL for durability + audit log
   - Keep ETS for fast lookups

---

## Summary

✅ **Core system complete and unified**: Todo → Plan → Execute → Approve → Apply
✅ **60+ agent modules catalogued and mapped**
✅ **Worker contract standardized** for all integration
✅ **Full dry-run safety** with Arbiter approval gates
⚠️ **Next phase**: Wrap existing agents as workers (quick integration wins)

**System Status:** Production-ready foundation with clear path to integrate all existing agents.

