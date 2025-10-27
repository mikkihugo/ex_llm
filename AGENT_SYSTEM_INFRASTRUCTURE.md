# Singularity Agent System - Existing Infrastructure Analysis

## Executive Summary

Singularity has a **partially implemented** agent coordination system. The foundational pieces exist (capability tracking, agent supervision, goal decomposition) but are **not yet integrated** with communication/routing mechanisms. This is intentional - the system was designed modularly and awaits the orchestration layer.

---

## 1. AGENT CAPABILITY TRACKING (EXISTS - FULLY IMPLEMENTED)

### Location
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/coordination/capability_registry.ex`
- `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/coordination/agent_capability.ex`

### What Exists

#### `AgentCapability` Struct
Comprehensive capability descriptor for agents:
```elixir
defstruct [
  :agent_name,
  :role,
  :domains,
  :input_types,
  :output_types,
  :complexity_level,
  :estimated_cost,
  :availability,
  :success_rate,
  :preferred_model,
  tags: [],
  metadata: %{}
]
```

**Supported Roles:**
- `:self_improve`, `:cost_optimize`, `:architect`, `:technology`, `:refactoring`, `:chat`, `:quality_enforcer`

**Supported Domains:**
- `:code_quality`, `:testing`, `:documentation`, `:architecture`, `:performance`, `:security`, `:refactoring`, `:knowledge`, `:learning`, `:monitoring`

**Input/Output Types:**
- Input: `:code`, `:design`, `:requirements`, `:codebase`, `:metrics`, `:feedback`
- Output: `:code`, `:analysis`, `:plan`, `:documentation`, `:metrics`, `:decision`

#### `CapabilityRegistry` GenServer
Main registry managing all agent capabilities:

**Public API:**
- `register(agent_name, attrs)` - Register agent capabilities
- `get_capability(agent_name)` - Get agent's capability descriptor
- `agents_for_domain(domain)` - Find agents by domain
- `agents_with_role(role)` - Find agents by role
- `best_agent_for_task(task)` - Find best agent for a task using fit scoring
- `top_agents_for_task(task, count)` - Get ranked list of agents
- `update_availability(agent_name, status)` - Track availability
- `update_success_rate(agent_name, rate)` - Update from feedback
- `domain_has_agents?(domain)` - Check domain coverage

**Fit Scoring Algorithm:**
- Domain match: 0.3 weight
- Input/output compatibility: 0.3 weight
- Success rate: 0.2 weight
- Availability: 0.2 weight

**Data Structure:**
- `capabilities`: Map of agent_name -> AgentCapability
- `index_by_domain`: Map of domain -> [agent_names]
- `index_by_role`: Map of role -> agent_name

---

## 2. AGENT SUPERVISION & LIFECYCLE (EXISTS - MOSTLY IMPLEMENTED)

### Supervision Tree
Location: `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/application.ex`

**Layer 4 (Agents & Execution):**
```
Agents.Supervisor
  ├─ RuntimeBootstrapper (fixed)
  │  └─ Ensures self-improving agent for TaskGraph runtime
  │
  └─ AgentSupervisor (DynamicSupervisor)
     └─ Individual Agent instances (dynamically spawned)
```

### Agent Supervision Details

#### `Agents.Supervisor`
Location: `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/supervisor.ex`
- Uses `:one_for_one` strategy
- Manages RuntimeBootstrapper and AgentSupervisor

#### `AgentSupervisor`
Location: `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/agent_supervisor.ex`
- DynamicSupervisor for spawning agents on-demand
- Provides operations:
  - `pause_all_agents()` / `resume_all_agents()`
  - `get_all_agents()`
  - `improve_agent(agent_id, payload)`

#### `RuntimeBootstrapper`
Location: `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/runtime_bootstrapper.ex`
- Ensures a single self-improving agent for TaskGraph runtime
- Implements automatic retry on startup failure
- Retry interval: 5 seconds

### Agent Instance Management

#### `Singularity.Agents.Agent`
Location: `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/agent.ex`

**Core GenServer for agent instances:**
- Each agent is a GenServer registered via `ProcessRegistry`
- Key operations:
  - `improve(agent_id, payload)` - Queue improvement
  - `update_metrics(agent_id, metrics)` - Feed performance data
  - `record_outcome(agent_id, outcome)` - Track success/failure
  - `pause(agent_id)` / `resume(agent_id)` - Control flow
  - `execute_task(agent_id, task, context)` - Route tasks to agent-specific handlers

**Agent Registration:**
- Via Registry: `{:via, Registry, {ProcessRegistry, {:agent, agent_id}}}`
- Enables lookups by agent_id

**State Management:**
- Improvement queue (Erlang :queue)
- Metrics aggregation
- Cycle tracking
- Performance validation
- Fingerprint-based duplicate detection

**Features:**
- Automatic queue processing
- Rate limiting via `Limiter.allow?/1`
- Regression detection on improvements
- Automatic rollback on validation failure
- Hot-reload integration

---

## 3. GOAL DECOMPOSITION (EXISTS - FULLY IMPLEMENTED)

### Location
`/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/coordination/goal_decomposer.ex`

### What It Does

Breaks high-level goals into concrete agent subtasks:

**Input:** `"Improve code quality in the authentication module - refactor duplicated code, add tests, document"`

**Output:** Array of tasks with:
```elixir
[
  %{id: 1, goal: "Analyze auth module", domain: :code_quality, complexity: :medium, ...},
  %{id: 2, goal: "Refactor duplicates", domain: :refactoring, depends_on: [1], ...},
  %{id: 3, goal: "Add tests", domain: :testing, depends_on: [2], ...},
  %{id: 4, goal: "Validate improvements", domain: :monitoring, depends_on: [3], ...}
]
```

### API
- `decompose(goal)` - LLM-based decomposition (complex)
- `quick_decompose(goal)` - Heuristic-based (fast, no LLM)

### Task Structure
Each task includes:
- `:id` - Unique identifier
- `:goal` - Natural language description
- `:domain` - What area it affects
- `:complexity` - simple/medium/complex
- `:input_type` - What kind of input needed
- `:output_type` - What it produces
- `:depends_on` - Task IDs that must complete first
- `:priority` - 1-5 (higher = execute first)
- `:estimated_effort` - 1-10 scale

### Validation
- No circular dependencies
- References valid task IDs
- Task count limits (1-20)

---

## 4. AGENT SPAWNING (EXISTS - PARTIALLY IMPLEMENTED)

### Location
`/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/agent_spawner.ex`

### What It Does
Converts Lua agent configurations into running Agent processes:

```elixir
config = %{
  "role" => "architect",
  "behavior_id" => "code-analysis-v1",
  "config" => %{"tools" => ["read_file"], "confidence_threshold" => 0.85}
}

{:ok, agent} = AgentSpawner.spawn(config)
# => %{id: "agent-xyz", pid: #PID<0.250.0>, role: "architect"}
```

### Implementation
- Generates unique agent IDs: `"agent-#{:erlang.unique_integer()}"`
- Spawns via `DynamicSupervisor.start_child(AgentSupervisor, {Agent, [opts]})`
- Extracts: role, behavior_id, config from map

---

## 5. AGENT COMMUNICATION & MESSAGING

### NATS Subjects (Defined but NOT YET IMPLEMENTED for agents)

Location: `/Users/mhugo/code/singularity-incubation/docs/messaging/NATS_SUBJECTS.md`

**Defined subjects for agent coordination (lines 129-152):**
```
agents.spawn                # Spawn new agents
agents.spawn.result         # Agent spawn results
agents.status               # Agent status updates
agents.status.query         # Agent status queries
agents.result               # Agent execution results
agents.improve              # Agent improvement events
agents.stop                 # Stop agent requests
agents.stop.result          # Agent stop results
```

**Status:** DEFINED but NO subscribers/publishers yet

### Current Communication Methods

**Within same Elixir node:**
- Direct GenServer calls: `GenServer.call/cast`
- Registry lookups: `Registry.lookup(ProcessRegistry, {:agent, agent_id})`
- No NATS integration yet

**Between nodes/services:**
- No inter-agent communication implemented
- Would go via NATS when agent orchestration is added

---

## 6. INDIVIDUAL AGENT IMPLEMENTATIONS

### Implemented Agent Types

1. **SelfImprovingAgent**
   - Location: `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/agents/self_improving_agent.ex`
   - Self-improving with continuous learning
   - Can observe metrics, decide evolution, synthesize new code

2. **CostOptimizedAgent**
   - Location: `cost_optimized_agent.ex`
   - Specializes in cost-aware task execution

3. **ArchitectureAgent**
   - Handles architectural analysis and planning

4. **TechnologyAgent**
   - Technology stack analysis and recommendations

5. **RefactoringAgent**
   - Code refactoring specialization

6. **ChatConversationAgent**
   - Conversational interface

7. **Quality Enforcer** (support)
   - Ensures quality standards

---

## 7. WHAT'S MISSING / NOT YET INTEGRATED

### Missing Components

1. **Task Router/Dispatcher**
   - NOT implemented: Logic to route tasks from goals to agents
   - Capability Registry exists, but no router using it
   - Goal Decomposer exists, but decomposed tasks aren't routed

2. **Agent Orchestrator**
   - NOT implemented: Central orchestrator managing task execution
   - No coordination between agents
   - No parallel task handling

3. **NATS Integration for Agents**
   - NATS subjects defined but no publishers/subscribers
   - No inter-node agent communication
   - Would enable distributed agent orchestration

4. **Agent Discovery/Announcement**
   - Agents don't announce capabilities when starting
   - CapabilityRegistry must be manually populated
   - No automatic registration on startup

5. **Feedback Loop**
   - Agent.record_outcome() exists
   - CapabilityRegistry.update_success_rate() exists
   - But no system connecting outcomes to capability updates

6. **Load Balancing**
   - No consideration of agent capacity/availability in routing
   - AgentCapability tracks availability but not used in routing

7. **Coordination Router**
   - NOT implemented: The missing piece that ties it all together
   - Would:
     - Take decomposed tasks
     - Find best agents using CapabilityRegistry
     - Route tasks to agents
     - Track execution
     - Update capabilities from outcomes

---

## 8. ARCHITECTURE DIAGRAM (Current State)

```
┌─────────────────────────────────────────────────────────────┐
│                   GOALS / USER REQUEST                       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │   Goal Decomposer      │ ✓ EXISTS
            │  (LLM or heuristic)    │
            └────────┬───────────────┘
                     │
                     ▼
            ┌────────────────────────┐
            │  Decomposed Tasks      │ ✓ EXISTS
            │  (with dependencies)   │
            └────────┬───────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────┐
    │  COORDINATION ROUTER (NOT YET BUILT)   │
    │  Would route tasks to agents            │
    └────────┬───────────────────────┬────────┘
             │                       │
    ┌────────▼─────────┐   ┌────────▼──────────┐
    │ Capability       │   │ Agent Task        │
    │ Registry         │   │ Executor          │
    │ ✓ EXISTS         │   │ ✗ NOT BUILT       │
    │ - Tracks what    │   │                   │
    │   agents can do  │   │ Would coordinate  │
    │ - Fit scoring    │   │ task execution    │
    │ - Availability   │   │ across agents     │
    └──────────────────┘   └───────────────────┘
             │                        │
             ▼                        ▼
    ┌─────────────────────────────────────────┐
    │        Agent Supervision Tree            │
    │  ✓ FULLY IMPLEMENTED                    │
    │                                          │
    │  Agents.Supervisor                      │
    │    ├─ RuntimeBootstrapper               │
    │    └─ AgentSupervisor (Dynamic)         │
    │       └─ Individual Agent GenServers    │
    │          - SelfImproving                │
    │          - CostOptimized                │
    │          - Architecture                 │
    │          - Technology                   │
    │          - Refactoring                  │
    │          - Chat                         │
    │          - QualityEnforcer               │
    └─────────────────────────────────────────┘
             │
             ▼
    ┌─────────────────────────────┐
    │  ProcessRegistry            │
    │  (Agent discovery by ID)    │
    │  ✓ EXISTS                   │
    └─────────────────────────────┘
```

---

## 9. NATS INTEGRATION STATUS

### What's Defined
- Agent NATS subjects documented in `NATS_SUBJECTS.md`
- Complete message format specs

### What's NOT Implemented
- No NATS publishers for agents.* subjects
- No NATS subscribers for agents.* subjects
- No request/reply handling
- No inter-node agent communication

### Why This Matters
- Single-node only currently
- Cannot distribute agents across multiple Singularity instances
- NATS infrastructure exists but agents don't use it

---

## 10. KEY FILES & LOCATIONS

### Core Agent System
| File | Location | Status |
|------|----------|--------|
| Agent (GenServer) | `agents/agent.ex` | ✓ Complete |
| Capability Registry | `agents/coordination/capability_registry.ex` | ✓ Complete |
| Agent Capability | `agents/coordination/agent_capability.ex` | ✓ Complete |
| Goal Decomposer | `agents/coordination/goal_decomposer.ex` | ✓ Complete |
| Agent Spawner | `agents/agent_spawner.ex` | ✓ Complete |
| Agents Supervisor | `agents/supervisor.ex` | ✓ Complete |
| Agent Supervisor | `agents/agent_supervisor.ex` | ✓ Complete |
| RuntimeBootstrapper | `agents/runtime_bootstrapper.ex` | ✓ Complete |

### Agent Implementations
| Agent | File | Status |
|-------|------|--------|
| SelfImproving | `agents/self_improving_agent.ex` | ✓ Complete |
| CostOptimized | `agents/cost_optimized_agent.ex` | ✓ Complete |
| Architecture | Various | ✓ Complete |
| Technology | Various | ✓ Complete |
| Refactoring | Various | ✓ Complete |
| Chat | Various | ✓ Complete |
| QualityEnforcer | `agents/quality_enforcer.ex` | ✓ Complete |

### Configuration & Messaging
| File | Location | Status |
|------|----------|--------|
| Config | `config/config.exs` | ✓ Exists (no agent config yet) |
| NATS Subjects | `docs/messaging/NATS_SUBJECTS.md` | ✓ Defined |
| Application | `application.ex` | ✓ Complete |

---

## 11. INTEGRATION REQUIREMENTS (What Would Be Needed)

### To Build Complete Agent Orchestration:

1. **Coordination Router Module**
   - Takes decomposed tasks
   - Queries CapabilityRegistry for best agents
   - Executes tasks via Agent.execute_task/3
   - Tracks outcomes
   - Feeds back to CapabilityRegistry

2. **NATS Publisher for Agents**
   - Publish agent spawning requests
   - Publish agent status updates
   - Publish task routing decisions

3. **NATS Subscriber for Agents**
   - Listen for agent spawn requests
   - Listen for task execution requests
   - Listen for status queries

4. **Automatic Capability Registration**
   - On agent startup, register with CapabilityRegistry
   - Set initial role, domains, capabilities
   - Update availability in real-time

5. **Feedback Integration**
   - Outcome -> success_rate update
   - Metrics -> availability update
   - Performance -> cost estimation update

6. **Agent Discovery Protocol**
   - Agents announce via NATS
   - Central registry aggregates
   - Enables distributed deployment

---

## 12. RECOMMENDATIONS FOR BUILDING ON THIS

### Quick Start Path
1. Create `Singularity.Agents.CoordinationRouter` module
2. Implement task routing using CapabilityRegistry.best_agent_for_task/1
3. Add agent outcome -> capability feedback loop
4. Extend Agent.execute_task/3 to be agent-type aware

### Full Distributed Path
1. Add NATS publishers to Agent (for status updates)
2. Add NATS subscribers to handle agent.* subjects
3. Implement agent discovery via system.engines.* subjects
4. Create distributed task queue

### No Breaking Changes Needed
- All foundational pieces already in place
- CapabilityRegistry and Agent supervision are production-ready
- New router would be purely additive
- Existing agents would work unchanged

---

## 13. SUMMARY TABLE

| Component | Exists | Production-Ready | Notes |
|-----------|--------|------------------|-------|
| Agent GenServer | ✓ | Yes | Fully implemented with all features |
| Capability Registry | ✓ | Yes | Complete fit-scoring and indexing |
| Goal Decomposition | ✓ | Yes | LLM and heuristic variants |
| Agent Supervision | ✓ | Yes | Dynamic spawning with retry logic |
| Agent Spawning | ✓ | Yes | Lua config to GenServer |
| SelfImprovingAgent | ✓ | Yes | Full evolution lifecycle |
| Other Agent Types | ✓ | Yes | All 6 types implemented |
| Task Router | ✗ | N/A | Key missing piece |
| NATS Integration | ✗ (Partial) | N/A | Subjects defined, no implementation |
| Feedback Loop | ~ | Partial | Components exist, not wired together |
| Load Balancing | ✗ | N/A | Not needed single-node |
| Agent Discovery | ✗ | N/A | Manual registration required |

---

## Conclusion

Singularity has a **solid foundation** for agent orchestration. The supervision, capability tracking, and individual agents are all production-ready. What's missing is the **coordination layer** that ties them together - a router that:
1. Takes goals
2. Decomposes them
3. Finds best agents using CapabilityRegistry
4. Routes tasks
5. Tracks outcomes
6. Updates capabilities

This is intentional modularity. Building on top of this foundation is straightforward and requires no changes to existing code.

