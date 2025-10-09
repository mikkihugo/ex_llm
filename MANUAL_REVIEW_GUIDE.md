# Manual Review Guide - Template Conflicts

This guide provides detailed analysis of the 3 files that have conflicting versions between `rust/package/templates/` and `templates_data/`.

---

## File 1: `elixir-nats-consumer.json`

### Locations
- **Source:** `rust/package/templates/elixir-nats-consumer.json` (6,307 bytes)
- **Target:** `templates_data/code_generation/patterns/messaging/elixir-nats-consumer.json` (6,619 bytes)

### Schema Comparison

| Aspect | Source (Old) | Target (New) |
|--------|-------------|--------------|
| **Schema Format** | Custom workflow schema | Singularity Unified Schema v1.0 |
| **Top-level structure** | `id`, `name`, `steps`, `metadata`, `ai_signature`, `template_content` | `$schema`, `version`, `type`, `metadata`, `content`, `quality`, `usage`, `compatibility` |
| **Code organization** | Embedded in single `template_content` string | Structured: `code`, `tests`, `docs`, `examples` |
| **Metadata** | Basic + `performance` object | Extended + `tags`, `author`, `created`, `updated`, `embedding` |
| **Quality tracking** | None | `quality.rules`, `quality.score`, `quality.validated` |
| **Usage tracking** | None | `usage.count`, `usage.success_rate`, `usage.last_used` |
| **Tests** | Embedded in template | Separate `content.tests` field |
| **Documentation** | Embedded in template | Separate `content.docs` field |

### Key Differences

#### Source Format (Old)
```json
{
  "id": "elixir-nats-consumer",
  "name": "Elixir NATS Consumer Generator",
  "steps": [...],
  "detector_signatures": {
    "package_files": ["mix.exs"],
    "dependencies": ["gnat", "jason"]
  },
  "ai_signature": {
    "name": "elixir_nats_consumer",
    "inputs": {...},
    "outputs": {...}
  },
  "template_content": "defmodule {{ModuleName}}Consumer..."
}
```

**Characteristics:**
- Workflow-oriented (has `steps`)
- Focused on code generation flow
- Single blob of template content
- Includes detector signatures for auto-detection

#### Target Format (New)
```json
{
  "$schema": "https://singularity.dev/schemas/template/v1",
  "version": "1.0",
  "type": "code_pattern",
  "metadata": {
    "id": "elixir-nats-consumer",
    "tags": ["messaging", "nats", "async"]
  },
  "content": {
    "code": "defmodule MyApp.NatsConsumer...",
    "tests": "defmodule MyApp.NatsConsumerTest...",
    "docs": "@moduledoc...",
    "dependencies": ["gnat", "jason"],
    "examples": [...]
  },
  "quality": {
    "rules": ["must_have_docs", "must_have_specs"],
    "score": 0.95
  },
  "usage": {
    "count": 0,
    "success_rate": 0.0
  }
}
```

**Characteristics:**
- Pattern-oriented (reusable template)
- Structured content (code, tests, docs separate)
- Quality metrics and usage tracking
- Living knowledge base integration

### Code Content Differences

Both contain Elixir GenServer NATS consumer code, but:

| Aspect | Source | Target |
|--------|--------|--------|
| **Template variables** | Uses `{{ModuleName}}`, `{{subject}}` | Uses concrete example `MyApp.NatsConsumer` |
| **Error handling** | Basic with telemetry | Enhanced with DLQ (Dead Letter Queue) |
| **Reconnection** | Basic | Auto-reconnect with exponential backoff |
| **Concurrency** | Not addressed | Configurable with `Task.Supervisor` |
| **Testing approach** | Basic test structure | Comprehensive with DLQ and telemetry tests |

### Recommendation

**✅ KEEP TARGET** (templates_data/ version)

**Reasons:**
1. **Standard Schema:** Uses unified schema v1.0 (future-proof)
2. **Better Structure:** Separate code, tests, docs (maintainable)
3. **Quality Tracking:** Metrics for continuous improvement
4. **Living KB Integration:** Usage tracking enables learning
5. **More Complete:** Better error handling, DLQ, reconnection logic

**Action:**
```bash
# Keep target, remove source
rm rust/package/templates/elixir-nats-consumer.json
```

**Optional:** If you want to preserve the detector signatures and AI signature from the source, extract them and add to a separate detection configuration file.

---

## File 2: `schema.json`

### Locations
- **Source:** `rust/package/templates/schema.json` (4,900 bytes)
- **Target:** `templates_data/schema.json` (6,192 bytes)

### Purpose Comparison

**⚠️ IMPORTANT: These are DIFFERENT schemas for DIFFERENT purposes!**

| Aspect | Source | Target |
|--------|--------|--------|
| **Title** | "Technology Detection Template Schema" | "Singularity Template Schema" |
| **Purpose** | Define templates for DETECTING technologies | Define templates for CODE PATTERNS |
| **Scope** | Language/framework/database detection | All Singularity templates (patterns, quality, workflows) |
| **Use Case** | "Is this a Rust project? Django app?" | "Generate NATS consumer, API endpoint, etc." |

### Schema Structure

#### Source: Technology Detection Schema
```json
{
  "title": "Technology Detection Template Schema",
  "required": ["name", "category", "version", "detector_signatures"],
  "properties": {
    "name": "Technology name (e.g., 'Rust', 'Django')",
    "category": ["language", "framework", "database", "messaging"],
    "detector_signatures": {
      "config_files": ["Cargo.toml", "manage.py"],
      "file_extensions": [".rs", ".py"],
      "patterns": ["use std::.*", "from django"],
      "dependencies": {...}
    },
    "framework_hints": {...},
    "build_commands": {...},
    "llm_support": {
      "analysis_prompts": {...},
      "code_snippets": {...}
    }
  }
}
```

**Use case:** Auto-detect what technologies are used in a codebase

#### Target: Unified Template Schema
```json
{
  "title": "Singularity Template Schema",
  "required": ["version", "type", "metadata", "content"],
  "properties": {
    "type": ["code_pattern", "quality_rule", "workflow", "snippet"],
    "metadata": {
      "id": "unique-template-id",
      "language": "elixir",
      "tags": [...]
    },
    "content": {
      "code": "Implementation code",
      "tests": "Test code",
      "docs": "Documentation"
    },
    "quality": {...},
    "usage": {...}
  }
}
```

**Use case:** Define reusable code patterns, quality rules, and workflows

### Recommendation

**✅ BOTH are needed! They serve different purposes.**

**Actions:**

1. **Keep target as-is** (master unified schema)
   ```bash
   # No action needed for target
   ```

2. **Rename source** to avoid confusion
   ```bash
   mv rust/package/templates/schema.json \
      rust/package/templates/technology_detection_schema.json
   ```

3. **Optional:** Move to dedicated location
   ```bash
   # If you want to use this for technology detection
   mv rust/package/templates/technology_detection_schema.json \
      templates_data/detection/technology_detection_schema.json
   ```

### Summary

- **Target (`templates_data/schema.json`):** Master schema for ALL templates
- **Source (rename):** Specialized schema for technology detection
- **Conflict:** False alarm - different purposes, both valuable

---

## File 3: `workflows/sparc/3-architecture.json`

### Locations
- **Source:** `rust/package/templates/workflows/sparc/3-architecture.json` (2,117 bytes - v1.0.0)
- **Target:** `templates_data/workflows/sparc/3-architecture.json` (653 bytes - v2.0.0)

### Version Comparison

| Aspect | Source (v1.0.0) | Target (v2.0.0) |
|--------|----------------|-----------------|
| **Format** | Verbose, self-contained | Compact, compositional |
| **Size** | 2,117 bytes | 653 bytes (69% smaller) |
| **Approach** | Embedded instructions | References external bits |
| **Reusability** | Low (monolithic) | High (composable) |

### Structure Comparison

#### Source (v1.0.0) - Monolithic
```json
{
  "id": "sparc-architecture",
  "name": "SPARC Architecture Generator",
  "steps": [
    {
      "name": "analyze-pseudocode",
      "operation": {"type": "analyze", "analyze": "code-pattern"}
    },
    {
      "name": "generate-architecture",
      "operation": {"type": "generate", "generate": "sparc-architecture"}
    }
  ],
  "metadata": {
    "version": "1.0.0",
    "author": "SPARC Team",
    "created_at": "2024-01-15",
    "performance": {
      "avg_execution_time_ms": 300.0,
      "memory_usage_bytes": 6291456,
      "complexity": 8
    }
  },
  "ai_signature": {
    "name": "sparc_architecture_generator",
    "inputs": {
      "pseudocode": "...",
      "requirements": "...",
      "technology_stack": "...",
      "scalability_needs": "..."
    },
    "outputs": {
      "architecture_design": "...",
      "component_interfaces": "...",
      "technology_recommendations": "...",
      "scalability_plan": "..."
    }
  },
  "template_content": "Design system architecture based on..."
}
```

**Characteristics:**
- Self-contained (everything in one file)
- Detailed AI signature
- Embedded template content
- Performance metrics

#### Target (v2.0.0) - Compositional
```json
{
  "id": "sparc-architecture",
  "name": "SPARC Architecture Phase",
  "description": "Design system architecture and component interactions",
  "phase": 2,
  "depends_on": ["sparc-research"],
  "compose": ["bits/architecture/rest-api.md"],
  "metadata": {
    "version": "2.0.0",
    "tags": ["sparc", "architecture", "design"],
    "complexity": 8
  },
  "instruction": "Design comprehensive system architecture...",
  "outputs": [
    "component_diagram",
    "interface_definitions",
    "data_flow_design",
    "technology_stack",
    "scalability_plan"
  ]
}
```

**Characteristics:**
- Compositional (`compose` references external bits)
- Phase-based (part of sequential workflow)
- Dependencies (`depends_on`)
- Cleaner separation of concerns

### Key Evolution: Composition Pattern

**v1.0.0 (Source):**
- Everything embedded
- Hard to reuse architecture guidance
- Duplicate content across workflows

**v2.0.0 (Target):**
```json
"compose": ["bits/architecture/rest-api.md"]
```
- References reusable bits
- `bits/architecture/rest-api.md` contains architecture patterns
- Same bit can be used in multiple workflows
- Easy to update guidance in one place

### Recommendation

**✅ KEEP TARGET** (v2.0.0 - templates_data/ version)

**Reasons:**
1. **Version:** v2.0.0 is newer (explicit version bump)
2. **Composition:** Reuses bits (DRY principle)
3. **Maintainability:** Change bits, affect all workflows
4. **Size:** 69% smaller (simpler to understand)
5. **Pattern:** Matches other SPARC phases in templates_data/

**Action:**
```bash
# Keep target, remove source
rm rust/package/templates/workflows/sparc/3-architecture.json
```

**Note:** The source's detailed `ai_signature` and `performance` metrics could be valuable. If needed, extract this metadata to a separate analysis/documentation file.

---

## Summary of Recommendations

| File | Action | Reason |
|------|--------|--------|
| **elixir-nats-consumer.json** | Keep TARGET | Unified schema, better structure, quality tracking |
| **schema.json** | Keep BOTH (rename source) | Different purposes (detection vs patterns) |
| **3-architecture.json** | Keep TARGET | Newer version, compositional design |

---

## Quick Action Script

```bash
#!/bin/bash

# File 1: Remove source (keep target)
rm rust/package/templates/elixir-nats-consumer.json

# File 2: Rename source (keep both)
mv rust/package/templates/schema.json \
   rust/package/templates/technology_detection_schema.json

# File 3: Remove source (keep target)
rm rust/package/templates/workflows/sparc/3-architecture.json

echo "Manual review actions completed!"
```

Save as `resolve_conflicts.sh` and run after reviewing this guide.

---

## Post-Resolution Validation

After resolving conflicts:

```bash
# 1. Validate all templates
moon run templates_data:validate

# 2. Check for any JSON errors
find templates_data -name "*.json" -exec jq . {} \; > /dev/null

# 3. Sync to database
moon run templates_data:sync-to-db

# 4. Generate embeddings
moon run templates_data:embed-all

# 5. Verify in database
psql singularity -c "SELECT id, artifact_type, metadata->>'version' as version FROM knowledge_artifacts WHERE artifact_type IN ('code_pattern', 'workflow') ORDER BY artifact_type, id;"
```

---

## Questions?

If you're unsure about any recommendation:
1. Check the unified schema: `templates_data/schema.json`
2. Review CLAUDE.md section on "Living Knowledge Base"
3. Look at similar templates in templates_data/ for patterns
4. Test with: `moon run templates_data:validate`
