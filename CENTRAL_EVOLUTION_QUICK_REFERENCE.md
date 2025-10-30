# Central Evolution System - Quick Reference Guide

## Three-Component System

### 1. Singularity Core (`nexus/singularity/`)
- **Main application** with 5 execution phases
- **Agents**: 24 types (SelfImprovingAgent, CostOptimizedAgent, etc.)
- **Analysis**: DetectionOrchestrator, PatternDetector
- **Execution**: ExecutionOrchestrator, Evolution.ex
- **Database**: singularity DB (77 schemas, 50+ migrations)
- **Port**: 4000

### 2. Genesis (`nexus/genesis/`)
- **Autonomy hub** for rule evolution
- **JobExecutor**: Isolated trial execution
- **RuleEngine**: Rule evaluation during trials
- **Isolation**: Sandbox management
- **Database**: singularity DB (shared, 3 tables)
- **Communication**: pgflow_workflow_consumer

### 3. CentralCloud (`nexus/central_services/lib/centralcloud/`)
- **Intelligence aggregator** across instances
- **IntelligenceHub**: Pattern aggregation
- **FrameworkLearningAgent**: Cross-instance learning
- **TemplateService**: Template lifecycle
- **Database**: central_services DB (8 tables)
- **Port**: 4001

---

## Key Files Location

| Task | File | Size |
|------|------|------|
| **View evolution code** | `singularity/lib/singularity/execution/evolution.ex` | 17KB |
| **View current agents** | `singularity/lib/singularity/agents/agent.ex` | 32KB |
| **View pattern detection** | `singularity/lib/singularity/analysis/detection_orchestrator.ex` | 14KB |
| **View intelligence hub** | `central_services/lib/centralcloud/intelligence_hub.ex` | 54KB |
| **View metrics** | `singularity/lib/singularity/metrics/aggregator.ex` | 11KB |
| **View execution strategies** | `singularity/lib/singularity/execution/orchestrator/` | 3 files |

---

## Quick API Reference

### Agent Operations
```elixir
# Get agent status
Singularity.Agents.Agent.get_status(agent_id)

# Execute task
Singularity.Agents.Agent.execute_task(agent_id, task, context)

# Record outcome
Singularity.Agents.Agent.record_outcome(agent_id, :success)

# Get metrics
Singularity.Metrics.Aggregator.get_metrics_for(agent_id, :last_week)
```

### Pattern Detection
```elixir
# Detect patterns (unified API)
Singularity.Analysis.DetectionOrchestrator.detect("path/to/code")
  # => %{framework: [...], technology: [...], service_architecture: [...]}

# With intent matching
Singularity.Analysis.DetectionOrchestrator.detect_with_intent(
  "path/to/code",
  "Create pgmq consumer"
)

# With caching
Singularity.Analysis.DetectionOrchestrator.detect_and_cache(
  "path/to/code",
  snapshot_id: "v1"
)
```

### Evolution Operations
```elixir
# Evolve agent
Singularity.Execution.Evolution.evolve_agent(agent_id)

# Get evolution status
Singularity.Execution.Evolution.get_evolution_status(agent_id)

# Execute with strategy
Singularity.Execution.Orchestrator.ExecutionOrchestrator.execute(
  goal,
  strategy: :task_dag,
  timeout: 30000
)
```

### Metrics & Reporting
```elixir
# Get agent metrics
Singularity.Metrics.Aggregator.get_metrics_for(agent_id, :last_week)

# Get all metrics
Singularity.Metrics.Aggregator.get_all_agent_metrics()

# Record metric
Singularity.Metrics.Aggregator.handle_telemetry_event(
  [:singularity, :agent, :completed],
  measurements,
  metadata
)
```

---

## Database Tables for Evolution

### Singularity DB

**Control & Governance**
- `rule_evolution_proposals` - Proposed rule changes with voting
- `execution_records` - All execution attempts
- `execution_metrics` - Metrics for each execution

**Patterns & Knowledge**
- `instance_patterns` - Local detected patterns
- `pattern_consensus` - Multi-instance consensus
- `knowledge_artifacts` - Unified artifact store

**Agents & Autonomy**
- `agent_metrics` - Agent performance metrics
- `execution_outcomes` - Success/failure outcomes
- `failure_patterns` - Common failure signatures

**History & Audit**
- `local_learning` - Instance-specific learning
- `codebase_snapshots` - Codebase state at points in time

### Central_Services DB

**Aggregation**
- `prompt_templates` - Cross-instance templates
- `architecture_patterns` - Aggregated patterns
- `performance_metrics` - Consensus metrics

**Learning**
- `framework_learnings` - Framework pattern learnings
- `infrastructure_systems` - Infrastructure patterns

---

## Configuration Examples

### Enable New Evolution Type
```elixir
# config/config.exs
config :singularity, :evolution_types,
  pattern_enhancement: %{module: Singularity.Evolution.PatternEnhancer, enabled: true},
  model_optimization: %{module: Singularity.Evolution.ModelOptimizer, enabled: true},
  new_evolution_type: %{module: YourNewEvolver, enabled: true}
```

### Enable Pattern Detection
```elixir
config :singularity, :pattern_types,
  framework: %{module: FrameworkDetector, enabled: true},
  technology: %{module: TechnologyDetector, enabled: true},
  service_architecture: %{module: ServiceArchitectureDetector, enabled: true}
```

### Enable Execution Strategies
```elixir
config :singularity, :execution_strategies,
  task_dag: %{module: TaskGraphStrategy, enabled: true},
  sparc: %{module: SparcStrategy, enabled: true},
  methodology: %{module: MethodologyStrategy, enabled: true}
```

---

## Evolution Workflow

### 1. Agent Detects Degradation
```
SelfImprovingAgent
  ├─ success_rate < 90%?
  ├─ avg_latency > 2000ms?
  ├─ avg_cost > $0.10?
  └─ codeengine_health < 7.0?
      → triggers evolution
```

### 2. Evolution Proposed
```
Execution.Evolution.evolve_agent(agent_id)
  ├─ Select improvement strategy
  ├─ Create rule_evolution_proposal
  ├─ Publish to pgflow_workflow_consumer
  └─ Genesis picks up proposal
```

### 3. Trial Executed in Genesis
```
Genesis.JobExecutor.execute_trial(proposal)
  ├─ Create isolated sandbox
  ├─ Run variant code inside sandbox
  ├─ Measure trial_results
  └─ Compare with baseline
```

### 4. Results Aggregated
```
CentralCloud.IntelligenceHub.aggregate_trial_results(results)
  ├─ Collect results from all trials
  ├─ Compute consensus (3+ agents)
  ├─ Threshold validation (85%+ confidence)
  └─ Publish to intelligence_quality_aggregate
```

### 5. Decision Made
```
If consensus reached:
  → Auto-apply evolution
  → Update agent behavior
  → Log to evolution_history
Else if consensus not reached:
  → Archive proposal
  → Request more data
  → Retry later
```

### 6. Learning Recorded
```
Pattern learned from successful evolution:
  → Add to knowledge_artifacts
  → Generate embeddings (pgvector)
  → Replicate to CentralCloud
  → Other instances learn from consensus
```

---

## Monitoring & Debugging

### View Agent Performance
```
Observer Dashboard → http://localhost:4002
  → Agents tab
  → Select agent_id
  → View metrics, history, status
```

### Check Evolution Attempts
```sql
-- singularity DB
SELECT id, agent_id, status, proposed_patterns, consensus_reached, created_at
FROM rule_evolution_proposals
WHERE created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

### View Trial Results
```sql
-- singularity DB
SELECT proposal_id, trial_results, trial_confidence, status
FROM rule_evolution_proposals
WHERE trial_results IS NOT NULL;
```

### Check Consensus Scores
```sql
-- singularity DB
SELECT pattern_id, pattern_type, confidence_score, instance_count
FROM pattern_consensus
WHERE confidence_score > 0.85;
```

---

## Testing Evolution

### Test Pattern Detection
```elixir
iex> Singularity.Analysis.DetectionOrchestrator.detect("lib/")
{:ok, %{
  framework: [...],
  technology: [...],
  service_architecture: [...]
}}
```

### Test Agent Evolution
```elixir
iex> Singularity.Execution.Evolution.evolve_agent("test-agent")
{:ok, %{
  evolution_type: :pattern_enhancement,
  proposal_id: "...",
  status: :proposed
}}
```

### Test Metrics Reporting
```elixir
iex> Singularity.Metrics.Aggregator.get_metrics_for("test-agent", :last_week)
{:ok, %{
  success_rate: 0.87,
  avg_latency_ms: 1200.5,
  avg_cost_cents: 3.5,
  feedback_score: 4.2
}}
```

---

## Common Operations

### Start Complete System
```bash
cd /home/mhugo/code/singularity
./start-all.sh
# Starts: PostgreSQL, Singularity (4000), CentralCloud (4001), Observer (4002)
```

### Stop All Services
```bash
./stop-all.sh
```

### Run Migrations
```bash
cd nexus/singularity
mix ecto.migrate

cd ../central_services
mix ecto.migrate
```

### View Logs
```bash
# All services
tail -f logs/*.log

# Specific service
tail -f logs/singularity.log
tail -f logs/centralcloud.log
tail -f logs/genesis.log
```

### Reset Database
```bash
mix ecto.drop
mix ecto.create
mix ecto.migrate
```

---

## Key Metrics to Track

### Agent Metrics
- `success_rate` - % of tasks completed successfully
- `avg_latency_ms` - Average task execution time
- `avg_cost_cents` - Average cost per task (in cents)
- `feedback_score` - User satisfaction (1-5 scale)
- `cycles` - Number of evolution cycles executed

### Evolution Metrics
- `proposals_made` - Total evolution proposals
- `proposals_approved` - Approved by consensus
- `proposals_rejected` - Failed consensus
- `trials_executed` - Number of trial runs
- `avg_trial_duration_ms` - Time to evaluate proposal

### System Metrics
- `instance_count` - Number of active instances
- `consensus_score` - Average consensus confidence
- `pattern_count` - Known patterns across system
- `learning_rate` - New patterns learned per day

---

## Troubleshooting

### Agent Not Evolving
```
Check:
1. Agent status: Singularity.Agents.Agent.get_status(agent_id)
2. Metrics: Singularity.Metrics.Aggregator.get_metrics_for(agent_id, :last_day)
3. Proposals: SELECT * FROM rule_evolution_proposals WHERE agent_id = ?
4. Genesis: tail logs/genesis.log for JobExecutor errors
```

### Patterns Not Detected
```
Check:
1. Config enabled: config/config.exs :pattern_types
2. Detection: DetectionOrchestrator.detect("lib/")
3. Patterns table: SELECT * FROM instance_patterns WHERE codebase_path = ?
4. Logs: grep "PatternDetector\|DetectionOrchestrator" logs/*.log
```

### CentralCloud Not Aggregating
```
Check:
1. Connection: SELECT * FROM centralcloud_schemas.intelligence_hub_status
2. Queues: SELECT * FROM pgmq.q_intelligence_patterns
3. Replication: psql -c "SELECT * FROM pg_publication;"
4. Logs: tail logs/centralcloud.log
```

---

## Next Steps for Development

1. **Create EvolutionOrchestrator** - Consolidate evolution logic
2. **Add EvolutionMetrics schema** - Detailed evolution tracking
3. **Implement EvolutionCoordinator in CentralCloud** - Multi-instance coordination
4. **Build EvolutionHistory** - Immutable audit trail
5. **Add Observer dashboards** - Real-time evolution monitoring

See `CENTRAL_EVOLUTION_ARCHITECTURE.md` for detailed architecture.
