# Singularity Central Evolution System - Architecture Exploration

## Executive Summary

Singularity is a multi-instance, multi-AI autonomous learning system with three main components:
1. **Singularity (Core)** - Main application in `nexus/singularity/` (5 execution phases, 39 components)
2. **Genesis** - Autonomous improvement hub in `nexus/genesis/` (rule evolution, experiment trials)
3. **CentralCloud** - Pattern intelligence aggregator in `nexus/central_services/lib/centralcloud/`

All three are **required** for full system functionality. Communication via pgmq, quantum_flow, NATS.

---

## 1. CentralCloud Structure

### Location
- **Main**: `/home/mhugo/code/singularity/nexus/central_services/lib/centralcloud/`
- **Database**: `central_services` (separate PostgreSQL instance)
- **Migrations**: `/home/mhugo/code/singularity/nexus/central_services/priv/repo/migrations/`

### Key Services

| Module | Purpose | Status |
|--------|---------|--------|
| `intelligence_hub.ex` (54KB) | Aggregates code/architecture/data intelligence from all instances | Core |
| `framework_learning_agent.ex` | Learns framework patterns across instances | Active |
| `framework_learning_orchestrator.ex` | Orchestrates framework learning | Active |
| `infrastructure_system_learning_orchestrator.ex` | Infrastructure pattern learning | Active |
| `llm_team_orchestrator.ex` | Multi-LLM coordination | Active |
| `template_service.ex` (17KB) | Template lifecycle management | Active |
| `shared_queue_manager.ex` | pgmq message routing & consensus | Active |
| `knowledge_cache.ex` | Cross-instance knowledge caching | Active |

### Key Consumers/Publishers
- **QuantumFlow Queues**: 
  - `intelligence_code_patterns_learned`
  - `intelligence_architecture_patterns_learned`
  - `intelligence_data_schemas_learned`
  - `intelligence_insights_query`
  - `intelligence_quality_aggregate`
- **Replication**: Logical replication from Singularity for templates
- **Consensus**: 3+ agents, 85%+ confidence threshold for approvals

### Database Schema (8 core tables)
```
- prompt_templates (embeddings for semantic search)
- template (replicated from Singularity)
- infrastructure_systems
- analysis_results
- code_snippets
- package, package_example
- security_advisory
```

---

## 2. Genesis Current State

### Location
- **Main**: `/home/mhugo/code/singularity/nexus/genesis/lib/genesis/`
- **Database**: `singularity` (shared with main app)
- **Migrations**: `/home/mhugo/code/singularity/nexus/genesis/priv/repo/migrations/`

### Key Modules (17 files)

| Module | Purpose |
|--------|---------|
| `application.ex` | OTP supervisor for Genesis services |
| `job_executor.ex` (9KB) | Executes evolution jobs in isolation |
| `llm_config_manager.ex` (8KB) | LLM configuration for experiments |
| `rule_engine.ex` (5KB) | Evaluates rules during trials |
| `quantum_flow_workflow_consumer.ex` (18KB) | Consumes evolution workflows from QuantumFlow |
| `shared_queue_consumer.ex` (9KB) | Processes shared queue messages |
| `isolation_manager.ex` (4KB) | Sandbox isolation for trial runs |
| `rollback_manager.ex` (7KB) | Handles rollback of failed evolutions |
| `sandbox_maintenance.ex` (7KB) | Maintenance of isolated sandboxes |
| `scheduler.ex` | Job scheduling |

### Key Capabilities
1. **Autonomous Rule Evolution** - Evaluates proposed rule changes
2. **Trial Execution** - A/B testing in isolated sandboxes
3. **Job Isolation** - Each evolution trial runs in isolation
4. **Rollback Management** - Reverts failed evolutions
5. **LLM Coordination** - Works with multiple LLM providers

### Database Schema (3 tables)
```
- experiment_records (trial executions)
- experiment_metrics (trial results)
- sandbox_history (isolation tracking)
```

---

## 3. Evolution Orchestrator (Current Implementation)

### Location
- **Core**: `singularity/lib/singularity/execution/evolution.ex` (17KB)
- **Orchestrator**: `singularity/lib/singularity/execution/orchestrator/`

### Current Evolution Types
1. **Pattern Enhancement** - Add high-confidence patterns
   - Precondition: success_rate < 90%
   - Validation: A/B test, measure improvement

2. **Model Optimization** - Switch cost-effective models
   - Precondition: avg_cost > $0.10
   - Validation: Cost reduction, quality maintained

3. **Cache Improvement** - Enhance caching strategy
   - Precondition: avg_latency > 2000ms
   - Validation: Measure latency reduction

4. **CodeEngine Health** - Improve CodeEngine integration
   - Precondition: health < 7.0 or fallback > 20%
   - Validation: Fallback reduction, health improvement

### Execution Strategy Pattern
```
ExecutionOrchestrator (Public API)
  ↓
ExecutionStrategyOrchestrator (Router)
  ├─ TaskGraphStrategy (Dependency DAGs)
  ├─ SparcStrategy (Template-driven)
  └─ MethodologyStrategy (SAFe workflow)
```

---

## 4. Agent Implementations

### Location
- **Agents**: `singularity/lib/singularity/agents/`
- **Schemas**: 77 schema files in `singularity/lib/singularity/schemas/`

### Primary Agent Types (Current)

| Agent | Location | Purpose |
|-------|----------|---------|
| `Agent.ex` (32KB) | Core GenServer for agent instance | Base agent with self-improvement loop |
| `SelfImprovingAgent.ex` (53KB) | Autonomous self-improvement | Main test agent |
| `CostOptimizedAgent.ex` (17KB) | Cost-optimization focus | Cost efficiency |
| `RemediationEngine.ex` (17KB) | Error remediation | Fix failures |
| `QualityEnforcer.ex` (15KB) | Quality metrics enforcement | QA/QC |
| `DeadCodeMonitor.ex` (19KB) | Dead code detection | Code cleanup |
| `SchemaGenerator.ex` (9KB) | Database schema generation | DB design |

### Workflow Agents
- `documentation_pipeline.ex` - Documentation generation
- `self_improvement_agent.ex` - Agent self-evolution
- `real_workload_feeder.ex` - Realistic workload generation
- `arbiter.ex` - Conflict resolution

### Agent Supervision & Coordination
```
Agent.Supervisor
  ├─ Agent instances (GenServers)
  ├─ Agent.Spawner (Dynamic creation)
  ├─ Agent.CoordinationAgents (Workflow coordination)
  └─ Agent.PerformanceDashboard
```

### Metric Reporting
```
Agent State
  ├─ cycles: evolution iterations
  ├─ metrics: {success_rate, latency, cost, feedback_score}
  ├─ status: idle|planning|executing|improving
  └─ improvement_history: array of applied improvements
        ↓
Metrics.Aggregator.get_metrics_for(agent_id, period)
        ↓
Database (execution_metrics, agent_metrics tables)
        ↓
Observer Dashboard (port 4002)
```

---

## 5. Database Structure

### Singularity Main DB (singularity)
**Key tables (77 schemas defined):**

**Execution & Control**
```
- execution/execution_record.ex
- execution/task.ex
- execution/rule.ex
- execution/rule_evolution_proposal.ex
- execution_metrics
- execution_outcome
```

**Patterns & Intelligence**
```
- instance_pattern.ex (local patterns)
- file_architecture_pattern.ex
- technology_pattern.ex
- approved_pattern.ex
- pattern_consensus.ex (multi-instance consensus)
- knowledge_artifact.ex (unified artifact store)
```

**Analysis & Quality**
```
- analysis/run.ex
- analysis/finding.ex
- code_analysis_result.ex
- failure_pattern.ex
- validation_metric.ex
```

**Agent & Autonomy**
```
- agent_metric.ex
- local_learning.ex (instance-specific learning)
```

**Code & Search**
```
- code_chunk.ex (with pgvector embeddings)
- code_embedding_cache.ex
- code_location_index.ex
- vector_search.ex
- vector_similarity_cache.ex
```

### Central_Services DB (centralcloud)
**8 core tables:**
```
- prompt_templates (with embeddings)
- templates (replicated)
- infrastructure_systems
- analysis_results
- code_snippets
- packages, package_examples
- security_advisories
```

### Shared Databases
- **pgvector**: 2560-dim embeddings (Qodo 1536 + Jina v3 1024)
- **pg_uuidv7**: Fast distributed IDs
- **pg_cron**: Scheduled tasks
- **pgmq**: Durable message queues
- **timescaledb**: Time-series metrics (optional)

---

## 6. Pattern Detection Current

### Location
- **Core**: `singularity/lib/singularity/architecture_engine/pattern_detector.ex` (8KB)
- **Orchestrator**: `singularity/lib/singularity/analysis/detection_orchestrator.ex` (14KB)
- **Stores**: `singularity/lib/singularity/architecture_engine/`

### Current Pattern Types (Config-Driven)
1. **Framework** - React, Django, Rails, etc.
   - Detector: `FrameworkDetector`
   - Store: `FrameworkPatternStore`

2. **Technology** - TypeScript, Python, Postgres, etc.
   - Detector: `TechnologyDetector`
   - Store: `TechnologyPatternStore`

3. **Service Architecture** - Microservices, monolith, etc.
   - Detector: `ServiceArchitectureDetector`
   - Store: `PatternStore`

### Architecture
```
DetectionOrchestrator (Public API)
  ├─ detect/2 (low-level, config-driven)
  ├─ detect_with_intent/2 (user intent matching)
  ├─ detect_and_cache/2 (with persistence)
  └─ Pattern Type Behavior
      ├─ FrameworkDetector
      ├─ TechnologyDetector
      └─ ServiceArchitectureDetector
```

### Pattern Storage
- **Patterns Table**: `instance_patterns` (ID, codebase_path, pattern_type, data)
- **Consensus**: `pattern_consensus` (aggregated across instances)
- **Cache**: `pattern_cache.ex` (in-memory caching with TTL)

---

## 7. Key Interdependencies

### Agent ↔ Evolution
```
Agent (state, metrics)
  → triggers evolution via Execution.Evolution.evolve_agent/1
  → A/B test in Genesis
  → feedback → update agent behavior
```

### Singularity ↔ Genesis
```
SelfImprovingAgent (singularity)
  → generates rule proposals
  → publishes to quantum_flow_workflow_consumer
  → Genesis.JobExecutor (isolated trial)
  → returns trial_results
  → Singularity applies or rejects
```

### Singularity ↔ CentralCloud
```
Local Learning (singularity)
  → detected patterns
  → publishes to intelligence_code_patterns_learned queue
  → CentralCloud.IntelligenceHub aggregates
  → returns consensus patterns
  → Singularity learns from consensus
```

### Pattern Flow
```
Agent Detection (DetectionOrchestrator)
  → PatternStore (local)
  → replicate to central_services
  → CentralCloud processes
  → consensus computed
  → replicate back to Singularity
  → agent training continues
```

---

## 8. Where New Modules Need to be Added

### For Central Evolution Refactor

#### 1. EvolutionOrchestrator (nexus/singularity/lib/singularity/evolution/)
- Replace scattered evolution logic
- Unify all evolution types (patterns, models, cache, health)
- Support multi-strategy evolution coordination

#### 2. EvolutionProposalManager (nexus/genesis/lib/genesis/evolution/)
- Manage evolution proposals from all instances
- Track voting & consensus
- Route to JobExecutor for trials

#### 3. EvolutionCoordinator (nexus/central_services/lib/centralcloud/evolution/)
- CentralCloud-side evolution coordination
- Aggregate trial results across instances
- Compute global consensus on rule changes

#### 4. EvolutionMetrics (new schema in singularity/lib/singularity/schemas/execution/)
- Track evolution attempts (proposed, approved, rejected)
- Store trial results with detailed metrics
- Measure evolution effectiveness

#### 5. EvolutionHistory (new schema)
- Immutable audit log of all evolution changes
- Enables rollback & analysis
- Tracks who/what/when/why for each evolution

#### 6. EvolutionDecisionTree (new executor)
- Rules for when to attempt evolutions
- Precondition evaluation
- Post-evolution validation

---

## 9. Current Orchestrator Pattern (Reusable Template)

All major systems use same config-driven orchestration:

```
Behavior Contract (@behaviour XyzType)
    ↓
Config (config.exs)
    ├─ :pattern_types
    ├─ :analyzer_types
    ├─ :scanner_types
    ├─ :generator_types
    └─ :execution_strategies
    ↓
Orchestrator (XyzOrchestrator)
    ├─ discover implementations
    ├─ load enabled configs
    ├─ route to implementations
    └─ aggregate results
    ↓
Concrete Types (FrameworkDetector, TechnologyDetector, etc.)
```

**Fully extensible without code changes** - just add to config.

---

## 10. File Locations Summary

| Component | Location | Key Files |
|-----------|----------|-----------|
| **Singularity Core** | `nexus/singularity/lib/singularity/` | 66 directories, 77 schemas |
| **Genesis** | `nexus/genesis/lib/genesis/` | 17 modules, 3 schemas |
| **CentralCloud** | `nexus/central_services/lib/centralcloud/` | 13 modules, 8 schemas |
| **Agents** | `nexus/singularity/lib/singularity/agents/` | 24 agent implementations |
| **Execution** | `nexus/singularity/lib/singularity/execution/` | Evolution, TaskGraph, Orchestrators |
| **Analysis** | `nexus/singularity/lib/singularity/analysis/` | DetectionOrchestrator, PatternDetector |
| **Architecture** | `nexus/singularity/lib/singularity/architecture_engine/` | Pattern detectors & stores |
| **Database** | `nexus/*/priv/repo/migrations/` | 50+ migrations |

---

## 11. Current Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    SINGULARITY CORE                         │
│  (nexus/singularity/ - 5 execution phases, 39 components)   │
├─────────────────────────────────────────────────────────────┤
│ Agents (24 types)                                           │
│  ├─ SelfImprovingAgent (main)                              │
│  ├─ CostOptimizedAgent                                      │
│  └─ [RemediationEngine, QualityEnforcer, etc.]             │
│                                                              │
│ Execution Layer                                             │
│  ├─ ExecutionOrchestrator (strategy routing)               │
│  ├─ Evolution.ex (A/B testing framework)                    │
│  └─ TaskGraphExecutor (DAG-based execution)                │
│                                                              │
│ Analysis Layer                                              │
│  ├─ DetectionOrchestrator (unified pattern detection)      │
│  ├─ PatternDetector (config-driven)                        │
│  └─ Architecture Engine (framework/tech/service detectors) │
│                                                              │
│ Knowledge & Metrics                                         │
│  ├─ Metrics.Aggregator                                      │
│  ├─ Knowledge.ArtifactStore                                 │
│  └─ Semantic Code Search (pgvector)                         │
└────────────────────────┬────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
        ↓                ↓                ↓
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│    GENESIS       │ │  CENTRALCLOUD    │ │     DATABASE     │
│ (nexus/genesis/) │ │ (central_services)│ │  PostgreSQL 17   │
├──────────────────┤ ├──────────────────┤ ├──────────────────┤
│ Autonomy Hub     │ │ Intelligence Hub  │ │ singularity DB   │
│ ├─ JobExecutor   │ │ ├─ Framework     │ │ ├─ 77 schemas    │
│ ├─ RuleEngine    │ │ │   Learning     │ │ ├─ pgvector      │
│ └─ Isolation Mgr │ │ ├─ Infra         │ │ └─ pgmq queues   │
│                  │ │ │   Learning     │ │                  │
│ Rule Evolution   │ │ ├─ Template      │ │ central_services │
│ ├─ Proposals     │ │ │   Service      │ │ ├─ 8 schemas     │
│ ├─ Voting        │ │ └─ Queue Manager │ │ └─ Replicas      │
│ └─ Rollback      │ │                  │ │                  │
└──────────────────┘ └──────────────────┘ └──────────────────┘
        ↑                      ↑                      ↑
        └──────────────────────┼──────────────────────┘
                      pgmq/quantum_flow/NATS
         (Durable inter-service communication)
```

---

## 12. Reusable Patterns

### Pattern 1: Config-Driven Orchestrator
```elixir
# Behavior contract
@behaviour EvolutionType

# In config/config.exs
config :singularity, :evolution_types,
  pattern_enhancement: %{module: PatternEnhancementEvolver, enabled: true},
  model_optimization: %{module: ModelOptimizer, enabled: true},
  # Add new evolution types without changing orchestrator code
```

### Pattern 2: Isolated Trial Execution
```
Genesis.JobExecutor.execute_trial(evolution_proposal)
  → creates isolated sandbox
  → runs trial_fn inside isolation
  → measures metrics
  → returns trial_results
  → parent decides rollback/commit
```

### Pattern 3: Consensus-Based Governance
```
RuleEvolutionProposal
  → votes from 3+ agents
  → confidence threshold 0.85+
  → trial_results validation
  → auto-apply if consensus met
```

### Pattern 4: Multi-Instance Learning
```
Local learning (Singularity instance)
  → publish patterns to pgmq
  → CentralCloud.IntelligenceHub aggregates
  → compute consensus across instances
  → replicate back (pgvector embeddings)
  → local instance learns from consensus
```

---

## Next Steps for Refactor

1. **Create EvolutionOrchestrator** - Unify evolution logic
2. **Implement EvolutionMetrics schema** - Track all evolution attempts
3. **Build EvolutionDecisionTree** - Rules for triggering evolution
4. **Set up EvolutionCoordinator in CentralCloud** - Multi-instance coordination
5. **Create EvolutionHistory** - Immutable audit trail
6. **Implement EvolutionProposalManager in Genesis** - Proposal lifecycle
7. **Add evolution observability** - Dashboards in Observer

