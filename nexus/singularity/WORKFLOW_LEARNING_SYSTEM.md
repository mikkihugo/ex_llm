# Workflow Learning System - Complete Implementation (October 2025)

## Overview

Singularity now has a complete end-to-end **workflow learning system** that automatically:
1. Analyzes workflow effectiveness from execution history
2. Synthesizes variations optimized for speed, quality, reliability, or cost
3. Publishes proven patterns to Genesis framework
4. Reports patterns to CentralCloud for multi-instance learning
5. Receives consensus patterns from CentralCloud
6. Registers consensus patterns locally for adoption

## Three-Layer Architecture

```
Layer 1: LOCAL LEARNING (Singularity Instance)
├─ GenesisWorkflowLearner
│  ├─ analyze_workflow_effectiveness() → patterns with confidence scores
│  ├─ synthesize_workflow_variations() → optimized variations
│  └─ publish_proven_workflows() → register locally (confidence 0.85+)
└─ WorkflowDispatcher (ETS-backed registry)

Layer 2: GENESIS PUBLICATION (Framework Learning)
├─ GenesisPublisher
│  └─ publish_workflow_pattern() → share patterns with Genesis framework
└─ Available to other Singularity instances via Genesis ecosystem

Layer 3: CENTRALCLOUD AGGREGATION (Cross-Instance Intelligence)
├─ GenesisWorkflowLearner
│  ├─ report_to_centralcloud() → send patterns (confidence 0.80+)
│  └─ request_consensus_from_centralcloud() → request aggregated results
├─ PgFlow.Producers
│  └─ publish to "centralcloud_workflow_patterns" queue
└─ CentralCloud Service (separate, port 4001)
    └─ Aggregates patterns from all instances
    └─ Computes consensus scores
    └─ Sends back to "singularity_workflow_consensus_patterns" queue

Layer 4: CONSENSUS REGISTRATION (Local Adoption)
├─ PgFlow.Listener
│  └─ Listens to "singularity_workflow_consensus_patterns" queue
├─ PgFlow.MessageRouter
│  └─ Routes message type "workflow_consensus_patterns" to handler
├─ Consumers.handle_workflow_consensus_patterns()
│  └─ Validates patterns (confidence 0.80+)
└─ GenesisWorkflowLearner.register_consensus_patterns()
   └─ Stores in Dispatcher for adoption
```

## Component Architecture

### 1. GenesisWorkflowLearner (lib/singularity/evolution/genesis_workflow_learner.ex)

**Purpose:** Core learning engine that analyzes workflow effectiveness and synthesizes variations.

**Key Functions:**
```elixir
# Analyze workflows from execution history
{:ok, patterns} = GenesisWorkflowLearner.analyze_workflow_effectiveness(
  min_confidence: 0.75,
  workflow_types: [:code_quality_training, :architecture_learning]
)

# Synthesize variations optimized for different goals
{:ok, variations} = GenesisWorkflowLearner.synthesize_workflow_variations(
  base_pattern: pattern,
  optimization_goals: [:execution_speed, :quality, :reliability, :cost]
)

# Publish high-confidence patterns to Genesis (0.85+)
{:ok, %{published: 5, skipped: 2}} = GenesisWorkflowLearner.publish_proven_workflows()

# Report patterns to CentralCloud for aggregation (0.80+)
{:ok, %{reported: 8, skipped: 0}} = GenesisWorkflowLearner.report_to_centralcloud()

# Request consensus patterns from CentralCloud
:ok = GenesisWorkflowLearner.request_consensus_from_centralcloud()

# Register consensus patterns locally for adoption
{:ok, 12} = GenesisWorkflowLearner.register_consensus_patterns([
  %{workflow_type: :code_quality_training, confidence: 0.92, ...},
  %{workflow_type: :architecture_learning, confidence: 0.88, ...}
])
```

**Confidence Calculation:**
```
confidence = (success_rate × 0.6) + (frequency_score × 0.3) + (quality_score × 0.1)

Where:
- success_rate: percentage of successful executions (0.0-1.0)
- frequency_score: normalized by max frequency (0.0-1.0)
- quality_score: normalized quality improvements (0.0-1.0)
```

**Gating Thresholds:**
- ✅ **0.80+** → Report to CentralCloud
- ✅ **0.85+** → Publish to Genesis
- ✅ **Any pattern** → Register if received from CentralCloud consensus

### 2. WorkflowDispatcher (lib/singularity/workflows/dispatcher.ex)

**Purpose:** Config-driven registry for centralized workflow management with pattern storage.

**Key Functions:**
```elixir
# Get workflow module for a type
{:ok, module} = Dispatcher.get_workflow(:code_quality_training)

# List all registered workflows
workflows = Dispatcher.list_workflows()
# => [{:code_quality_training, Module}, {:architecture_learning, Module}, ...]

# Record proven workflow pattern
:ok = Dispatcher.record_workflow_pattern(:code_quality_training, %{
  config: %{timeout: 30000, workers: 4},
  success_rate: 0.95,
  confidence: 0.92
})

# Get proven patterns for a workflow type
patterns = Dispatcher.get_proven_patterns(:code_quality_training)
```

**Registry Configuration (config.exs):**
```elixir
config :singularity, :workflows,
  registry: [
    code_quality_training: Singularity.Workflows.CodeQualityTrainingWorkflow,
    architecture_learning: Singularity.Workflows.ArchitectureLearningWorkflow,
    # ... 12 more workflows
  ],
  aliases: [
    quality: :code_quality_training,
    architecture: :architecture_learning
  ]
```

### 3. PgFlow Integration (lib/singularity/evolution/QuantumFlow/)

**Queue Structure:**

| Queue | Direction | Content | Handler |
|-------|-----------|---------|---------|
| `centralcloud_workflow_patterns` | → CentralCloud | Workflow patterns (confidence 0.80+) | — |
| `singularity_workflow_consensus_patterns` | ← CentralCloud | Consensus patterns | `Consumers.handle_workflow_consensus_patterns` |
| `singularity_consensus_results` | ← CentralCloud | Voting results | `Consumers.handle_consensus_result` |
| `singularity_rollback_triggers` | ← Guardian | Rollback signals | `Consumers.handle_rollback_trigger` |
| `singularity_safety_profiles` | ← Genesis | Safety updates | `Consumers.handle_safety_profile_update` |

**Producers (lib/singularity/evolution/QuantumFlow/producers.ex):**
```elixir
# Send workflow patterns to CentralCloud
{:ok, msg_id} = Producers.publish_message(
  "centralcloud_workflow_patterns",
  payload
)
```

**Consumers (lib/singularity/evolution/QuantumFlow/consumers.ex):**
```elixir
# Handle consensus patterns from CentralCloud
{:ok, "registered"} = Consumers.handle_workflow_consensus_patterns(%{
  "type" => "workflow_consensus_patterns",
  "instance_id" => "singularity-prod-001",
  "workflow_patterns" => [
    %{
      "workflow_type" => "code_quality_training",
      "config" => %{timeout: 30000},
      "success_rate" => 0.95,
      "confidence" => 0.92,
      "genesis_id" => "pattern-uuid",
      "timestamp" => "2025-10-30T16:30:00Z"
    }
  ],
  "pattern_count" => 1,
  "timestamp" => "2025-10-30T16:30:15Z"
})
```

**Message Router (lib/singularity/evolution/QuantumFlow/message_router.ex):**
```elixir
# Routes messages to appropriate handler based on type
{:ok, "processed"} = MessageRouter.route_message(%{
  "type" => "workflow_consensus_patterns",
  "workflow_patterns" => [...]
})

# Listen to a queue
{:ok, pid} = MessageRouter.listen_on_queue("singularity_workflow_consensus_patterns")
```

**Listener (lib/singularity/evolution/QuantumFlow/listener.ex):**
```elixir
# Auto-starts on application boot if configured
# Listens to all configured queues
# Routes messages via MessageRouter
# Handles acknowledgments and retries
```

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ EXECUTION TRACKING (RCA)                                            │
│                                                                     │
│ Workflows execute → GenerationSession tracks → RefinementStep logs │
│ Results stored in database with metrics                            │
└──────────────────────┬──────────────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────────────┐
│ LAYER 1: LOCAL LEARNING (Singularity)                              │
│                                                                     │
│ GenesisWorkflowLearner.analyze_workflow_effectiveness()            │
│ ↓                                                                   │
│ Query RCA data → Calculate success_rate, frequency, quality        │
│ ↓                                                                   │
│ Patterns with confidence scores:                                   │
│   - Pattern A: 0.92 (excellent)                                    │
│   - Pattern B: 0.87 (good)                                         │
│   - Pattern C: 0.78 (below threshold)                              │
└──────────────────────┬──────────────────────────────────────────────┘
                       ↓
        ┌──────────────┴──────────────┐
        ↓                             ↓
┌───────────────────────┐   ┌──────────────────────┐
│ LAYER 2: GENESIS      │   │ LAYER 3: CENTRALCLOUD│
│                       │   │                      │
│ GenesisPublisher      │   │ PgFlow Producer      │
│ .publish_workflow_    │   │                      │
│  pattern()            │   │ Send patterns to:    │
│                       │   │ "centralcloud_      │
│ Register (0.85+):     │   │  workflow_patterns" │
│ - Pattern A: 0.92 ✓   │   │                      │
│ - Pattern B: 0.87 ✓   │   │ Patterns sent (0.80+):│
│                       │   │ - Pattern A: 0.92 ✓  │
│ Available to Genesis  │   │ - Pattern B: 0.87 ✓  │
│ ecosystem             │   │ - Pattern C: 0.78 ✗  │
└───────────────────────┘   └──────────────────────┘
                                      ↓
                        ┌─────────────────────────────┐
                        │ CENTRALCLOUD SERVICE        │
                        │ (port 4001)                 │
                        │                             │
                        │ CentralCloud.Aggregator     │
                        │                             │
                        │ Receives patterns from all  │
                        │ instances, aggregates into  │
                        │ consensus scores            │
                        │                             │
                        │ Example:                    │
                        │ Instance-1: A=0.92, B=0.87 │
                        │ Instance-2: A=0.89, B=0.91 │
                        │ Instance-3: A=0.95, B=0.85 │
                        │ ─────────────────────────── │
                        │ Consensus: A=0.92, B=0.88  │
                        └──────────────┬──────────────┘
                                       ↓
                        ┌──────────────────────────┐
                        │ Send consensus patterns   │
                        │ back to queue:            │
                        │ "singularity_workflow_   │
                        │  consensus_patterns"     │
                        └──────────────┬───────────┘
                                       ↓
┌──────────────────────────────────────────────────────────────────────┐
│ LAYER 4: CONSENSUS REGISTRATION (Local Adoption)                    │
│                                                                      │
│ PgFlow.Listener                                                      │
│ ↓                                                                    │
│ Listens to "singularity_workflow_consensus_patterns"                │
│ ↓                                                                    │
│ PgFlow.MessageRouter                                                │
│ ↓                                                                    │
│ Routes type "workflow_consensus_patterns"                           │
│ ↓                                                                    │
│ Consumers.handle_workflow_consensus_patterns()                      │
│ ↓                                                                    │
│ Validates confidence (0.80+) and filter patterns                    │
│ ↓                                                                    │
│ GenesisWorkflowLearner.register_consensus_patterns()               │
│ ↓                                                                    │
│ Dispatcher.record_workflow_pattern() for each pattern               │
│ ↓                                                                    │
│ Local adoption: Patterns available for next workflow executions    │
└──────────────────────────────────────────────────────────────────────┘
```

## Configuration

### Environment Variables

```bash
# Enable PgFlow queue listeners (default: true if CENTRALCLOUD_ENABLED)
export PGFLOW_QUEUES_ENABLED=true

# Enable CentralCloud integration (default: true)
export CENTRALCLOUD_ENABLED=true
```

### Configuration (config/config.exs)

```elixir
config :singularity, :quantum_flow_queues,
  enabled: true,
  queue_listeners: [
    "singularity_workflow_consensus_patterns",
    "singularity_consensus_results",
    "singularity_rollback_triggers",
    "singularity_safety_profiles"
  ]

config :singularity, :workflows,
  registry: [
    # ... 14 workflows defined
  ],
  aliases: [
    # ... aliases
  ]
```

## Usage Examples

### Starting the Complete System

```bash
# Terminal 1: Start PostgreSQL + Singularity + CentralCloud
./start-all.sh

# Or individually:
# Terminal 1
cd singularity && mix phx.server

# Terminal 2
cd centralcloud && mix phx.server

# Terminal 3 (optional)
cd observer && mix phx.server
```

### Manually Triggering Workflow Learning

```elixir
# In iex terminal (mix phx.server or iex -S mix)

# 1. Analyze what workflows are working well
{:ok, patterns} = Singularity.Evolution.GenesisWorkflowLearner.analyze_workflow_effectiveness()

# 2. See the patterns discovered
patterns |> Enum.take(3) |> Enum.each(&IO.inspect/1)

# 3. Synthesize variations
{:ok, variations} = Singularity.Evolution.GenesisWorkflowLearner.synthesize_workflow_variations(
  base_pattern: Enum.find(patterns, & &1.confidence > 0.90),
  optimization_goals: [:execution_speed, :quality]
)

# 4. Publish proven patterns to Genesis (0.85+)
{:ok, %{published: count}} = Singularity.Evolution.GenesisWorkflowLearner.publish_proven_workflows()
IO.puts("Published #{count} patterns to Genesis")

# 5. Report to CentralCloud (0.80+)
{:ok, %{reported: count}} = Singularity.Evolution.GenesisWorkflowLearner.report_to_centralcloud()
IO.puts("Reported #{count} patterns to CentralCloud")

# 6. Check what's registered locally
Singularity.Workflows.Dispatcher.list_workflows()
|> Enum.take(3)
|> IO.inspect()

# 7. Get proven patterns for a specific workflow
patterns = Singularity.Workflows.Dispatcher.get_proven_patterns(:code_quality_training)
IO.puts("#{length(patterns)} proven patterns found")
```

## Integration with CentralCloud

CentralCloud service needs to:

1. **Listen to queue:** `centralcloud_workflow_patterns`
2. **Process messages:** Aggregate patterns from multiple instances
3. **Compute consensus:** Average confidence scores, track pattern frequency
4. **Send response:** Message with type "workflow_consensus_patterns" to queue `singularity_workflow_consensus_patterns`

**Expected CentralCloud Response Format:**
```json
{
  "type": "workflow_consensus_patterns",
  "instance_id": "centralcloud-001",
  "workflow_patterns": [
    {
      "workflow_type": "code_quality_training",
      "config": {
        "timeout": 30000,
        "workers": 4,
        "quality_threshold": 0.95
      },
      "success_rate": 0.92,
      "frequency": 42,
      "quality_improvements": 8.5,
      "confidence": 0.92,
      "genesis_id": "pattern-uuid",
      "timestamp": "2025-10-30T16:30:00Z"
    }
  ],
  "pattern_count": 1,
  "timestamp": "2025-10-30T16:30:15Z"
}
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/singularity/evolution/genesis_workflow_learner.ex` | Core learning engine (680 lines) |
| `lib/singularity/workflows/dispatcher.ex` | Config-driven workflow registry (383 lines) |
| `lib/singularity/evolution/QuantumFlow/message_router.ex` | Message routing to handlers (NEW, 200 lines) |
| `lib/singularity/evolution/QuantumFlow/listener.ex` | Auto-start queue listeners (NEW, 280 lines) |
| `lib/singularity/evolution/QuantumFlow/consumers.ex` | Message handlers (extended, +50 lines) |
| `lib/singularity/evolution/QuantumFlow/producers.ex` | Message publishing (existing) |
| `config/config.exs` | Workflow + PgFlow config (extended) |

## Testing the System

### Unit Tests
```bash
cd singularity
mix test test/singularity/evolution/genesis_workflow_learner_test.exs
mix test test/singularity/workflows/dispatcher_test.exs
mix test test/singularity/evolution/QuantumFlow/message_router_test.exs
```

### Integration Tests
```bash
# Start PostgreSQL and CentralCloud first
./start-all.sh

# Run integration tests
mix test --only integration
```

### Manual Testing
```elixir
# Check if listeners are running
Singularity.Evolution.QuantumFlow.Listener.start_link()

# Send test message
payload = %{
  "type" => "workflow_consensus_patterns",
  "instance_id" => "test-001",
  "workflow_patterns" => [
    %{
      "workflow_type" => "code_quality_training",
      "config" => %{},
      "success_rate" => 0.95,
      "frequency" => 10,
      "quality_improvements" => 5.0,
      "confidence" => 0.92,
      "genesis_id" => "test-pattern",
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
    }
  ]
}

Singularity.Evolution.QuantumFlow.MessageRouter.route_message(payload)
```

## Monitoring & Observability

### Telemetry Events

```elixir
:telemetry.execute([:evolution, :workflow, :analyzed], %{count: N})
:telemetry.execute([:evolution, :workflow, :published_to_genesis], %{count: N})
:telemetry.execute([:evolution, :workflow, :reported_to_centralcloud], %{count: N})
:telemetry.execute([:evolution, :QuantumFlow, :workflow_patterns_registered], %{count: N})
```

### Database Queries

```sql
-- Check workflow execution history (RCA)
SELECT workflow_type, COUNT(*) as executions, AVG(success) as success_rate
FROM rca_execution_results
WHERE created_at > now() - interval '7 days'
GROUP BY workflow_type;

-- Check registered workflow patterns
SELECT workflow_type, COUNT(*) as pattern_count, AVG(confidence) as avg_confidence
FROM workflow_patterns
GROUP BY workflow_type;
```

## Future Enhancements

1. **Adaptive Learning:** Automatically update workflow config based on patterns
2. **Pattern Clustering:** Group similar patterns, merge if confidence > threshold
3. **Cross-Workflow Learning:** Learn patterns that span multiple workflow types
4. **Cost Optimization:** Track and optimize for lowest cost while maintaining quality
5. **Prediction Models:** Predict best workflow variant for given codebase characteristics
6. **Human-in-the-Loop:** Request approval for high-impact pattern changes

## Architecture Decisions

### Why Three Layers?

1. **Local Learning** - Fast feedback loop, can experiment freely
2. **Genesis Publication** - Persistent patterns in framework, available across instances
3. **CentralCloud Consensus** - Multi-instance intelligence, detects global trends

### Why Confidence Gating?

- **0.80+** for CentralCloud: Proven locally, safe to share across instances
- **0.85+** for Genesis: Very high confidence, worth persisting to framework
- Prevents spreading unproven patterns; allows conservative adoption

### Why PgFlow?

- **Durable messaging** - PostgreSQL PGMQ handles retries, no message loss
- **Asynchronous** - Singularity continues operating if CentralCloud is slow/down
- **Scalable** - Works with 1 or 1000 instances

## Troubleshooting

### Patterns Not Being Reported to CentralCloud

```elixir
# 1. Check if patterns exist
{:ok, patterns} = GenesisWorkflowLearner.analyze_workflow_effectiveness()
IO.inspect(patterns, label: "Analyzed patterns")

# 2. Check confidence scores
patterns |> Enum.map(& &1.confidence) |> IO.inspect()

# 3. Check if CentralCloud queue exists
Singularity.PgFlow.list_queues()

# 4. Try manual reporting
{:ok, result} = GenesisWorkflowLearner.report_to_centralcloud(min_confidence: 0.75)
```

### Consensus Patterns Not Being Received

```elixir
# 1. Check if listener is running
Process.whereis(Singularity.Evolution.QuantumFlow.Listener)

# 2. Check queue for pending messages
Singularity.PgFlow.read_from_queue("singularity_workflow_consensus_patterns")

# 3. Enable debug logging
Logger.configure(level: :debug)
```

## References

- `CLAUDE.md` - Project overview and setup guide
- `AGENTS.md` - Agent system and execution architecture
- `CENTRALCLOUD_INTEGRATION_GUIDE.md` - CentralCloud setup
- `AGENT_SYSTEM_EXPERT.md` - System architecture details
