# Agent System Dependency Graph
**Generated:** 2025-01-24
**Purpose:** Visual reference for agent dependencies and relationships

---

## High-Level Architecture

```mermaid
graph TB
    subgraph "Layer 1: OTP Foundation"
        AS[AgentSupervisor<br/>DynamicSupervisor]
        PR[ProcessRegistry]
        AUT[Autonomy.*<br/>RuleEngine, Decider, Limiter]
    end

    subgraph "Layer 2: Core Infrastructure"
        BASE[Agent<br/>Base Class<br/>1026 LOC]
        CS[CodeStore]
        CTRL[Control]
        HR[HotReload]
    end

    subgraph "Layer 3: Production Agents"
        COA[CostOptimizedAgent<br/>551 LOC]
        DCM[DeadCodeMonitor<br/>629 LOC]
        DU[DocumentationUpgrader<br/>573 LOC]
        DP[DocumentationPipeline<br/>501 LOC]
        QE[QualityEnforcer<br/>497 LOC]
        RE[RemediationEngine<br/>569 LOC]
    end

    subgraph "Layer 4: Real Implementations"
        AA[ArchitectureEngine.Agent<br/>157 LOC]
        TA[TechnologyAgent<br/>665 LOC]
        CA[ChatConversationAgent<br/>664 LOC]
        RA[RefactoringAgent<br/>247 LOC]
    end

    subgraph "Layer 5: Support & Coordination"
        SPAWN[AgentSpawner<br/>136 LOC]
        TWA[TodoWorkerAgent<br/>150 LOC]
        AEW[AgentEvolutionWorker<br/>100 LOC<br/>OBAN]
        AIB[AgentImprovementBroadcaster<br/>67 LOC]
    end

    subgraph "Layer 6: Application"
        ASUP[Agents.Supervisor<br/>54 LOC]
        RTB[RuntimeBootstrapper<br/>82 LOC<br/>BROKEN]
    end

    %% Dependencies
    AS --> BASE
    PR --> BASE
    AUT --> BASE

    BASE --> CS
    BASE --> CTRL
    BASE --> HR

    CS --> COA
    CS --> DU
    CS --> DP

    CTRL --> QE
    CTRL --> RE

    BASE --> AA
    BASE --> TA
    BASE --> CA
    BASE --> RA

    AS --> SPAWN
    SPAWN --> TWA
    SPAWN --> AEW
    SPAWN --> AIB

    ASUP --> AS
    ASUP --> RTB
    RTB --> BASE

    %% Styling
    classDef broken fill:#f99,stroke:#900,stroke-width:3px
    classDef production fill:#9f9,stroke:#090,stroke-width:2px
    classDef support fill:#99f,stroke:#009,stroke-width:2px

    class RTB broken
    class COA,DCM,DU,DP,QE,RE,AA,TA,CA,RA production
    class SPAWN,TWA,AEW,AIB support
```

---

## Agent Interaction Flow

```mermaid
sequenceDiagram
    participant User
    participant AgentSpawner
    participant AgentSupervisor
    participant Agent
    participant LLM
    participant CodeStore

    User->>AgentSpawner: spawn(config)
    AgentSpawner->>AgentSupervisor: start_child(Agent, opts)
    AgentSupervisor->>Agent: start_link(opts)
    Agent->>Agent: init(opts)
    Agent-->>AgentSpawner: {:ok, pid}
    AgentSpawner-->>User: {:ok, agent_info}

    User->>Agent: execute_task(task, context)
    Agent->>Agent: route to agent type

    alt CostOptimizedAgent
        Agent->>Agent: check_rules
        alt Rules succeed
            Agent-->>User: {:ok, result}
        else Rules fail
            Agent->>LLM: call(:simple, messages)
            LLM-->>Agent: {:ok, response}
            Agent-->>User: {:ok, result}
        end
    else DocumentationPipeline
        Agent->>CodeStore: scan_files()
        CodeStore-->>Agent: files
        Agent->>Agent: analyze_quality()
        Agent->>Agent: apply_upgrades()
        Agent->>CodeStore: write_files()
        Agent-->>User: {:ok, report}
    end
```

---

## Critical Dependencies (Must Fix)

### 1. RuntimeBootstrapper → ??? (BROKEN)

```mermaid
graph LR
    RTB[RuntimeBootstrapper] -.->|References| UNDEF[Singularity.SelfImprovingAgent<br/>UNDEFINED]
    RTB -.->|Should use?| BASE[Singularity.Agent<br/>Base Class]
    RTB -.->|Or create?| ALIAS[Singularity.SelfImprovingAgent<br/>Alias Module]

    classDef broken fill:#f99,stroke:#900,stroke-width:3px
    classDef fix fill:#9f9,stroke:#090,stroke-width:2px

    class UNDEF,RTB broken
    class BASE,ALIAS fix
```

**Fix Options:**
- Option A: `RTB` → `Singularity.Agent` (base class)
- Option B: Create alias `Singularity.SelfImprovingAgent` → `Singularity.Agent`

---

### 2. Agent Namespace Collision

```mermaid
graph TB
    subgraph "Current (BROKEN)"
        AGENT1[agents/agent.ex<br/>Singularity.Agent?]
        REF1[References to<br/>Singularity.Agent]
        UNDEF1[Undefined module<br/>confusion]
    end

    subgraph "Proposed (FIXED)"
        AGENT2[agents/base.ex<br/>Singularity.Agents.Base]
        ALIAS2[agent.ex<br/>Singularity.Agent<br/>Alias to Base]
        REF2[Clear references<br/>No confusion]
    end

    AGENT1 -.->|Rename| AGENT2
    AGENT1 -.->|Create| ALIAS2
    REF1 -->|Update| REF2

    classDef broken fill:#f99,stroke:#900,stroke-width:3px
    classDef fix fill:#9f9,stroke:#090,stroke-width:2px

    class AGENT1,REF1,UNDEF1 broken
    class AGENT2,ALIAS2,REF2 fix
```

---

### 3. Health Module Duplication

```mermaid
graph LR
    subgraph "Current (DUPLICATE)"
        IHA[infrastructure/health_agent.ex<br/>Service Health<br/>100 LOC]
        AH1[health/agent_health.ex<br/>Agent Health<br/>100 LOC]
    end

    subgraph "Proposed (CONSOLIDATED)"
        AH2[health/agent_health.ex<br/>Unified Health<br/>150 LOC<br/>Agent + Service]
    end

    IHA -.->|Merge into| AH2
    AH1 -.->|Expand| AH2

    classDef duplicate fill:#ff9,stroke:#990,stroke-width:2px
    classDef consolidated fill:#9f9,stroke:#090,stroke-width:2px

    class IHA,AH1 duplicate
    class AH2 consolidated
```

---

## Agent Type Resolution Flow

```mermaid
graph TD
    START[User calls Agent.execute_task/3]
    START --> LOOKUP[Lookup agent_id in ProcessRegistry]
    LOOKUP --> CHECK{Agent found?}
    CHECK -->|No| ERROR[Return :not_found]
    CHECK -->|Yes| GETTYPE[Get agent type from registry]
    GETTYPE --> RESOLVE[Resolve agent module]

    RESOLVE --> TYPE{Agent Type?}
    TYPE -->|:architecture| AA[ArchitectureAgent.execute_task/2]
    TYPE -->|:cost_optimized| COA[CostOptimizedAgent.execute_task/2]
    TYPE -->|:technology| TA[TechnologyAgent.execute_task/2]
    TYPE -->|:refactoring| RA[RefactoringAgent.execute_task/2]
    TYPE -->|:self_improving| SIA[SelfImprovingAgent.execute_task/2]
    TYPE -->|:chat| CA[ChatConversationAgent.execute_task/2]
    TYPE -->|Unknown| UNKNOWN[Return :unknown_agent_type]

    AA --> RESULT[Return result]
    COA --> RESULT
    TA --> RESULT
    RA --> RESULT
    SIA --> RESULT
    CA --> RESULT

    classDef error fill:#f99,stroke:#900,stroke-width:2px
    classDef success fill:#9f9,stroke:#090,stroke-width:2px

    class ERROR,UNKNOWN error
    class RESULT success
```

---

## Module Dependency Matrix

| Module | Depends On | Used By | Status |
|--------|-----------|---------|--------|
| **Agent (Base)** | CodeStore, Control, HotReload, Autonomy.* | All agents, AgentSpawner | ⚠️ Namespace collision |
| **AgentSupervisor** | - | Agents.Supervisor, AgentSpawner | ✅ Working |
| **ProcessRegistry** | - | Agent, AgentSpawner | ✅ Working |
| **AgentSpawner** | AgentSupervisor, Agent | TaskGraphExecutor, Lua | ✅ Working |
| **CostOptimizedAgent** | RuleEngine, Correlation, LLM.Service | Agent routing | ✅ Working |
| **DeadCodeMonitor** | Repo, DeadCodeHistory, Bash | Agent routing | ✅ Working |
| **DocumentationUpgrader** | All 6 agents, CodeStore, TemplateService | DocumentationPipeline | ✅ Working |
| **DocumentationPipeline** | DocumentationUpgrader, QualityEnforcer | Application | ✅ Working |
| **QualityEnforcer** | ArtifactStore, TechnologyAgent | DocumentationPipeline | ✅ Working |
| **RemediationEngine** | RAGCodeGenerator, Store | QualityEnforcer | ✅ Working |
| **RuntimeBootstrapper** | AgentSupervisor, SelfImprovingAgent | Agents.Supervisor | ❌ BROKEN |
| **Agents.Supervisor** | RuntimeBootstrapper, AgentSupervisor | Application | ⚠️ Blocked by RTB |
| **ArchitectureEngine.Agent** | ArchitectureEngine | Agent routing | ✅ Working |
| **TechnologyAgent** | TechnologyTemplateLoader, FrameworkDetector | Agent routing | ✅ Working |
| **ChatConversationAgent** | GoogleChat, Slack | Agent routing | ✅ Working |
| **RefactoringAgent** | Analysis, CodeStore, QualityEngine | Agent routing | ✅ Working |
| **TodoWorkerAgent** | TaskGraph, TodoStore | TodoSwarmCoordinator | ✅ Working |
| **AgentEvolutionWorker** | Evolution, Feedback.Analyzer | Oban.Cron | ⚠️ Blocked by Oban |
| **AgentImprovementBroadcaster** | Agent, :pg, :rpc | Control | ✅ Working |
| **Infrastructure.HealthAgent** | CodebaseStore | - | ⚠️ DUPLICATE |
| **Health.AgentHealth** | ProcessRegistry, :sys | - | ⚠️ DUPLICATE |
| **MetricsFeeder** | SelfImprovingAgent | - | ⚠️ Test only |
| **RealWorkloadFeeder** | SelfImprovingAgent, LLM.Service | - | ⚠️ Test only |

---

## Data Flow Diagrams

### Agent Spawning Flow

```mermaid
flowchart TD
    START([User Request]) --> SPAWN[AgentSpawner.spawn/1]
    SPAWN --> GENERATE[Generate unique agent_id]
    GENERATE --> CONFIG[Build child_spec with config]
    CONFIG --> DSUPER[DynamicSupervisor.start_child]
    DSUPER --> AGENT[Agent.start_link/1]
    AGENT --> INIT[Agent.init/1]
    INIT --> REGISTER[Register in ProcessRegistry]
    REGISTER --> READY[Agent ready for tasks]
    READY --> RETURN([Return agent metadata])

    classDef process fill:#99f,stroke:#009,stroke-width:2px
    classDef decision fill:#ff9,stroke:#990,stroke-width:2px
    classDef success fill:#9f9,stroke:#090,stroke-width:2px

    class SPAWN,DSUPER,AGENT process
    class READY success
```

### Self-Improvement Cycle

```mermaid
flowchart LR
    subgraph "Metrics Collection"
        M1[Agent receives task]
        M2[Track success/failure]
        M3[Calculate metrics]
        M4[Update agent state]
    end

    subgraph "Decision Making"
        D1[Evaluate performance]
        D2{Below threshold?}
        D3[Generate improvement]
    end

    subgraph "Evolution"
        E1[Validate code]
        E2[Apply update]
        E3[Test new version]
        E4{Regression?}
        E5[Rollback]
        E6[Keep update]
    end

    M1 --> M2 --> M3 --> M4
    M4 --> D1 --> D2
    D2 -->|Yes| D3
    D2 -->|No| M1
    D3 --> E1 --> E2 --> E3 --> E4
    E4 -->|Yes| E5 --> M1
    E4 -->|No| E6 --> M1

    classDef metrics fill:#99f,stroke:#009,stroke-width:2px
    classDef decision fill:#ff9,stroke:#990,stroke-width:2px
    classDef evolution fill:#9f9,stroke:#090,stroke-width:2px

    class M1,M2,M3,M4 metrics
    class D1,D2,D3 decision
    class E1,E2,E3,E4,E5,E6 evolution
```

---

## Critical Path Analysis

### Path 1: Basic Agent Spawning (Currently BROKEN)

```
Application
  → Agents.Supervisor
    → RuntimeBootstrapper ❌ BROKEN
      → Singularity.SelfImprovingAgent ❌ UNDEFINED

FIX: RuntimeBootstrapper → Singularity.Agent ✅
```

### Path 2: Task Execution (Should Work After Fix)

```
User
  → Agent.execute_task(agent_id, task, context)
    → ProcessRegistry lookup ✅
    → Get agent type ✅
    → Resolve agent module ✅
    → Agent.execute_task(task, context) ✅
      → CostOptimizedAgent logic ✅
      → TechnologyAgent logic ✅
      → etc.
```

### Path 3: Evolution Cycle (Blocked by Oban)

```
Oban.Cron (hourly)
  → AgentEvolutionWorker ⚠️ BLOCKED
    → Feedback.Analyzer.find_agents_needing_improvement
    → Evolution.evolve_agent
    → Metrics tracking

FIX: Make Oban optional OR run manually ✅
```

---

## Legend

```mermaid
graph LR
    WORKING[✅ Working Module]
    BROKEN[❌ Broken Module]
    BLOCKED[⚠️ Blocked/Duplicate]
    SUPPORT[🔧 Support Module]

    classDef working fill:#9f9,stroke:#090,stroke-width:2px
    classDef broken fill:#f99,stroke:#900,stroke-width:3px
    classDef blocked fill:#ff9,stroke:#990,stroke-width:2px
    classDef support fill:#99f,stroke:#009,stroke-width:2px

    class WORKING working
    class BROKEN broken
    class BLOCKED blocked
    class SUPPORT support
```

---

**Next Steps:** Fix critical path (RuntimeBootstrapper + namespace collision) to unblock agent system
