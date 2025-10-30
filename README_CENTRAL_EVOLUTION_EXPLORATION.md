# Central Evolution System - Codebase Exploration Results

**Date**: October 30, 2025  
**Thoroughness**: Medium (structural understanding, not exhaustive)  
**Status**: Complete - 3 comprehensive documents created

## Quick Start

Start with **CENTRAL_EVOLUTION_ARCHITECTURE.md** for a complete understanding of the system.

For quick lookups, use **CENTRAL_EVOLUTION_QUICK_REFERENCE.md**.

To find specific files, use **CENTRAL_EVOLUTION_INDEX.md**.

---

## The Three Documents

### 1. CENTRAL_EVOLUTION_ARCHITECTURE.md
**For**: Deep architecture understanding  
**Size**: 517 lines, 19KB  
**Topics**:
- Executive summary of 3-component system
- CentralCloud structure & services
- Genesis autonomy hub details
- Current evolution orchestrator implementation
- Agent implementations (24 types)
- Complete database structure
- Pattern detection system
- Key interdependencies
- Where to add new modules
- Reusable patterns
- Architecture diagrams

**Start here** if you need to understand how all pieces fit together.

### 2. CENTRAL_EVOLUTION_QUICK_REFERENCE.md
**For**: Day-to-day development & troubleshooting  
**Size**: 419 lines, 11KB  
**Topics**:
- Three-component system overview
- Key file locations & API endpoints
- Quick API reference (agent, pattern, evolution operations)
- Database tables by purpose
- Configuration examples
- Evolution workflow (6 steps)
- Monitoring & debugging checklist
- Common operations
- Testing examples
- Troubleshooting guide

**Use this** when you need quick answers or API reference.

### 3. CENTRAL_EVOLUTION_INDEX.md
**For**: File navigation & reference  
**Size**: 541 lines, 16KB  
**Topics**:
- Complete file listing
- 24 agent implementations (with file sizes)
- Execution layer (17 files)
- Analysis layer (detectors, patterns)
- 77 database schemas (organized by purpose)
- 50+ migrations (organized by type)
- Genesis modules (17 files with descriptions)
- CentralCloud modules (13 files with descriptions)
- Supporting infrastructure (messaging, packages)
- Key tables by purpose (4 categories)
- Architecture patterns (4 reusable templates)
- Development checklist
- Useful SQL queries

**Use this** when you need to find a specific file or understand the complete structure.

---

## Key Findings Summary

### System Structure
```
Singularity (Core)          Genesis (Autonomy)         CentralCloud (Intelligence)
├─ 24 agents                ├─ JobExecutor              ├─ IntelligenceHub
├─ Evolution.ex             ├─ RuleEngine               ├─ Framework Learning
├─ Pattern Detection        ├─ Isolation Manager        ├─ Template Service
├─ Execution Orchestrator   ├─ Rollback Manager         ├─ Queue Manager
├─ 77 schemas               ├─ 3 schemas                ├─ 8 schemas
└─ 50+ migrations           └─ 8 migrations             └─ 20 migrations

     ↕ pgmq/QuantumFlow/NATS
  (Durable inter-service communication)
```

### What Each Component Does
- **Singularity**: Core execution, local learning, agent management
- **Genesis**: Isolated trial execution, rule evolution, safety management
- **CentralCloud**: Pattern aggregation, consensus computation, multi-instance learning

All three are **REQUIRED** for full system functionality.

### Evolution System (Current)
- **Code**: `singularity/lib/singularity/execution/evolution.ex` (17KB)
- **Types**: Pattern enhancement, model optimization, cache improvement, CodeEngine health
- **Process**: Detect degradation → Propose evolution → Genesis trial → Consensus → Apply
- **Governance**: 3+ agents, 85%+ confidence threshold, trial validation

### Database Structure
**Singularity DB**: 77 schemas tracking execution, patterns, agents, code, analysis  
**Central_Services DB**: 8 schemas for aggregation, learning, templates  
**Key Tables**:
- `rule_evolution_proposals` - Evolution proposals with voting
- `instance_patterns` - Local patterns
- `pattern_consensus` - Multi-instance consensus
- `agent_metrics` - Performance metrics
- `experiment_records` / `experiment_metrics` - Trial results

### Orchestrator Pattern (Reusable)
All major systems use same config-driven pattern:
```
@behaviour XyzType
    ↓ (in config.exs)
    ↓ (via XyzOrchestrator)
    ↓
Concrete implementations
```

Examples: DetectionOrchestrator, ExecutionOrchestrator, AnalysisOrchestrator

---

## For the Refactor Team

### What Can Be Reused
1. **DetectionOrchestrator pattern** - Unified orchestration template
2. **ExecutionOrchestrator pattern** - Strategy routing
3. **Genesis.JobExecutor** - Isolated trial execution
4. **RuleEvolutionProposal schema** - Voting & governance
5. **Metrics.Aggregator** - Metrics collection framework
6. **IntelligenceHub** - Multi-instance aggregation
7. **SharedQueueManager** - Message routing
8. **Pattern stores** - Persistence pattern

### What to Build
1. **EvolutionOrchestrator** - Unify scattered evolution logic
2. **EvolutionMetrics schema** - Track all evolution attempts
3. **EvolutionCoordinator** (in CentralCloud) - Multi-instance coordination
4. **EvolutionHistory schema** - Immutable audit trail
5. **EvolutionDecisionTree** - Rules for triggering evolution
6. **EvolutionProposalManager** (in Genesis) - Proposal lifecycle

### Where to Add Modules
```
singularity/lib/singularity/evolution/
    ├─ evolution_orchestrator.ex (new)
    ├─ evolution_decision_tree.ex (new)
    └─ schemas/
        ├─ evolution_metrics.ex (new)
        └─ evolution_history.ex (new)

genesis/lib/genesis/evolution/
    └─ evolution_proposal_manager.ex (new)

central_services/lib/centralcloud/evolution/
    └─ evolution_coordinator.ex (new)
```

---

## How to Use These Documents

### Scenario 1: "I need to understand the architecture"
→ Read **CENTRAL_EVOLUTION_ARCHITECTURE.md** sections 1-3

### Scenario 2: "Where is the evolution code?"
→ Look in **CENTRAL_EVOLUTION_INDEX.md** section "Singularity Core Files" → "Execution Layer"

### Scenario 3: "How do I test agent evolution?"
→ Check **CENTRAL_EVOLUTION_QUICK_REFERENCE.md** section "Testing Evolution"

### Scenario 4: "What tables store evolution data?"
→ Check **CENTRAL_EVOLUTION_QUICK_REFERENCE.md** section "Database Tables for Evolution"

### Scenario 5: "I need to add a new orchestrator pattern"
→ Read **CENTRAL_EVOLUTION_ARCHITECTURE.md** section "Current Orchestrator Pattern"

### Scenario 6: "The agent is not evolving - debug it"
→ See **CENTRAL_EVOLUTION_QUICK_REFERENCE.md** section "Troubleshooting"

### Scenario 7: "Show me all the files in Genesis"
→ See **CENTRAL_EVOLUTION_INDEX.md** section "Genesis Files"

---

## Key Statistics

| Component | Files | Size | Location |
|-----------|-------|------|----------|
| Singularity Agents | 24 | 300KB | `singularity/lib/singularity/agents/` |
| Singularity Execution | 17 | 380KB | `singularity/lib/singularity/execution/` |
| Singularity Schemas | 77 | 800KB | `singularity/lib/singularity/schemas/` |
| Genesis Core | 17 | 150KB | `genesis/lib/genesis/` |
| CentralCloud | 13 | 200KB | `central_services/lib/centralcloud/` |
| Total Documentation | 3 | 46KB | Repository root |

---

## File Locations

```
/home/mhugo/code/singularity/

Documentation (Created):
├── CENTRAL_EVOLUTION_ARCHITECTURE.md (19KB)
├── CENTRAL_EVOLUTION_QUICK_REFERENCE.md (11KB)
├── CENTRAL_EVOLUTION_INDEX.md (16KB)
└── README_CENTRAL_EVOLUTION_EXPLORATION.md (this file)

Source Code:
├── nexus/singularity/
│   ├── lib/singularity/agents/ (24 agent types)
│   ├── lib/singularity/execution/ (evolution, orchestrators, task graphs)
│   ├── lib/singularity/analysis/ (detection, pattern detection)
│   ├── lib/singularity/metrics/ (aggregation, collection)
│   ├── lib/singularity/schemas/ (77 schemas)
│   └── priv/repo/migrations/ (50+ migrations)
├── nexus/genesis/
│   ├── lib/genesis/ (17 modules, autonomy hub)
│   ├── lib/genesis/schemas/ (3 schemas)
│   └── priv/repo/migrations/ (8 migrations)
└── nexus/central_services/lib/centralcloud/
    ├── intelligence_hub.ex (54KB, pattern aggregation)
    ├── lib/centralcloud/schemas/ (8 schemas)
    └── priv/repo/migrations/ (20 migrations)
```

---

## Next Steps

### For Understanding
1. Read CENTRAL_EVOLUTION_ARCHITECTURE.md (30 min)
2. Skim CENTRAL_EVOLUTION_INDEX.md (15 min)
3. Keep CENTRAL_EVOLUTION_QUICK_REFERENCE.md bookmarked

### For Implementation
1. Review current evolution code (singularity/lib/singularity/execution/evolution.ex)
2. Review Genesis trial execution (genesis/lib/genesis/job_executor.ex)
3. Review CentralCloud aggregation (central_services/lib/centralcloud/intelligence_hub.ex)
4. Design new orchestrator structure
5. Implement EvolutionOrchestrator & supporting schemas
6. Add integration tests
7. Update Observer dashboards
8. Document with AI metadata

---

## Related Documentation

- `CLAUDE.md` - Project overview & guidelines
- `AGENTS.md` - Agent system documentation
- `SYSTEM_STATE_OCTOBER_2025.md` - Current system status
- `FINAL_PLAN.md` - Architecture planning

---

## Questions?

Refer to the appropriate document:

- **Architecture questions** → CENTRAL_EVOLUTION_ARCHITECTURE.md
- **API/usage questions** → CENTRAL_EVOLUTION_QUICK_REFERENCE.md
- **File/location questions** → CENTRAL_EVOLUTION_INDEX.md
- **Debug/troubleshoot** → CENTRAL_EVOLUTION_QUICK_REFERENCE.md section "Troubleshooting"

---

**Created**: October 30, 2025  
**Status**: Ready for implementation  
**Total Lines**: 1,477  
**Total Size**: 46KB
