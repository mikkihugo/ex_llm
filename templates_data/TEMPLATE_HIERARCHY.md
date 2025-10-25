# Architecture Pattern Template Hierarchy

## Overview

All 22 architecture pattern templates are organized in a self-documenting hierarchical structure using the `parent_pattern` field in JSON. This enables:

- **Type Hierarchy Navigation**: Understand how patterns relate to each other
- **Self-Documenting Types**: Type relationships explicit in JSON, not inferred
- **Efficient Querying**: JSONB hierarchy field enables fast hierarchical queries
- **Learning Bidirectionality**: Types automatically tracked for Git ↔ PostgreSQL ↔ CentralCloud sync

## Hierarchy Structure

### Foundation Patterns (Root)

These 11 root patterns form the foundation of all architecture decisions:

1. **monolith** - Single deployment unit with shared database
   - modular - Modular monolith with clear boundaries
   - layered - Layered architecture pattern
   - hexagonal - Hexagonal (ports & adapters) pattern
   - domain-driven-monolith - DDD-based monolithic structure
   - distributed - Multiple deployables (anti-pattern variant)

2. **microservices** - Multiple independent services
   - microservices-saga - Saga pattern for distributed transactions
   - microservices-cqrs - CQRS pattern for read/write separation
   - microservices-event-sourcing - Event sourcing for state management

3. **publish-subscribe** - Asynchronous pub/sub communication
   - event-driven - Event-driven architecture
   - message-queue - Message queue variant

4. **request-response** - Synchronous RPC communication

5. **domain-driven-design** - Design methodology
   - subdomain-services - Services mapped to subdomains

6. **api-gateway** - Gateway pattern (infrastructure)

7. **service-mesh** - Service mesh (infrastructure)

8. **serverless** - Serverless/FaaS architecture

9. **peer-to-peer** - P2P decentralized architecture

10. **hybrid** - Combination of multiple patterns

11. **cqrs** - CQRS standalone pattern

## Hierarchy Tree

```
monolith
├── modular
├── layered
├── hexagonal
├── domain-driven-monolith
└── distributed

microservices
├── microservices-saga
├── microservices-cqrs
└── microservices-event-sourcing

publish-subscribe
├── event-driven
└── message-queue

request-response (no children)

domain-driven-design
└── subdomain-services

api-gateway (infrastructure, no children)
service-mesh (infrastructure, no children)
serverless (no children)
peer-to-peer (no children)
hybrid (combination, no children)
cqrs (standalone, no children)
```

## Template JSON Structure

Each template includes hierarchical metadata:

```json
{
  "id": "microservices_saga",
  "name": "Microservices with Saga Pattern",
  "category": "architecture",
  "version": "1.0.0",
  "parent_pattern": "microservices",
  "description": "...",
  "indicators": [...],
  "benefits": [...],
  "concerns": [...]
}
```

### Hierarchical Fields

- **parent_pattern** (string | null) - Parent pattern ID (null for roots)
- **category** (string) - "architecture" for all patterns
- **_type_hierarchy** (computed) - Added by loader, contains:
  - `type`: detected artifact type
  - `parent`: parent pattern
  - `category`: category
  - `hierarchy_path`: computed path (e.g., "microservices/saga")

## Loading Strategy

The `mix templates_data.load` task:

1. **Reads** all 22 templates from `templates_data/architecture_patterns/`
2. **Detects** artifact type from JSON structure (fallback to directory)
3. **Extracts** hierarchy info (`parent_pattern`, `category`)
4. **Builds** `_type_hierarchy` map with:
   - Explicit parent relationships
   - Computed hierarchy paths for querying
   - Self-documenting structure
5. **Stores** in PostgreSQL with:
   - `artifact_type` - detected type
   - `content` (JSONB) - full template with hierarchy
   - `content_raw` (TEXT) - original JSON for audit trail

## Querying by Hierarchy

### Direct Queries

```sql
-- Find all microservices variants
SELECT * FROM knowledge_artifacts
WHERE content @> '{"parent_pattern": "microservices"}';

-- Find all patterns under monolith
SELECT * FROM knowledge_artifacts
WHERE content @> '{"parent_pattern": "monolith"}';

-- Find root patterns (no parent)
SELECT * FROM knowledge_artifacts
WHERE content @> '{"parent_pattern": null}'
AND artifact_type = 'architecture_pattern';
```

### Elixir Queries

```elixir
alias Singularity.Knowledge.ArtifactStore

# Find all children of a pattern
{:ok, children} = ArtifactStore.query_jsonb(
  filter: %{"parent_pattern" => "microservices"}
)

# Find patterns by hierarchy path
{:ok, results} = ArtifactStore.search(
  "microservices saga",
  artifact_type: "architecture_pattern"
)
```

## Design Principles

### 1. Self-Documenting Types
- Type relationships are **explicit** in JSON (`parent_pattern`), not inferred
- No need for code changes to add new patterns or hierarchy levels
- Patterns themselves define their relationships

### 2. Hierarchical Organization
- Root patterns represent fundamental architectural choices
- Child patterns represent specializations or optimizations
- Clear parent-child relationships enable:
  - Migration paths (monolith → modular → microservices)
  - Pattern selection guidance
  - Comparison of variants

### 3. Bidirectional Sync
- **Git ← PostgreSQL ← CentralCloud**: Hierarchy data flows everywhere
- Changes to `parent_pattern` in Git automatically sync to DB
- Learning system preserves hierarchy when promoting patterns
- Enables cross-instance pattern discovery

### 4. No Type Inference
- ❌ **OLD**: Infer types from JSON structure keys
- ✅ **NEW**: Types declared explicitly in `parent_pattern` field
- This makes types:
  - Queryable by hierarchy
  - Machine-readable
  - Human-understandable

## Adding New Patterns

To add a new pattern:

1. **Create JSON** with `parent_pattern` field:
```json
{
  "id": "new_pattern",
  "name": "New Pattern Name",
  "parent_pattern": "parent_id_or_null",
  "category": "architecture",
  "indicators": [...],
  "benefits": [...]
}
```

2. **Load into DB**:
```bash
mix templates_data.load architecture_patterns
```

3. **Sync to CentralCloud** (if enabled):
```bash
moon run templates_data:sync-to-db
```

The hierarchy is automatically recognized without any code changes.

## Type Hierarchy Statistics

- **Total patterns**: 22
- **Root patterns**: 11
- **Child patterns**: 11
- **Max depth**: 2 levels
- **Average children per root**: 1
- **Most variants**: microservices (3 variants)

## File Organization

```
templates_data/
├── architecture_patterns/
│   ├── monolith.json
│   ├── modular.json
│   ├── microservices.json
│   ├── microservices-saga.json
│   ├── microservices-cqrs.json
│   ├── publish-subscribe.json
│   ├── ... (22 total)
│   └── TEMPLATE_HIERARCHY.md (this file)
```

## Next Steps

1. **Sync to PostgreSQL**: Run `mix templates_data.load` to populate DB
2. **Query by Hierarchy**: Use JSONB queries to navigate patterns
3. **CentralCloud Integration**: Patterns sync to central learning system
4. **Pattern Learning**: Track usage and auto-promote successful patterns

## References

- See **DATABASE_STRATEGY.md** for JSONB storage details
- See **KNOWLEDGE_ARTIFACTS_SETUP.md** for full knowledge base setup
- See **CLAUDE.md** "Living Knowledge Base" for bidirectional sync pattern
