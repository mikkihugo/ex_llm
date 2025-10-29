# Template System Architecture

## Overview

Single knowledge artifact system in CentralCloud PostgreSQL with pgvector, distributed via pgflow to Singularity instances as read-only mirrors.

## Architecture

```
templates_data/*.json (source)
    ↓
CentralCloud.TemplateService.sync_from_disk()
    ↓
PostgreSQL (templates table) + pgvector (2560-dim embeddings)
    ↓
pgflow.send_with_notify() → Singularity instances
    ↓
Logical Replication → Singularity DB (read-only replica)
```

## Database Schema

### CentralCloud (central_services DB)
- **Table**: `templates`
- **Primary Key**: `id` (string) + `version` (string)
- **Fields**: category, metadata (JSONB), content (JSONB), embedding (vector), etc.
- **Writable**: Yes (CentralCloud writes)

### Singularity (singularity DB)
- **Table**: `central_cloud_templates` (read-only replica)
- **Same schema** as CentralCloud templates
- **Writable**: NO (read-only mirror)
- **Sync**: Via PostgreSQL Logical Replication + pgflow notifications

## Artifact Categories

All artifact types stored in same table:

### Templates
- `base` - Base templates (base/)
- `bit` - Code bits (code_generation/bits/)
- `code_generation` - Code generation templates
- `code_snippet` - Code snippets
- `framework` - Framework patterns (frameworks/)
- `prompt` - Prompt templates (prompt_library/)
- `quality_standard` - Quality standards (quality_standards/)
- `workflow` - Workflow templates (workflows/)

### Models
- `model` - AI model definitions (from models.dev, YAML, custom)
- `complexity_model` - ML complexity prediction models

### Patterns
- `pattern` - General patterns
- `task_complexity` - Task complexity patterns/definitions

## Communication

- **CentralCloud → Singularity**: pgflow (not NATS)
  - Subjects: `template.sync.{category}.{id}`
  - Subjects: `central.template.get`, `central.template.search`, `central.template.store`
- **Replication**: PostgreSQL Logical Replication (automatic, real-time)
- **Read-only**: Singularity instances never write to templates

## Features

1. **Single Source of Truth**: CentralCloud PostgreSQL
2. **Semantic Search**: pgvector (2560-dim embeddings)
3. **Distribution**: pgflow notifications + logical replication
4. **Read-only Mirrors**: Singularity instances have local read-only copies
5. **Versioning**: Templates versioned, can query latest or specific version
6. **Unified Storage**: Templates, models, patterns all in one table
