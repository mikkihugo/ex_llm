# Singularity Agent System

Singularity includes a complete autonomous agent system with **60+ agent-related modules** organized into specialized workers, coordinators, supervisors, and orchestrators.

## Overview

The agent system is unified under `Singularity.Workflows` with:
- **Approval flow** (Arbiter tokens)
- **Dry-run safety** (test before applying)
- **Standardized worker contract**: `function(args_map, opts) → {:ok, result} | {:error, reason}`

## Agent Types

### Primary Agents

| Agent | Purpose | Status |
|-------|---------|--------|
| **SelfImprovementAgent** | GenServer orchestrator for edits/workflows | ✅ Complete |
| **CostOptimizedAgent** | Reduce LLM costs via caching | ✅ Active |
| **TechnologyAgent** | Detect/manage technology stacks | ✅ Active |
| **QualityEnforcer** | Enforce code quality standards | ✅ Active |
| **DeadCodeMonitor** | Detect and report dead code | ✅ Active |
| **ChangeTracker** | Track code changes over time | ✅ Active |

### Workers (Unified in Workflows)

| Worker | Purpose | Functions |
|--------|---------|-----------|
| **RefactorWorker** | Analyze/transform/validate code | `:analyze`, `:transform`, `:validate` |
| **AssimilateWorker** | Learn from changes, integrate, report | `:learn`, `:integrate`, `:report` |

### Coordinators

| Coordinator | Purpose | Status |
|-------------|---------|--------|
| **TodoSwarmCoordinator** | Poll todos → detect smells → plan → execute | ✅ Primary entry point |
| **FileAnalysisSwarmCoordinator** | Coordinate file analysis across swarm | ✅ Active |
| **ExecutionOrchestrator** | High-level execution orchestration | ✅ Active |

### Infrastructure

| Component | Purpose | Status |
|-----------|---------|--------|
| **AgentSpawner** | Factory for spawning agents | ✅ Active |
| **RealWorkloadFeeder** | Feed real workloads to agents | ✅ Active |
| **MetricsFeeder** | Track agent performance metrics | ✅ Active |
| **AgentPerformanceDashboard** | Monitor agent health | ✅ Active |

## Architecture

```
┌─────────────────────────────────────────────────┐
│        Singularity.Workflows (Hub)               │
│     Unified HTDAG + Approvals + Dry-Run-Safe    │
└─────────────────────────────────────────────────┘
         ↑ Entry points         ↑ Query/update
         │                      │
    ┌────┴────┬───────────┬─────┴────┐
    │         │           │           │
    ▼         ▼           ▼           ▼
TodoSwarm  Evolution  FileAnalysis ExecutionTracer
Coordinator (loop)    Coordinator  (monitoring)
    │         │           │           │
    └──→ Planner ─────────┴───────────┘
         │ (detect + plan)
         │
    ┌────┴──────────────────────────┐
    │ Returns: HTDAG workflow with  │
    │ worker nodes like:             │
    │ {RefactorWorker, :analyze}    │
    │ {AssimilateWorker, :learn}    │
    └────┬──────────────────────────┘
         │
    ┌────┴──────────────────────────┐
    │ Workflows.execute_workflow    │
    │ - Call worker(args, opts)     │
    │ - Collect dry-run results     │
    │ - Request approval if needed  │
    │ - Apply with token            │
    └────┬──────────────────────────┘
         │
    ┌────┴────┬───────────┬──────────┬──────────┐
    │         │           │          │          │
    ▼         ▼           ▼          ▼          ▼
 Refactor  Assimilate  Quality   Dead Code  Tech
 Worker    Worker      Enforcer   Monitor   Agent
```

## Usage Examples

### Basic Agent Execution

```elixir
alias Singularity.Workflows

# Execute workflow with approval gates
{:ok, workflow_id} = Workflows.execute_workflow(
  %{
    nodes: [
      %{
        id: "analyze_1",
        type: :task,
        worker: {RefactorWorker, :analyze},
        args: %{codebase_id: "my-project"}
      },
      %{
        id: "approve_1",
        type: :approval,
        reason: "manual_review",
        depends_on: ["analyze_1"]
      }
    ]
  },
  dry_run: true  # Test first!
)
```

### Agent Coordination

```elixir
alias Singularity.Execution.TodoSwarmCoordinator

# Coordinate multiple agents for a task
TodoSwarmCoordinator.coordinate(%{
  codebase_id: "my-project",
  task_type: :refactor
})
```

### Monitoring Agent Performance

```elixir
alias Singularity.Agents.AgentPerformanceDashboard

# Get agent health status
dashboard = AgentPerformanceDashboard.get_status()

# View metrics
AgentPerformanceDashboard.metrics("agent-123")
```

## Supervision Tree

```
Singularity.Agents.Supervisor (Root)
├── AgentSupervisor
│   ├── SelfImprovementAgent
│   ├── ChangeTracker
│   └── AgentSpawner
├── CoordinationSupervisor
│   ├── CapabilityRegistry
│   └── AgentRouter
└── ExecutionSupervisor
    ├── TodoSwarmCoordinator
    ├── FileAnalysisSwarmCoordinator
    └── RefactorAssimilateSwarmCoordinator
```

## Worker Contract

All agents wrapped as workers follow this pattern:

```elixir
defmodule Singularity.Execution.MyWorker do
  def my_action(args, opts) when is_map(args) do
    dry_run = Keyword.get(opts, :dry_run, true)
    
    if dry_run do
      {:ok, %{action: :my_action, dry_run: true, description: "Would do X"}}
    else
      case MyAgentModule.do_something(args) do
        {:ok, data} -> {:ok, %{action: :my_action, result: data}}
        {:error, reason} -> {:error, reason}
      end
    end
  end
end
```

## Workflows Integration

Agents are integrated via QuantumFlow workflows:

```elixir
# Workflow definition
workflow = %{
  nodes: [
    %{id: "detect", worker: {TechnologyAgent, :detect}, args: %{...}},
    %{id: "refactor", worker: {RefactorWorker, :analyze}, args: %{...}, depends_on: ["detect"]},
    %{id: "approve", type: :approval, depends_on: ["refactor"]},
    %{id: "integrate", worker: {AssimilateWorker, :integrate}, args: %{...}, depends_on: ["approve"]}
  ]
}

# Execute with dry-run safety
{:ok, results} = Singularity.Workflows.execute_workflow(workflow, dry_run: true)
```

## Configuration

Agent configuration is in `config/config.exs`:

```elixir
config :singularity, :agents,
  enabled: true,
  max_concurrent: 10,
  timeout_ms: 300_000
```

## Monitoring

- **Agent Performance Dashboard** - Monitor agent health
- **Metrics Dashboard** - Track execution metrics
- **Execution Tracer** - Debug workflow execution

## See Also

- **AGENT_SYSTEM_INVENTORY.md** - Complete detailed inventory (60+ modules)
- **README.md** - System overview
- **docs/BEAM_DEBUGGING_GUIDE.md** - Debugging agent execution
