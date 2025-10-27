# Phase 8.1: Infrastructure Systems Database & Schema

## Completed

### 1. Migration: `infrastructure_systems` Table
**File**: `centralcloud/priv/repo/migrations/20251027000001_create_infrastructure_systems.exs`

Creates the infrastructure_systems table with:
- UUID primary key
- Fields: name, category, description, detection_patterns (JSONB), fields (JSONB)
- Tracking fields: source, confidence (0.0-1.0), last_validated_at, learned_at
- Indexes: unique (name, category), category, confidence, inserted_at

### 2. Schema: `InfrastructureSystem`
**File**: `centralcloud/lib/centralcloud/schemas/infrastructure_system.ex`

Ecto schema with:
- Changeset validation (required: name, category; confidence bounds 0.0-1.0)
- Helper methods:
  - `get_or_create(name, category, attrs)` - Get existing or create new
  - `upsert(name, category, attrs)` - Update or create
  - `record_detection_result(name, category, detected?)` - Update confidence based on detection

**Confidence Adjustments**:
- Detection successful: +0.05
- Detection failed: -0.10
- Bounded to [0.0, 1.0]

### 3. Service: `InfrastructureRegistry`
**File**: `centralcloud/lib/centralcloud/infrastructure/registry.ex`

Core CRUD operations:
- `get_all_systems(opts)` - Get all systems with optional filtering
- `get_systems_by_category(category, opts)` - Query by category
- `get_system(name, category)` - Get single system
- `upsert_system(attrs)` - Create or update
- `record_detection(name, category, detected?)` - Update confidence
- `batch_record_detections(results)` - Batch updates
- `get_formatted_registry(opts)` - Get systems grouped by category (for NATS response)
- `seed_initial_systems(systems)` - Populate from list
- `get_statistics()` - Count and confidence metrics

### 4. NATS Endpoint: `IntelligenceHub.InfrastructureEndpoint`
**File**: `centralcloud/lib/centralcloud/infrastructure/intelligence_endpoint.ex`

Handles NATS requests at subject: `intelligence_hub.infrastructure.registry`

**Request Format**:
```json
{
  "query_type": "infrastructure_registry",
  "include": ["message_brokers", "databases", ...],
  "min_confidence": 0.7
}
```

**Response Format**:
```json
{
  "message_brokers": [
    {
      "name": "Kafka",
      "category": "message_brokers",
      "detection_patterns": [...],
      "fields": {...},
      "confidence": 0.95,
      "source": "llm"
    }
  ],
  "service_mesh": [...],
  ...
}
```

## Next Steps

### Phase 8.2: Initial Seed & Integration
1. Add `IntelligenceHub.InfrastructureEndpoint` to application.ex supervision tree
2. Seed initial 14 Phase 7 infrastructure systems from Rust defaults
3. Update `InfrastructureRegistryCache` in Singularity to use CentralCloud endpoint
4. Test detection flow with cached definitions

### Phase 8.3: LLM Research Agent
1. Create `InfrastructureResearchAgent` for LLM-powered discovery
2. Implement detection pattern generation
3. Auto-populate confidence scores

### Phase 8.4: Learning Loop
1. Track detection accuracy per system
2. Auto-update confidence from results
3. Implement learning feedback mechanisms

## Database Schema

```
infrastructure_systems
  id UUID PK
  name string NOT NULL
  category string NOT NULL
  description text
  detection_patterns jsonb[] DEFAULT []
  fields jsonb DEFAULT {}
  source string DEFAULT 'manual' ('llm'|'manual'|'research')
  confidence float DEFAULT 0.5 (0.0-1.0)
  last_validated_at utc_datetime
  learned_at utc_datetime
  created_at utc_datetime
  updated_at utc_datetime

INDEXES:
  UNIQUE(name, category)
  (category)
  (confidence DESC)
  (inserted_at DESC)
```

## Example Usage

```elixir
# Create system
{:ok, kafka} = Registry.upsert_system(%{
  name: "Kafka",
  category: "message_brokers",
  detection_patterns: ["kafka.yml", "kafkajs"],
  confidence: 0.85,
  source: "llm"
})

# Get by category
{:ok, brokers} = Registry.get_systems_by_category("message_brokers", min_confidence: 0.8)

# Record detection result
{:ok, kafka} = Registry.record_detection("Kafka", "message_brokers", true)

# Get formatted for NATS response
{:ok, registry} = Registry.get_formatted_registry(min_confidence: 0.8)
```

## Status

✅ **Database & Schema Complete**
- [x] Migration created
- [x] Schema with validations
- [x] Registry service with CRUD
- [x] NATS endpoint for queries
- [ ] Added to supervision tree (Phase 8.2)
- [ ] Initial seed data (Phase 8.2)
- [ ] LLM Research Agent (Phase 8.3)
- [ ] Learning loop (Phase 8.4)
