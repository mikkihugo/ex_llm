# Singularity Work Plan System

Complete SAFe 6.0 Essential Portfolio Management with NATS API, PostgreSQL persistence, and WSJF prioritization.

## Overview

The Work Plan system implements **SAFe 6.0 Essential** framework for managing strategic work across the Singularity platform. It provides a complete hierarchy from 3-5 year strategic themes down to 1-3 month features, with automatic WSJF (Weighted Shortest Job First) prioritization.

## Architecture

### Hierarchy (SAFe 6.0)

```
Strategic Themes (3-5 year vision areas)
  └─ Epics (6-12 month initiatives - Business or Enabler)
      └─ Capabilities (3-6 month cross-team features)
          └─ Features (1-3 month team deliverables)
              └─ HTDAG breakdown → Stories → Tasks
```

### Components

1. **Database Layer** (`priv/repo/migrations/20240101000007_create_work_plan_tables.exs`)
   - PostgreSQL tables for strategic_themes, epics, capabilities, features
   - Ecto schemas with validation and type safety
   - Automatic WSJF calculation

2. **GenServer State** (`work_plan_coordinator.ex`)
   - In-memory cache of all work items
   - Loads from database on startup
   - Provides fast access to hierarchy and next work

3. **NATS API** (`work_plan_api.ex`)
   - External interface for submitting work via NATS
   - Request/reply pattern for synchronous operations
   - JSON message format

4. **Seed Data** (`priv/repo/seeds/work_plan_seeds.exs`)
   - Real Singularity roadmap
   - 3 Strategic Themes, 7+ Epics, multiple Capabilities/Features
   - 6.5 BLOC total target

## Getting Started

### 1. Run Migrations

```bash
cd singularity_app
mix ecto.migrate
```

This creates the tables:
- `strategic_themes`
- `epics`
- `capabilities`
- `capability_dependencies`
- `features`

### 2. Seed Initial Data

```bash
mix planning.seed
```

This loads the Singularity roadmap with:
- **Strategic Theme 1**: Autonomous Code Generation (3 BLOC)
  - Epic: Self-Improving Agent System
  - Epic: Semantic Code Search & RAG
- **Strategic Theme 2**: Distributed Agent Orchestration (2 BLOC)
  - Epic: NATS-Based Messaging
  - Epic: SAFe Portfolio Management
- **Strategic Theme 3**: Production-Grade Infrastructure (1.5 BLOC)
  - Epic: Observability Stack
  - Epic: Database Optimization

### 3. Start the Application

```bash
mix phx.server
```

The `WorkPlanCoordinator` and `WorkPlanAPI` start automatically and load data from the database.

## Usage

### Direct API (Elixir)

```elixir
alias Singularity.Execution.Planning.WorkPlanCoordinator

# Add a strategic theme
{:ok, theme_id} = WorkPlanCoordinator.add_strategic_theme(%{
  name: "AI-Powered Development",
  description: "Build AI-first development tools (5 BLOC)",
  target_bloc: 5.0,
  priority: 1
})

# Add an epic
{:ok, epic_id} = WorkPlanCoordinator.add_epic(%{
  theme_id: theme_id,
  name: "Intelligent Code Review",
  description: "AI-powered code review with automated fixes",
  type: :business,
  business_value: 9,
  time_criticality: 8,
  risk_reduction: 7,
  job_size: 10
})

# Add a capability
{:ok, cap_id} = WorkPlanCoordinator.add_capability(%{
  epic_id: epic_id,
  name: "Static Analysis Integration",
  description: "Integrate with existing static analysis tools",
  depends_on: []
})

# Add a feature
{:ok, feature_id} = WorkPlanCoordinator.add_feature(%{
  capability_id: cap_id,
  name: "Credo Integration",
  description: "Auto-fix Credo warnings",
  acceptance_criteria: [
    "Detects all Credo warnings",
    "Suggests fixes for 80%+ of warnings",
    "Auto-applies safe fixes"
  ]
})

# Get next work (highest WSJF)
next_work = WorkPlanCoordinator.get_next_work()

# Get full hierarchy
hierarchy = WorkPlanCoordinator.get_hierarchy()

# Get progress summary
progress = WorkPlanCoordinator.get_progress()
```

### NATS API (External Systems)

#### Create Strategic Theme

```bash
nats req planning.strategic_theme.create '{
  "name": "AI-Powered Development",
  "description": "Build AI-first development tools (5 BLOC)",
  "target_bloc": 5.0,
  "priority": 1
}'
```

Response:
```json
{
  "status": "ok",
  "id": "theme-abc123",
  "message": "Strategic theme created successfully"
}
```

#### Create Epic

```bash
nats req planning.epic.create '{
  "theme_id": "theme-abc123",
  "name": "Intelligent Code Review",
  "description": "AI-powered code review with automated fixes",
  "type": "business",
  "business_value": 9,
  "time_criticality": 8,
  "risk_reduction": 7,
  "job_size": 10
}'
```

#### Create Capability

```bash
nats req planning.capability.create '{
  "epic_id": "epic-xyz789",
  "name": "Static Analysis Integration",
  "description": "Integrate with existing static analysis tools",
  "depends_on": []
}'
```

#### Create Feature

```bash
nats req planning.feature.create '{
  "capability_id": "cap-def456",
  "name": "Credo Integration",
  "description": "Auto-fix Credo warnings",
  "acceptance_criteria": [
    "Detects all Credo warnings",
    "Suggests fixes for 80%+ of warnings",
    "Auto-applies safe fixes"
  ]
}'
```

#### Get Next Work

```bash
nats req planning.next_work.get '{}'
```

Response:
```json
{
  "status": "ok",
  "next_work": {
    "id": "feat-abc123",
    "name": "Credo Integration",
    "description": "Auto-fix Credo warnings",
    "capability_id": "cap-def456",
    "status": "backlog",
    "acceptance_criteria": [...]
  }
}
```

#### Get Hierarchy

```bash
nats req planning.hierarchy.get '{}'
```

#### Get Progress

```bash
nats req planning.progress.get '{}'
```

Response:
```json
{
  "status": "ok",
  "progress": {
    "themes": {"active": 3, "completed": 0},
    "epics": {"ideation": 2, "analysis": 1, "implementation": 4, "done": 0},
    "capabilities": {"backlog": 3, "implementing": 4, "done": 0},
    "features": {"backlog": 8, "in_progress": 4, "done": 0},
    "total_bloc_target": 6.5,
    "completion_percentage": 0.0
  }
}
```

## WSJF (Weighted Shortest Job First)

### Formula

```
WSJF = (Business Value + Time Criticality + Risk Reduction) / Job Size
```

### Inputs

- **Business Value** (1-10): How much business value does this deliver?
- **Time Criticality** (1-10): How urgent is this?
- **Risk Reduction** (1-10): How much risk does this mitigate?
- **Job Size** (1-20): Estimated effort (Fibonacci-like: 1, 2, 3, 5, 8, 13, 20)

### Prioritization

- Higher WSJF = Higher priority
- Epics calculate WSJF from inputs
- Capabilities inherit WSJF from parent epic
- Features inherit WSJF from parent capability
- `get_next_work()` returns highest WSJF feature with dependencies met

### Example

```elixir
# Epic with high business value, urgency, and low effort
business_value = 9
time_criticality = 8
risk_reduction = 7
job_size = 8

wsjf = (9 + 8 + 7) / 8 = 3.0  # High priority!

# Epic with lower business value and high effort
business_value = 5
time_criticality = 4
risk_reduction = 3
job_size = 20

wsjf = (5 + 4 + 3) / 20 = 0.6  # Lower priority
```

## NATS Subjects

All subjects are defined in `work_plan_api.ex`:

- `planning.strategic_theme.create` - Create strategic theme
- `planning.epic.create` - Create epic
- `planning.capability.create` - Create capability
- `planning.feature.create` - Create feature
- `planning.hierarchy.get` - Get full hierarchy
- `planning.progress.get` - Get progress summary
- `planning.next_work.get` - Get next work (highest WSJF)

## Database Schema

### Strategic Themes

```elixir
schema "strategic_themes" do
  field :name, :string
  field :description, :string
  field :target_bloc, :float
  field :priority, :integer
  field :status, :string  # active | completed | archived
  field :approved_by, :string
  has_many :epics, Epic
  timestamps()
end
```

### Epics

```elixir
schema "epics" do
  field :name, :string
  field :description, :string
  field :type, :string  # business | enabler
  field :status, :string  # ideation | analysis | implementation | done
  field :wsjf_score, :float
  field :business_value, :integer
  field :time_criticality, :integer
  field :risk_reduction, :integer
  field :job_size, :integer
  field :approved_by, :string
  belongs_to :theme, StrategicTheme
  has_many :capabilities, Capability
  timestamps()
end
```

### Capabilities

```elixir
schema "capabilities" do
  field :name, :string
  field :description, :string
  field :status, :string  # backlog | analyzing | implementing | validating | done
  field :wsjf_score, :float
  field :approved_by, :string
  belongs_to :epic, Epic
  has_many :features, Feature
  has_many :capability_dependencies, CapabilityDependency
  has_many :depends_on, through: [:capability_dependencies, :depends_on_capability]
  timestamps()
end
```

### Features

```elixir
schema "features" do
  field :name, :string
  field :description, :string
  field :status, :string  # backlog | in_progress | done
  field :htdag_id, :string
  field :acceptance_criteria, {:array, :string}
  field :approved_by, :string
  belongs_to :capability, Capability
  timestamps()
end
```

## Integration with Vision-Driven Planning

The Work Plan system integrates with `add_chunk/2` for natural language vision submission:

```elixir
# Existing: Add vision chunk (analyzed by LLM)
WorkPlanCoordinator.add_chunk("Build distributed tracing with OpenTelemetry")

# New: Direct structured submission via API
WorkPlanCoordinator.add_feature(%{
  name: "OpenTelemetry Integration",
  description: "Integrate OpenTelemetry SDK",
  capability_id: cap_id,
  acceptance_criteria: [...]
})
```

Both approaches update the same GenServer state and database.

## Resetting Data

To reset and reseed:

```bash
# Drop and recreate database
mix ecto.drop && mix ecto.create && mix ecto.migrate

# Reload seed data
mix planning.seed

# Restart application
mix phx.server
```

## Troubleshooting

### Empty State on Startup

**Problem**: `get_next_work()` returns `nil`

**Solution**: Ensure migrations ran and seed data loaded:

```bash
mix ecto.migrate
mix planning.seed
```

### NATS Connection Errors

**Problem**: WorkPlanAPI fails to subscribe

**Solution**: Ensure NATS server is running:

```bash
nats-server -js
```

### WSJF Not Calculating

**Problem**: Epic WSJF score is 0.0

**Solution**: Ensure all WSJF inputs are provided when creating epic:

```elixir
WorkPlanCoordinator.add_epic(%{
  # ... other fields ...
  business_value: 8,
  time_criticality: 7,
  risk_reduction: 9,
  job_size: 13
})
```

### Capability Dependencies

**Problem**: Feature not returned by `get_next_work()` even with high WSJF

**Solution**: Check if capability dependencies are met. Dependencies must be in `:done` status before dependent capabilities become available.

## Future Enhancements

1. **Web UI** - Visualize hierarchy and progress
2. **LLM Integration** - Improve `add_chunk/2` with better LLM analysis
3. **HTDAG Integration** - Auto-create HTDAG from features
4. **Metrics** - Track velocity, throughput, cycle time
5. **Forecasting** - Predict completion dates based on velocity
6. **Dependency Visualization** - Graph view of capability dependencies
7. **Approval Workflows** - Multi-step approval for high-cost epics
8. **Historical Analysis** - Learn from past epic performance

## References

- [SAFe 6.0 Essential](https://scaledagileframework.com/essential-safe/)
- [WSJF Explained](https://scaledagileframework.com/wsjf/)
- [Ecto Documentation](https://hexdocs.pm/ecto/)
- [NATS Documentation](https://docs.nats.io/)
