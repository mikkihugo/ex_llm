# v2.2.0 Metadata Validation System

**Status**: ✅ IMPLEMENTED (2025-01-14)

## Overview

Singularity now validates v2.2.0 AI metadata completeness during code ingestion and provides tools to detect and fix incomplete documentation.

## What Gets Validated

For each ingested file, we check for:

### 1. Human Content (Top Section - For Humans)
- Quick Start examples
- Public API list
- Common errors and solutions
- Real usage examples

### 2. Separator
```markdown
---
## AI Navigation Metadata
*The sections below provide structured metadata for AI assistants, graph databases (Neo4j), and vector databases (pgvector).*
```

### 3. AI Metadata (Below Separator)
- **Module Identity JSON** - Structured metadata for disambiguation
- **Architecture Diagram (Mermaid)** - Visual call flow understanding
- **Call Graph (YAML)** - Machine-readable for Neo4j/graph DB
- **Anti-Patterns** - Explicit duplicate prevention
- **Search Keywords** - Vector search optimization

## Validation Levels

Each file receives a validation score (0.0 to 1.0) and level:

| Level | Score | Description |
|-------|-------|-------------|
| **complete** | 1.0 | All 7 requirements met |
| **partial** | 0.5-0.99 | Some AI metadata present |
| **legacy** | 0.01-0.49 | Has docs but not v2.2.0 structure |
| **missing** | 0.0 | No @moduledoc at all |

## Integration with HTDAGAutoBootstrap

### During Ingestion (Real-time)

When HTDAGAutoBootstrap ingests code during startup:

```elixir
# In HTDAGAutoBootstrap.persist_module_to_db/2
validation = MetadataValidator.validate_file(file_path, content)

# Store in database
attrs = %{
  metadata: %{
    # ... existing fields ...
    v2_2_validation: validation  # ✅ NEW
  }
}
```

### Startup Report

After ingestion completes, you'll see:

```
==================================================
v2.2.0 AI Metadata Validation Report
==================================================
  Total Files:    251
  ✓ Complete:     50 (20.0%)
  ⚠ Partial:      100 (40.0%)
  ✗ Missing:      101 (40.0%)
==================================================

Files needing attention:
  lib/singularity/agent.ex
    Level: partial, Score: 0.6
    Recommendations:
      - Add Call Graph (YAML)
      - Add Anti-Patterns section

Run `mix metadata.validate` for full report
Run `MetadataValidator.fix_incomplete_metadata/1` to auto-generate
```

## Manual Validation

### Basic Usage

```bash
# Validate all files in 'singularity' codebase
mix metadata.validate

# Validate specific codebase
mix metadata.validate my-project

# Show detailed report (all files with scores)
mix metadata.validate --detailed
```

### Auto-Fix

```bash
# Auto-generate missing metadata using LLM + HBS templates
mix metadata.validate --fix
```

## Handling Incomplete Metadata

Three strategies are available:

### 1. Auto-Generate (Recommended)

Uses SelfImprovingAgent + HBS templates to generate missing sections:

```elixir
# For a single file
MetadataValidator.fix_incomplete_metadata("lib/singularity/agent.ex")

# Batch fix via mix task
mix metadata.validate --fix
```

**How it works:**
1. Detect language (Elixir, Rust, Go, Java, JavaScript, Gleam)
2. Load appropriate HBS template (`templates_data/prompt_library/quality/{lang}/add-missing-docs-production.hbs`)
3. Call LLM with file content + template
4. Parse generated documentation
5. Update file with missing sections
6. Re-ingest to update database

### 2. Mark for Manual Review

Flag files for human review later:

```elixir
MetadataValidator.mark_for_review("lib/singularity/complex_module.ex",
  missing: [:call_graph, :architecture_diagram]
)
```

Creates TODO in database that SelfImprovingAgent picks up.

### 3. Mark as Legacy

Accept files as-is, skip v2.2.0 validation:

```elixir
MetadataValidator.mark_as_legacy("lib/singularity/old_module.ex")
```

Useful for:
- Third-party code
- Deprecated modules
- Test utilities

## Database Schema

Validation results are stored in `code_files.metadata` JSONB field:

```elixir
%{
  # ... existing metadata fields ...
  v2_2_validation: %{
    level: :partial,
    score: 0.6,
    has: %{
      human_content: true,
      separator: true,
      module_identity: true,
      architecture_diagram: false,  # Missing
      call_graph: false,            # Missing
      anti_patterns: true,
      search_keywords: true
    },
    missing: [:architecture_diagram, :call_graph],
    recommendations: [
      "Add Architecture Diagram (Mermaid)",
      "Add Call Graph (YAML)"
    ]
  }
}
```

## Querying Validation Results

### Find incomplete files

```elixir
alias Singularity.{Repo, Schemas.CodeFile}
import Ecto.Query

# Files with score < 1.0
incomplete_files =
  CodeFile
  |> where([cf], fragment("(metadata->'v2_2_validation'->>'score')::float < ?", 1.0))
  |> select([cf], %{
    path: cf.file_path,
    level: fragment("metadata->'v2_2_validation'->>'level'"),
    score: fragment("(metadata->'v2_2_validation'->>'score')::float")
  })
  |> Repo.all()
```

### Find files missing specific sections

```elixir
# Files missing call_graph
files_missing_call_graph =
  CodeFile
  |> where([cf],
    fragment("metadata->'v2_2_validation'->'has'->>'call_graph' = ?", "false")
  )
  |> Repo.all()
```

## HBS Templates

Each language has a production-quality template:

| Language | Template Path |
|----------|--------------|
| Elixir | `templates_data/prompt_library/quality/elixir/add-missing-docs-production.hbs` |
| Rust | `templates_data/prompt_library/quality/rust/add-missing-docs-production.hbs` |
| Go | `templates_data/prompt_library/quality/go/add-missing-docs-production.hbs` |
| Java | `templates_data/prompt_library/quality/java/add-missing-docs-production.hbs` |
| JavaScript | `templates_data/prompt_library/quality/javascript/add-missing-docs-production.hbs` |
| Gleam | (coming soon) |

All templates follow v2.2.0 structure:
1. Human content first
2. Clear separator
3. AI metadata below separator

## Telemetry Events

Validation integrates with existing telemetry:

```elixir
# During ingestion
:telemetry.execute([:htdag, :validation, :complete], %{
  total_files: 251,
  complete: 50,
  partial: 100,
  missing: 101
})
```

## Future Enhancements

### Planned Features

1. **Real-time Validation** - CodeFileWatcher validates on save
2. **Auto-fix on Save** - Optional auto-generation in editor
3. **Quality Scores** - Track metadata improvement over time
4. **Neo4j Integration** - Export call graphs to graph DB
5. **Vector DB Optimization** - Use keywords to improve embeddings

### Configuration Options

```elixir
# config/config.exs
config :singularity, Singularity.Analysis.MetadataValidator,
  # Automatically fix on ingestion
  auto_fix: false,

  # Validation level to trigger auto-fix
  min_score: 0.8,

  # Skip validation for these paths
  skip_paths: ["test/**", "deps/**"],

  # Mark as legacy automatically
  legacy_patterns: ["lib/singularity/deprecated/**"]
```

## Architecture

```
HTDAGAutoBootstrap (on startup)
  ↓ Scans files
HTDAGLearner.learn_codebase()
  ↓ Learns modules
persist_module_to_db(module)
  ↓ Validates during persist
MetadataValidator.validate_file(path, content)
  ↓ Checks 7 requirements
Returns: %{level: :partial, score: 0.6, missing: [...]}
  ↓ Stores in DB
code_files.metadata.v2_2_validation
  ↓ After ingestion
report_validation_statistics()
  ↓ Logs summary
"✓ Complete: 50 (20%), ⚠ Partial: 100 (40%), ✗ Missing: 101 (40%)"
```

## Implementation Files

| File | Purpose |
|------|---------|
| `lib/singularity/analysis/metadata_validator.ex` | Core validation logic |
| `lib/singularity/execution/planning/htdag_auto_bootstrap.ex` | Integration with ingestion |
| `lib/mix/tasks/metadata.validate.ex` | Mix task for manual validation |
| `templates_data/prompt_library/quality/*/add-missing-docs-production.hbs` | LLM templates |

## Summary

✅ **Complete validation system** for v2.2.0 metadata
✅ **Real-time validation** during code ingestion
✅ **Batch validation** via mix task
✅ **Auto-fix** using LLM + HBS templates
✅ **Database storage** for query and analysis
✅ **Telemetry integration** for observability

All files ingested by HTDAGAutoBootstrap now have validation metadata stored, ready for semantic search optimization, graph DB integration, and continuous improvement!
