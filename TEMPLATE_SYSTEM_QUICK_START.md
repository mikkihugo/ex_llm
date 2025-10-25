# Template System Quick Start Guide

## What Is It?

A **hierarchical, self-documenting template system** for architecture patterns:
- **22 architecture patterns** organized in a hierarchy
- **11 root patterns** (fundamental choices like monolith vs microservices)
- **11 child patterns** (specializations like microservices-saga, microservices-cqrs)
- **Self-documenting types** - relationships declared via `parent_pattern` field in JSON
- **Zero config** - New patterns added via JSON only, no code changes

## Quick Facts

| Aspect | Details |
|--------|---------|
| **Total Templates** | 22 JSON files |
| **Root Patterns** | 11 (monolith, microservices, publish-subscribe, etc.) |
| **Child Patterns** | 11 (monolith variants, microservices variants, etc.) |
| **Storage** | PostgreSQL JSONB + Text (parsed + raw) |
| **Queries** | JSONB operators (@>) for hierarchy lookups |
| **Type Hierarchy** | Explicit via `parent_pattern` field |
| **Status** | Ready to load ✓ |

## File Structure

```
templates_data/
├── architecture_patterns/
│   ├── monolith.json                     (root)
│   ├── modular.json                      (parent: monolith)
│   ├── layered.json                      (parent: monolith)
│   ├── hexagonal.json                    (parent: monolith)
│   ├── domain-driven-monolith.json       (parent: monolith)
│   ├── distributed.json                  (parent: monolith)
│   ├── microservices.json                (root)
│   ├── microservices-saga.json           (parent: microservices)
│   ├── microservices-cqrs.json           (parent: microservices)
│   ├── microservices-event-sourcing.json (parent: microservices)
│   ├── publish-subscribe.json            (root)
│   ├── event-driven.json                 (parent: publish-subscribe)
│   ├── message-queue.json                (parent: publish-subscribe)
│   ├── request-response.json             (root)
│   ├── domain-driven-design.json         (root)
│   ├── subdomain-services.json           (parent: domain-driven-design)
│   ├── api-gateway.json                  (root, infrastructure)
│   ├── service-mesh.json                 (root, infrastructure)
│   ├── serverless.json                   (root)
│   ├── peer-to-peer.json                 (root)
│   ├── hybrid.json                       (root)
│   ├── cqrs.json                         (root)
│   └── TEMPLATE_HIERARCHY.md             (documentation)
```

## How to Use

### 1. Load Templates into PostgreSQL

```bash
cd singularity

# Load all architecture patterns
mix templates_data.load architecture_patterns

# Or load all template types
mix templates_data.load all

# Verify in PostgreSQL
psql -d singularity -c "
SELECT artifact_id, content->>'name' as name, content->>'parent_pattern' as parent
FROM knowledge_artifacts
WHERE artifact_type = 'architecture_pattern'
ORDER BY artifact_id;"
```

### 2. Query by Hierarchy

Find all microservices variants:
```sql
SELECT artifact_id, content->>'name' as name
FROM knowledge_artifacts
WHERE content @> '{"parent_pattern": "microservices"}'
ORDER BY artifact_id;
```

Find root patterns (no parent):
```sql
SELECT artifact_id, content->>'name' as name
FROM knowledge_artifacts
WHERE content->>'parent_pattern' IS NULL
AND artifact_type = 'architecture_pattern'
ORDER BY artifact_id;
```

Find by hierarchy path:
```sql
SELECT artifact_id, content->'_type_hierarchy'->>'hierarchy_path' as path
FROM knowledge_artifacts
WHERE content -> '_type_hierarchy' @> '{"hierarchy_path": "monolith/modular"}'
ORDER BY artifact_id;
```

### 3. Add New Pattern

Create `templates_data/architecture_patterns/new-pattern.json`:

```json
{
  "id": "new_pattern",
  "name": "New Pattern Name",
  "category": "architecture",
  "version": "1.0.0",
  "parent_pattern": "parent_id_or_null",
  "description": "...",
  "indicators": [...],
  "benefits": [...],
  "concerns": [...]
}
```

Load it:
```bash
mix templates_data.load architecture_patterns
```

That's it! No code changes needed.

## Understanding the Hierarchy

### Monolith Family
- **monolith** (root) - Single deployment unit
  - **modular** - With clear module boundaries
  - **layered** - Using layered architecture pattern
  - **hexagonal** - Using ports & adapters pattern
  - **domain-driven-monolith** - DDD-based structure
  - **distributed** - Multiple deployables (anti-pattern variant)

### Microservices Family
- **microservices** (root) - Multiple independent services
  - **microservices-saga** - Saga pattern for distributed transactions
  - **microservices-cqrs** - CQRS pattern for read/write separation
  - **microservices-event-sourcing** - Event sourcing for state management

### Communication Patterns
- **request-response** (root) - Synchronous RPC
- **publish-subscribe** (root) - Asynchronous messaging
  - **event-driven** - Architecture based on events
  - **message-queue** - Queue-based communication

### Design Methodologies
- **domain-driven-design** (root) - DDD methodology
  - **subdomain-services** - Services mapped to subdomains

### Infrastructure & Standalone
- **api-gateway** (root) - Gateway pattern
- **service-mesh** (root) - Service mesh layer
- **serverless** (root) - Serverless/FaaS
- **peer-to-peer** (root) - P2P architecture
- **hybrid** (root) - Combinations
- **cqrs** (root) - Standalone CQRS pattern

## JSON Template Structure

```json
{
  "id": "template_id",
  "name": "Human-Readable Name",
  "category": "architecture",
  "version": "1.0.0",
  "parent_pattern": "parent_id_or_null",
  "description": "What this pattern is...",
  "aliases": ["Alternative name 1", "Alternative name 2"],
  "indicators": [
    {
      "name": "indicator_name",
      "description": "How to detect this pattern",
      "weight": 0.85,
      "required": true
    }
  ],
  "benefits": [
    "Benefit 1",
    "Benefit 2"
  ],
  "concerns": [
    "Concern 1",
    "Concern 2"
  ],
  "when_to_use": [
    "When you have situation X",
    "When you need Y"
  ],
  "when_not_to_use": [
    "When you have situation A",
    "When you need B"
  ],
  "required_practices": [
    {
      "practice": "Practice Name",
      "priority": "REQUIRED|RECOMMENDED|OPTIONAL",
      "description": "Why this practice is important"
    }
  ],
  "tools_and_frameworks": [
    "Tool 1",
    "Framework 1"
  ],
  "llm_team_validation": {
    "validated": true,
    "consensus_score": 85,
    "validated_by": ["claude-opus", "gpt-4.1"],
    "validation_date": "2025-10-25",
    "approved": true
  },
  "metadata": {
    "created_at": "2025-10-25",
    "version": "1.0.0",
    "detection_template": "detect-pattern.lua"
  }
}
```

## Storage Details

### PostgreSQL Columns

```
knowledge_artifacts
├── artifact_type     TEXT         "architecture_pattern"
├── artifact_id       TEXT         "microservices_saga"
├── version          TEXT          "1.0.0"
├── content          JSONB         Full template (parsed, queryable)
├── content_raw      TEXT          Original JSON (audit trail)
├── source           TEXT          "git" or "learned"
├── created_by       TEXT          "templates_loader"
└── embedding        vector        (pgvector for semantic search)
```

### Automatic JSONB Enrichment

The loader automatically adds:
```json
{
  "_type_hierarchy": {
    "type": "microservices_saga",
    "parent": "microservices",
    "category": "architecture",
    "self_documenting": true,
    "hierarchy_path": "microservices/saga"
  },
  "_detected_type": "architecture_pattern"
}
```

This enables:
- Fast hierarchy queries without JSON parsing
- Self-documenting type relationships
- Pattern migration path tracking

## Mix Task Usage

```bash
# Load all templates
mix templates_data.load

# Load specific category
mix templates_data.load architecture_patterns

# Load all categories
mix templates_data.load all

# Usage
mix templates_data.load [dir_name | all]

Available directories:
  architecture_patterns
  frameworks
  quality_standards
  code_generation
  prompt_library
  code_snippets
  workflows
  htdag_strategies
  base
  partials
  rules
```

## Type Detection Priority

The loader automatically detects types in this order:

1. **Explicit type field** in JSON
   ```json
   {"type": "architecture_pattern"}
   ```

2. **Structure-based detection** from JSON keys
   - Has "indicators", "benefits", "concerns" → architecture_pattern
   - Has "steps", "inputs", "outputs" → code_generator
   - Has "code", "language" → code_snippet
   - Etc.

3. **Directory-based fallback**
   - `architecture_patterns/` → architecture_pattern
   - `code_generation/` → code_template
   - Etc.

4. **Default**
   - "generic_template"

## Key Features

✅ **Self-Documenting** - Types in JSON, not inferred
✅ **Hierarchical** - Parent-child relationships explicit
✅ **Zero-Config** - Add patterns via JSON only
✅ **Queryable** - JSONB operators for fast lookups
✅ **Bidirectional Sync** - Git ↔ PostgreSQL ↔ CentralCloud
✅ **Versioned** - Semantic versioning per template
✅ **Validated** - LLM team consensus included
✅ **Learnable** - Track usage, auto-promote successful patterns

## Next Steps

1. **Load templates**: `mix templates_data.load`
2. **Verify in DB**: Query knowledge_artifacts table
3. **Test hierarchy**: Query by parent_pattern
4. **Integrate**: Use in architecture detection system
5. **Track usage**: Monitor which patterns are used
6. **Learn patterns**: Auto-promote successful ones

## Documentation Files

- **TEMPLATE_HIERARCHY.md** - Complete hierarchy documentation
- **HIERARCHICAL_TEMPLATES_IMPLEMENTATION.md** - Implementation details
- **DATABASE_STRATEGY.md** - Storage strategy details
- **KNOWLEDGE_ARTIFACTS_SETUP.md** - Full knowledge base setup

## Questions?

See **templates_data/TEMPLATE_HIERARCHY.md** for comprehensive documentation.
