# Phase 8: Infrastructure Registry Learning in CentralCloud

## Overview

Phase 7 established the infrastructure detection infrastructure with:
- **Rust (code_quality_engine)**: Dynamic registry with 14 systems across 4 categories
- **Elixir (ArchitectureEngine)**: InfrastructureRegistryCache, InfrastructureType behavior, InfrastructureDetectionOrchestrator
- **Integration**: CentralCloud bridge for querying registry definitions

**Phase 8 Goal**: Move infrastructure system definitions from hardcoded defaults to **LLM-researched, dynamically learned** definitions in CentralCloud.

## Current Architecture (Phase 7)

```
┌─ code_quality_engine (Rust) ────────────────────────┐
│                                                      │
│  InfrastructureRegistry {                           │
│    message_brokers: 4 systems (hardcoded)           │
│    databases: 2 systems (hardcoded)                 │
│    observability: 2 systems (hardcoded)             │
│    service_mesh: 3 systems (hardcoded)              │
│    api_gateways: 3 systems (hardcoded)              │
│    container_orchestration: 3 systems (hardcoded)   │
│    cicd: 5 systems (hardcoded)                      │
│  }                                                  │
│                                                      │
│  default_registry() fallback                        │
└──────────────────────────────────────────────────────┘
       ↓ NATS query (intelligence_hub.infrastructure.registry)
┌─ CentralCloud (Elixir) ──────────────────────────────┐
│ (Currently just passes through Rust definitions)     │
└──────────────────────────────────────────────────────┘
       ↓
┌─ ArchitectureEngine (Elixir) ───────────────────────┐
│                                                      │
│  InfrastructureRegistryCache (GenServer)            │
│    - Caches registry from CentralCloud              │
│    - Provides detection patterns for detectors      │
│    - Fallback to defaults if unavailable            │
│                                                      │
│  TechnologyDetector (uses cache)                    │
│    - detect_service_mesh/1                          │
│    - detect_api_gateways/1                          │
│    - detect_container_orchestration/1               │
│                                                      │
│  InfrastructureDetectionOrchestrator                │
│    - Config-driven detector discovery               │
│    - Parallel execution of detectors                │
└──────────────────────────────────────────────────────┘
```

## Phase 8 Target Architecture

```
┌─ CentralCloud (Elixir) ──────────────────────────────┐
│                                                      │
│  IntelligenceHub.InfrastructureRegistry              │
│    - Query database for system definitions           │
│    - Generation agent researches new systems         │
│    - LLM determines detection patterns               │
│                                                      │
│  infrastructure_systems table {                      │
│    id, name, category, description,                 │
│    detection_patterns: JSON,                        │
│    fields: JSON,                                    │
│    source: "llm" | "manual" | "research",          │
│    confidence: float,                               │
│    learned_at: timestamp                            │
│  }                                                  │
│                                                      │
│  InfrastructureLearningAgent                        │
│    - Researches new infrastructure systems          │
│    - Generates/validates detection patterns         │
│    - Updates database with findings                 │
│    - Learns from detection results                  │
│                                                      │
│  intelligence_hub.infrastructure.registry endpoint  │
│    - Returns all systems with LLM-generated patterns│
│    - High confidence (0.9+) systems                 │
│    - Recently updated systems first                 │
│                                                      │
└──────────────────────────────────────────────────────┘
         ↓
┌─ code_quality_engine (Rust) ────────────────────────┐
│                                                      │
│  InfrastructureRegistry (empty defaults fallback)   │
│    - Serves hardcoded defaults if CentralCloud down │
│    - Minimal maintenance burden                     │
│    - Handles offline mode gracefully                │
│                                                      │
└──────────────────────────────────────────────────────┘
         ↓
┌─ ArchitectureEngine (Elixir) ───────────────────────┐
│                                                      │
│  InfrastructureRegistryCache (unchanged)            │
│    - Queries CentralCloud for definitions           │
│    - Caches locally                                 │
│    - Falls back to Rust defaults if needed          │
│                                                      │
│  TechnologyDetector (unchanged)                     │
│    - Works with LLM-generated patterns              │
│    - Better detection via research                  │
│                                                      │
│  InfrastructureDetectionOrchestrator (unchanged)    │
│    - Config-driven discovery (as before)            │
│                                                      │
└──────────────────────────────────────────────────────┘
```

## Phase 8 Tasks

### Task 1: Create infrastructure_systems Table
**Location**: `central_services/lib/central_services/repo/migrations/`

```elixir
create table(:infrastructure_systems) do
  add :name, :string, null: false                      # "Istio", "Kong", etc.
  add :category, :string, null: false                  # "service_mesh", "api_gateway", etc.
  add :description, :text
  add :detection_patterns, :jsonb, default: []         # ["istio.yml", "istiod"]
  add :fields, :jsonb, default: %{}                    # {"virtual_services" => "array"}
  add :source, :string, default: "manual"              # "llm", "manual", "research"
  add :confidence, :float, default: 0.5
  add :last_validated_at, :utc_datetime
  add :learned_at, :utc_datetime

  timestamps()
end

create unique_index(:infrastructure_systems, [:name, :category])
create index(:infrastructure_systems, [:category])
create index(:infrastructure_systems, [:confidence, :inserted_at])
```

### Task 2: Create InfrastructureSystem Schema
**Location**: `central_services/lib/central_services/infrastructure/infrastructure_system.ex`

```elixir
defmodule CentralServices.Infrastructure.InfrastructureSystem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "infrastructure_systems" do
    field :name, :string
    field :category, :string
    field :description, :string
    field :detection_patterns, {:array, :string}, default: []
    field :fields, :map, default: %{}
    field :source, :string, default: "manual"
    field :confidence, :float, default: 0.5
    field :last_validated_at, :utc_datetime
    field :learned_at, :utc_datetime

    timestamps()
  end

  def changeset(system, attrs) do
    system
    |> cast(attrs, [
      :name, :category, :description, :detection_patterns,
      :fields, :source, :confidence, :learned_at
    ])
    |> validate_required([:name, :category])
    |> validate_confidence()
  end

  defp validate_confidence(changeset) do
    validate_number(changeset, :confidence,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
  end
end
```

### Task 3: Create InfrastructureRegistry Service
**Location**: `central_services/lib/central_services/infrastructure/registry.ex`

```elixir
defmodule CentralServices.Infrastructure.Registry do
  @moduledoc "Query and manage infrastructure system definitions"

  import Ecto.Query
  alias CentralServices.Repo
  alias CentralServices.Infrastructure.InfrastructureSystem

  def get_all_systems(min_confidence \\ 0.5) do
    InfrastructureSystem
    |> where([s], s.confidence >= ^min_confidence)
    |> order_by([s], [desc: s.confidence, desc: s.inserted_at])
    |> Repo.all()
    |> group_by_category()
  end

  def get_systems_by_category(category, min_confidence \\ 0.5) do
    InfrastructureSystem
    |> where([s], s.category == ^category)
    |> where([s], s.confidence >= ^min_confidence)
    |> order_by([s], [desc: s.confidence])
    |> Repo.all()
  end

  def create_or_update_system(attrs) do
    system = Repo.get_by(InfrastructureSystem,
      name: attrs.name,
      category: attrs.category
    )

    if system do
      InfrastructureSystem.changeset(system, Map.put(attrs, :last_validated_at, DateTime.utc_now()))
      |> Repo.update()
    else
      InfrastructureSystem.changeset(%InfrastructureSystem{},
        Map.put(attrs, :learned_at, DateTime.utc_now()))
      |> Repo.insert()
    end
  end

  defp group_by_category(systems) do
    systems
    |> Enum.reduce(%{}, fn system, acc ->
      category = system.category
      Map.update(acc, category, [system], &[system | &1])
    end)
  end
end
```

### Task 4: Create InfrastructureResearchAgent
**Location**: `central_services/lib/central_services/agents/infrastructure_research_agent.ex`

LLM-powered agent that:
- Researches infrastructure systems when requested
- Generates detection patterns using LLM
- Updates registry with findings
- Validates patterns against codebase results
- Learns from detection accuracy

Example capabilities:
```elixir
# Research a new system
InfrastructureResearchAgent.research_system("Dapr", "service_mesh")
# → Returns: {
#     name: "Dapr",
#     category: "service_mesh",
#     detection_patterns: ["dapr.yml", "dapr", ".dapr"],
#     fields: %{"actors" => "array"},
#     confidence: 0.85
#   }

# Update confidence based on detection results
InfrastructureResearchAgent.record_detection_result("Istio", true)
# → Increases confidence if correctly detected, decreases if missed

# Batch research systems
InfrastructureResearchAgent.research_category("message_broker")
# → Researches and updates all systems in category
```

### Task 5: Create IntelligenceHub Endpoint
**Location**: `central_services/lib/central_services/intelligence_hub/infrastructure.ex`

NATS endpoint that serves infrastructure definitions:

```elixir
# Query subject: intelligence_hub.infrastructure.registry
# Request:
{
  "query_type": "infrastructure_registry",
  "include": ["message_brokers", "databases", ..., "cicd"],
  "min_confidence": 0.7
}

# Response:
{
  "message_brokers": [
    {
      "name": "Kafka",
      "category": "message_broker",
      "description": "...",
      "detection_patterns": [...],
      "fields": {...},
      "confidence": 0.95,
      "source": "llm"
    },
    ...
  ],
  "service_mesh": [...],
  ...
}
```

## Implementation Flow

### Phase 8.1: Database & Schema
1. Create migration for `infrastructure_systems` table
2. Create `InfrastructureSystem` schema with validations
3. Create `Registry` service for CRUD operations

### Phase 8.2: Agent & Learning
1. Create `InfrastructureResearchAgent` with LLM integration
2. Implement detection pattern generation via LLM
3. Implement confidence tracking and updates
4. Add batch research capabilities

### Phase 8.3: Integration
1. Create IntelligenceHub endpoint
2. Update InfrastructureRegistryCache to use endpoint
3. Add fallback chain: CentralCloud → Rust defaults
4. Test with TechnologyDetector

### Phase 8.4: Validation & Learning
1. Track detection accuracy per system
2. Auto-update confidence based on results
3. Flag low-confidence systems for review
4. Implement feedback loop for learning

## Benefits

✅ **Dynamic Infrastructure Support**: Add new systems without code changes
✅ **LLM-Researched**: Patterns generated by LLM with reasoning
✅ **Learning System**: Confidence improves over time
✅ **Centralized Management**: All infrastructure definitions in one place
✅ **Graceful Degradation**: Works offline with defaults
✅ **Cross-Instance Learning**: CentralCloud learns from all Singularity instances

## Success Metrics

- All 14 Phase 7 systems with LLM-generated patterns
- Confidence scores 0.8+ for all systems
- Detection accuracy >95% for high-confidence systems
- New infrastructure systems auto-researched on request
- Confidence increases as detections are validated

## Timeline

- Phase 8.1 (Database): 1-2 days
- Phase 8.2 (Agent): 2-3 days
- Phase 8.3 (Integration): 1 day
- Phase 8.4 (Validation): 1-2 days

**Total: 5-8 days**
