# Central Evolution System - Complete File Index

## Documentation Files

- **CENTRAL_EVOLUTION_ARCHITECTURE.md** (19KB) - Comprehensive architecture exploration
  - Executive summary
  - Component structure (Singularity, Genesis, CentralCloud)
  - Database schema details
  - Evolution orchestrator patterns
  - Agent implementations
  - Interdependencies & data flow
  - Where to add new modules
  - Next steps for refactor

- **CENTRAL_EVOLUTION_QUICK_REFERENCE.md** (11KB) - Quick lookup guide
  - Three-component overview
  - Key file locations
  - API reference
  - Database tables
  - Configuration examples
  - Evolution workflow steps
  - Monitoring & debugging
  - Common operations
  - Troubleshooting

---

## Singularity Core Files

### Location: `/home/mhugo/code/singularity/nexus/singularity/`

#### Agents (24 implementations)
```
lib/singularity/agents/
├─ agent.ex (32KB) - Core GenServer for agent instance ★
├─ self_improving_agent.ex (53KB) - Main self-improving agent ★
├─ cost_optimized_agent.ex (17KB) - Cost optimization focus
├─ remediation_engine.ex (17KB) - Error remediation
├─ quality_enforcer.ex (15KB) - Quality metrics enforcement
├─ dead_code_monitor.ex (19KB) - Dead code detection
├─ schema_generator.ex (9KB) - Database schema generation
├─ documentation_pipeline.ex (17KB) - Documentation generation
├─ self_improvement_agent.ex (4KB) - Agent self-evolution
├─ real_workload_feeder.ex (7KB) - Workload generation
├─ arbiter.ex (8KB) - Conflict resolution
├─ agent_spawner.ex (4KB) - Dynamic agent creation
├─ agent_supervisor.ex (3KB) - Agent supervision
├─ agent_performance_dashboard.ex (14KB)
├─ metrics_feeder.ex (3KB) - Synthetic metrics
├─ template_performance.ex (18KB) - Template performance tracking
└─ coordination/ - Multi-agent workflows
```

#### Execution Layer
```
lib/singularity/execution/
├─ evolution.ex (17KB) - Agent evolution & A/B testing ★★★
├─ orchestrator/
│  ├─ execution_orchestrator.ex (7KB) - Strategy routing
│  ├─ execution_strategy_orchestrator.ex (5KB) - Strategy selection
│  └─ execution_strategy.ex (4KB) - Strategy definition
├─ task_graph.ex (23KB)
├─ task_graph_engine.ex (27KB)
├─ task_graph_executor.ex (20KB)
├─ safe_work_planner.ex (39KB)
├─ story_decomposer.ex (20KB)
├─ file_analysis_swarm_coordinator.ex (12KB)
└─ schemas/
   ├─ execution_record.ex - Execution history
   ├─ task.ex - Task definition
   ├─ rule.ex - Evolvable rules ★
   ├─ rule_evolution_proposal.ex - Rule proposals ★
   └─ [7 more execution schemas]
```

#### Analysis Layer
```
lib/singularity/analysis/
├─ detection_orchestrator.ex (14KB) - Unified detection ★★
├─ pattern_detector.ex (8KB) - Config-driven patterns
├─ detectors/ - Pattern detectors
│  ├─ framework_detector.ex
│  ├─ technology_detector.ex
│  └─ service_architecture_detector.ex
├─ extractors/
│  └─ pattern_extractor.ex
├─ metadata_validator.ex (15KB)
├─ codebase_health_tracker.ex (16KB)
└─ [4 more analysis modules]
```

#### Architecture Engine
```
lib/singularity/architecture_engine/
├─ pattern_detector.ex (8KB)
├─ pattern_type.ex (5KB) - Behavior contract
├─ pattern_store.ex (16KB) - Pattern persistence
├─ framework_pattern_store.ex (10KB)
├─ technology_pattern_store.ex (19KB)
├─ framework_pattern_sync.ex (6KB)
├─ infrastructure_detection_orchestrator.ex (5KB)
├─ infrastructure_registry_cache.ex (15KB)
└─ detectors/
   ├─ framework_detector.ex
   ├─ technology_detector.ex
   └─ service_architecture_detector.ex
```

#### Metrics & Monitoring
```
lib/singularity/metrics/
├─ aggregator.ex (11KB) - Agent metrics aggregation ★
├─ orchestrator.ex (9KB)
├─ code_metrics.ex (5KB)
├─ enrichment.ex (11KB)
├─ event_collector.ex (6KB)
├─ nif.ex (6KB)
└─ README.md - Metrics documentation
```

#### Database Schemas (77 total)
```
lib/singularity/schemas/
├─ execution/
│  ├─ execution_record.ex - All executions
│  ├─ task.ex - Task definitions
│  ├─ rule.ex - Evolvable rules ★
│  ├─ rule_evolution_proposal.ex - Rule proposals ★
│  ├─ rule_execution.ex
│  ├─ task_execution_strategy.ex
│  └─ todo.ex
├─ agent_metric.ex - Agent metrics
├─ approval_queue.ex
├─ approved_pattern.ex
├─ code_analysis_result.ex
├─ code_chunk.ex - Code storage (pgvector)
├─ code_embedding_cache.ex
├─ code_file.ex
├─ code_location_index.ex
├─ codebase_metadata.ex
├─ codebase_registry.ex
├─ codebase_snapshot.ex - Codebase state snapshots
├─ dead_code_history.ex
├─ dependency_catalog.ex
├─ failure_pattern.ex - Common failures
├─ file_architecture_pattern.ex
├─ graph_edge.ex
├─ graph_node.ex
├─ graph_type.ex
├─ instance_pattern.ex - Local patterns ★
├─ knowledge_artifact.ex - Unified artifacts ★
├─ knowledge_request.ex
├─ language_detection_confidence.ex
├─ local_learning.ex - Instance learning
├─ pattern_cache.ex
├─ pattern_consensus.ex - Multi-instance consensus ★
├─ technology_detection.ex
├─ technology_pattern.ex - Tech patterns
├─ template.ex
├─ template_cache.ex
├─ validation_metric.ex
├─ vector_search.ex
├─ vector_similarity_cache.ex
└─ [31 more schemas]
```

#### Migrations (50+)
```
priv/repo/migrations/
├─ 20240101000001_enable_extensions.exs - pgvector, pg_uuidv7
├─ 20240101000002_create_core_tables.exs
├─ 20240101000003_create_knowledge_tables.exs
├─ 20240101000004_create_code_analysis_tables.exs
├─ 20240101000005_create_git_and_cache_tables.exs
├─ 20240101000006_create_package_registry_tables.exs
├─ 20240101000014_align_schema_table_names.exs
├─ 20240101000015_consolidate_unified_schema.exs
├─ 20250101000009_create_autonomy_tables.exs
├─ 20250101000019_create_technology_detection_tables.exs
├─ 20250101000020_create_code_search_tables.exs
├─ 20251026120002_create_execution_metrics.exs
├─ 20251026120000_create_failure_patterns.exs
├─ 20251027120000_create_execution_outcomes.exs
├─ 20251007004000_create_agent_flow_tracking_tables.exs
└─ [35 more migrations]
```

---

## Genesis Files

### Location: `/home/mhugo/code/singularity/nexus/genesis/`

#### Core Modules (17 files)
```
lib/genesis/
├─ application.ex (4KB) - OTP supervisor
├─ job_executor.ex (9KB) - Trial execution in isolation ★
├─ llm_config_manager.ex (8KB)
├─ rule_engine.ex (5KB) - Rule evaluation ★
├─ pgflow_workflow_consumer.ex (18KB) - Evolution workflows
├─ shared_queue_consumer.ex (9KB) - pgmq messages
├─ isolation_manager.ex (4KB) - Sandbox management
├─ rollback_manager.ex (7KB) - Failed evolution rollback
├─ sandbox_maintenance.ex (7KB)
├─ scheduler.ex (7KB)
├─ experiment_runner.ex
├─ analysis.ex
├─ cleanup.ex
├─ jobs.ex
├─ reporting.ex
├─ structured_logger.ex (6KB)
└─ database/
```

#### Schemas (3 files)
```
lib/genesis/schemas/
├─ experiment_record.ex - Trial executions
├─ experiment_metrics.ex - Trial results
└─ sandbox_history.ex - Isolation tracking
```

#### Migrations (8)
```
priv/repo/migrations/
├─ 20250101000001_create_experiment_records.exs
├─ 20250101000002_create_experiment_metrics.exs
├─ 20250101000003_create_sandbox_history.exs
├─ 20251025120000_create_execution_metrics_replica.exs
└─ [4 more]
```

---

## CentralCloud Files

### Location: `/home/mhugo/code/singularity/nexus/central_services/lib/centralcloud/`

#### Core Modules (13 modules)
```
lib/centralcloud/
├─ application.ex (5KB) - OTP supervisor
├─ intelligence_hub.ex (54KB) - Pattern aggregation ★★★
├─ intelligence_hub_subscriber.ex (11KB)
├─ framework_learning_agent.ex (10KB) - Framework learning
├─ framework_learning_orchestrator.ex (9KB)
├─ framework_learner.ex (7KB)
├─ infrastructure_system_learning_orchestrator.ex (6KB)
├─ infrastructure_system_learner.ex (3KB)
├─ llm_team_orchestrator.ex (4KB)
├─ knowledge_cache.ex (4KB) - Cross-instance cache
├─ template_service.ex (17KB) - Template lifecycle
├─ shared_queue_manager.ex (9KB) - Message routing
├─ template_loader.ex (6KB)
├─ prompt_management.ex (7KB)
├─ pattern_importer.ex
├─ pattern_validation.ex
└─ workflow/ - Learning workflows
```

#### Schemas (8 files)
```
lib/centralcloud/schemas/
├─ analysis_result.ex
├─ code_snippet.ex
├─ infrastructure_system.ex
├─ package.ex
├─ package_example.ex
├─ prompt_template.ex - Templates with embeddings
├─ security_advisory.ex
└─ template.ex
```

#### Migrations (20)
```
priv/repo/migrations/
├─ 20250109000001_create_central_services_database.exs (24KB)
├─ 20250130000002_create_templates_table.exs (2KB)
├─ 20251023212305_create_architecture_patterns.exs
├─ 20251025000001_enable_pg_cron.exs
├─ 20251025000002_create_approved_patterns_table.exs
├─ 20251025000003_create_performance_metrics_table.exs
└─ [14 more]
```

---

## Supporting Infrastructure

### Messaging & Queues
```
pgmq queues (PostgreSQL message queues):
├─ intelligence_code_patterns_learned
├─ intelligence_architecture_patterns_learned
├─ intelligence_data_schemas_learned
├─ intelligence_insights_query
├─ intelligence_quality_aggregate
├─ pgflow_workflow_consumer
└─ [shared_queue_*, others]
```

### Package Locations
```
packages/
├─ ex_pgflow/ - pgflow workflow orchestration
├─ ex_llm/ - LLM provider abstraction
├─ code_quality_engine/ - Rust NIF (quality metrics)
├─ linting_engine/ - Rust NIF (multi-language linting)
├─ parser_engine/ - Rust NIF (tree-sitter parsing)
├─ prompt_engine/ - Rust NIF (prompt generation)
└─ [more engines]
```

### Observer (UI)
```
observer/
├─ lib/observer/ - Phoenix application
├─ lib/observer_web/ - Web interface
├─ Port: 4002
└─ Provides:
   ├─ Agent performance dashboards
   ├─ Evolution tracking
   ├─ Pattern intelligence views
   └─ System metrics
```

---

## Key Tables by Purpose

### Evolution & Governance
| Table | Location | Purpose |
|-------|----------|---------|
| `rule_evolution_proposals` | singularity | Evolution proposals with voting |
| `execution_records` | singularity | All executions (tasks, workflows) |
| `execution_metrics` | singularity | Execution performance metrics |
| `execution_outcomes` | singularity | Success/failure outcomes |
| `experiment_records` | singularity | Trial executions in Genesis |
| `experiment_metrics` | singularity | Trial results & measurements |

### Pattern & Knowledge
| Table | Location | Purpose |
|-------|----------|---------|
| `instance_patterns` | singularity | Local detected patterns |
| `pattern_consensus` | singularity | Multi-instance consensus scores |
| `knowledge_artifacts` | singularity | Unified artifact store |
| `technology_patterns` | singularity | Tech stack patterns |
| `approved_patterns` | singularity | High-confidence patterns |
| `prompt_templates` | central_services | Cross-instance templates |

### Agent & Quality
| Table | Location | Purpose |
|-------|----------|---------|
| `agent_metrics` | singularity | Agent performance metrics |
| `local_learning` | singularity | Instance-specific learning |
| `failure_patterns` | singularity | Common failure signatures |
| `validation_metrics` | singularity | Quality validation results |

### Code & Search
| Table | Location | Purpose |
|-------|----------|---------|
| `code_chunks` | singularity | Code storage (with pgvector) |
| `code_embedding_cache` | singularity | Embedding cache |
| `code_location_index` | singularity | Location lookup |
| `vector_similarity_cache` | singularity | Search cache |

---

## Architecture Patterns Used

### Pattern 1: Config-Driven Orchestrator
Used in:
- PatternDetector → PatternType behavior
- AnalysisOrchestrator → AnalyzerType behavior
- ScanOrchestrator → ScannerType behavior
- GenerationOrchestrator → GeneratorType behavior
- ExecutionOrchestrator → ExecutionStrategy behavior

**Template:**
```
Behavior (@behaviour)
    ↓
Config (config.exs)
    ↓
Orchestrator (discovery & routing)
    ↓
Implementations
```

### Pattern 2: Isolated Trial Execution
Used in:
- Genesis.JobExecutor (rule evolution trials)
- Singularity.Execution.Evolution (A/B testing)

**Template:**
```
IsolationManager.create_sandbox()
    ↓
JobExecutor.execute_trial(fn_or_code)
    ↓
Measure metrics in isolation
    ↓
Compare baseline vs trial
    ↓
Decide: apply or rollback
```

### Pattern 3: Consensus-Based Governance
Used in:
- RuleEvolutionProposal (voting on evolution)
- PatternConsensus (multi-instance patterns)

**Requirements:**
- 3+ agents
- 85%+ confidence threshold
- Trial results validation

### Pattern 4: Multi-Instance Learning
Used in:
- IntelligenceHub aggregation
- Pattern replication (logical replication)
- Consensus computation

**Flow:**
```
Local detection
    ↓
Publish to pgmq
    ↓
CentralCloud aggregates
    ↓
Compute consensus
    ↓
Replicate back
    ↓
All instances learn
```

---

## How to Find Things

### Finding Specific Module
```bash
# Search by name
grep -r "class FileAnalysisSwarmCoordinator" /home/mhugo/code/singularity/nexus/

# By responsibility
grep -r "def evolve_agent" /home/mhugo/code/singularity/nexus/singularity/lib/
# Found: singularity/lib/singularity/execution/evolution.ex

# By pattern type
grep -r "DetectionOrchestrator" /home/mhugo/code/singularity/nexus/
# Found: singularity/lib/singularity/analysis/detection_orchestrator.ex
```

### Finding Database Schema
```bash
# Find schema files
find /home/mhugo/code/singularity/nexus/singularity/lib/singularity/schemas -name "*.ex" | grep rule

# Find migrations
ls /home/mhugo/code/singularity/nexus/singularity/priv/repo/migrations/ | grep 007
```

### Finding Evolution Code
```bash
# All evolution-related code
grep -r "evolve\|evolution\|Evolution" /home/mhugo/code/singularity/nexus/singularity/lib \
  --include="*.ex" | grep -v ".exs" | head -20
```

---

## Development Checklist

When building Evolution Orchestrator refactor:

- [ ] Read CENTRAL_EVOLUTION_ARCHITECTURE.md
- [ ] Review Singularity.Execution.Evolution (evolution.ex)
- [ ] Review Genesis.JobExecutor (job_executor.ex)
- [ ] Review CentralCloud.IntelligenceHub (intelligence_hub.ex)
- [ ] Check rule_evolution_proposal schema
- [ ] Check agent.ex for metric reporting
- [ ] Review metrics/aggregator.ex
- [ ] Check detection_orchestrator.ex pattern
- [ ] Review execution_orchestrator.ex pattern
- [ ] Plan new schema: EvolutionMetrics
- [ ] Plan new module: EvolutionOrchestrator
- [ ] Plan new module: EvolutionCoordinator (in CentralCloud)
- [ ] Design EvolutionHistory schema
- [ ] Create test cases
- [ ] Update Observer dashboards
- [ ] Create documentation

---

## Useful SQL Queries

### Check Evolution Activity
```sql
SELECT id, agent_id, status, proposed_patterns, consensus_reached, created_at
FROM rule_evolution_proposals
WHERE created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

### View Agent Metrics
```sql
SELECT agent_id, COUNT(*) as execution_count, AVG(success_rate) as avg_success
FROM agent_metrics
GROUP BY agent_id
ORDER BY execution_count DESC;
```

### Check Pattern Consensus
```sql
SELECT pattern_type, confidence_score, instance_count
FROM pattern_consensus
WHERE confidence_score > 0.85
ORDER BY confidence_score DESC;
```

### View Trial Results
```sql
SELECT proposal_id, trial_results, trial_confidence
FROM rule_evolution_proposals
WHERE trial_results IS NOT NULL
ORDER BY created_at DESC LIMIT 10;
```

---

## Related Documentation

See also:
- `/home/mhugo/code/singularity/CLAUDE.md` - Project overview
- `/home/mhugo/code/singularity/AGENTS.md` - Agent system documentation
- `/home/mhugo/code/singularity/SYSTEM_STATE_OCTOBER_2025.md` - System status
- `/home/mhugo/code/singularity/FINAL_PLAN.md` - Architecture plan
