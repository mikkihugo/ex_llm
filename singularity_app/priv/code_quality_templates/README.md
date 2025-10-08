# Code Quality Templates & Graph Model System

This directory contains two coherent specification layers (migration in progress):

1. Base Quality Templates – focus on generation & review standards.
2. Graph-Enabled Templates – extend base with graph_model, rag_indexing, temporal & integrity semantics.

All tooling (validation, export, enrichment) is hosted via Mix tasks. Parsers & engines run as Rust NIFs, enabling low‑overhead live analysis.

## Available Templates (Production Focus)

### Elixir
- `elixir_production.json` - Maximum quality (docs, specs, tests, strict)
- `elixir_standard.json` - Good quality (docs, specs, basic tests)
- `elixir_draft.json` - Minimal quality (just working code)

### Rust
- `rust_production.json` - Maximum quality (docs, Result types, tests, clippy)
- `rust_standard.json` - Good quality
- `rust_draft.json` - Minimal quality

### TypeScript
- `typescript_production.json` - Maximum quality (JSDoc, types, tests)
- `typescript_standard.json` - Good quality
- `typescript_draft.json` - Minimal quality

## Template Structure (Baseline Quality Spec)

```json
{
  "name": "Language Quality Level",
  "language": "elixir",
  "quality_level": "production",
  "description": "...",

  "requirements": {
    "documentation": { ... },
    "type_specs": { ... },
    "error_handling": { ... },
    "testing": { ... },
    "code_style": { ... },
    "code_smells": { ... }
  },

  "prompts": {
    "code_generation": "...",
    "documentation": "...",
    "type_specs": "...",
    "tests": "..."
  },

  "examples": {
    "good_code": "...",
    "bad_code": "..."
  },

  "quality_checklist": [ ... ],

  "scoring_weights": { ... }
}
```

## Usage (Generation)

Templates are automatically loaded by `QualityCodeGenerator`:

```elixir
# Uses elixir_production.json template
{:ok, result} = QualityCodeGenerator.generate(
  task: "Parse JSON",
  language: "elixir",
  quality: :production
)
```

## Customization

1. **Edit existing templates** - Modify JSON files directly
2. **Add new templates** - Create new JSON files following the structure
3. **Custom prompts** - Edit the `prompts` section for your style
4. **Adjust weights** - Change `scoring_weights` to prioritize different quality aspects

## Template Fields

### `requirements`
Defines what the code must include (docs, specs, tests, etc.)

### `prompts`
LLM prompts used for generation. Available variables:
- `{task}` - The user's task description
- `{code}` - Existing code to enhance

### `examples`
Good and bad code examples to guide generation

### `quality_checklist`
Human-readable checklist for manual review

### `scoring_weights`
Weights for automated quality scoring (0.0-1.0)

## Adding a New Language (Base Quality)

Create a new template file, e.g., `python_production.json`:

```json
{
  "name": "Python Production Quality",
  "language": "python",
  "quality_level": "production",
  "requirements": {
    "documentation": {
      "docstrings": {
        "required": true,
        "format": "Google style"
      }
    },
    "type_hints": {
      "required": true
    },
    "testing": {
      "framework": "pytest",
      "coverage_target": 90
    }
  },
  "prompts": {
    "code_generation": "Generate production-quality Python code..."
  }
}
```

Then use it:

```elixir
QualityCodeGenerator.generate(
  task: "Parse JSON",
  language: "python",
  quality: :production
)
```

---

## Graph Model Additions (Spec Version >= 2.0)

Production templates now embed a `graph_model` block and related sections:

```jsonc
{
  "graph_model": {
    "node_types": [ { "type": "function", "required_fields": ["name","signature"], "doc_policy": "required" } ],
    "edge_types": [ { "type": "calls", "from": "function", "to": "function", "multiplicity": "many_to_many" } ],
    "extraction_rules": { "exclude_patterns": ["_test.exs"], "visibility": ["public","internal"] },
    "confidence_scoring": { "calls": { "base": 0.9, "adjusters": [ { "if": "dynamic_dispatch", "delta": -0.2 } ] } },
    "integrity_checks": [ { "code": "dangling_edge", "severity": "error", "description": "Edge references missing node" } ],
    "query_hints": ["list top unstable functions", "find undocumented public modules" ],
    "error_semantics": { "severity_levels": ["info","warn","error"], "categories": ["docs","design","performance"] },
    "temporal_rules": { "track": ["function","module"], "reset_on_signature_change": true }
  },
  "rag_indexing": {
    "chunking": { "strategy": "function", "max_tokens": 800 },
    "ranking_weights": { "doc_quality": 0.3, "centrality": 0.4, "recentness": 0.3 }
  },
  "semantic_anchors": ["MODULE_OVERVIEW","PUBLIC_API","ERROR_CONDITIONS"]
}
```

### Purpose
| Element | Purpose |
|---------|---------|
| node_types | Declares graph entity taxonomy per language |
| edge_types | Declares allowable relations (validated at export) |
| extraction_rules | Declarative filters / inclusion criteria |
| confidence_scoring | Weights & adjustments for relation certainty |
| integrity_checks | Declarative graph invariants to enforce |
| query_hints | Seed phrases to prime retrieval layer |
| error_semantics | Standard severity & category vocabulary |
| temporal_rules | Which entities get `first_seen` / `last_modified` |
| rag_indexing | Chunking & ranking inputs for embeddings |
| semantic_anchors | Stable segment markers inside docs/code |

---

## Validation

Mix task (planned):

```
mix quality.validate_templates [--json] [--ci]
```

Performs:
1. Load all `*_production.json`
2. Validate against `graph_model.schema.json`
3. Emit summary / JSON report
4. Exit non‑zero on schema or semantic violations

---

## Export Pipeline (Requires capabilities: graph)

Primary task (planned skeleton):
```
mix quality.export_graph [--languages=elixir,typescript] [--source=live|ingested]
```

Flow:
1. Validate templates (fail fast)
2. Load temporal cache (`.quality_graph/cache.json`)
3. Enumerate nodes via adapters:
   - live: invoke Rust parser NIFs (fresh AST)
   - ingested: read DB records (future path)
4. Normalize → hash → temporal merge
5. Emit streaming JSONL: `nodes.jsonl`, `edges.jsonl`
6. Run integrity checks → `integrity_report.json`
7. Derive `query_hints.json`, `export_meta.json`
8. Persist updated temporal cache

Output directory: `priv/quality_exports/` (configurable).

---

## Data Schemas (Initial)

### Node (JSONL line)
```json
{
  "id": "<sha256>",
  "language": "elixir",
  "kind": "function",
  "canonical_path": "lib/foo/bar.ex::Foo.bar/2",
  "name": "bar",
  "signature": "def bar(a, b) do",
  "file": "lib/foo/bar.ex",
  "span": { "start": 12, "end": 34 },
  "temporal": { "first_seen": "2025-10-08T12:00:00Z", "last_modified": "2025-10-08T12:00:00Z", "observation_count": 1 },
  "metadata": { "exported": true }
}
```

### Edge
```json
{
  "id": "<sha256_of_from+type+to>",
  "type": "calls",
  "from": "<node_id>",
  "to": "<node_id>",
  "confidence": 0.88,
  "metadata": {}
}
```

### Integrity Report
```json
{
  "generated_at": "2025-10-08T12:05:00Z",
  "summary": {"errors": 0, "warnings": 2},
  "items": [ {"code": "dangling_edge", "severity": "error", "edge_id": "..."} ]
}
```

---

## Signature Hashing
Canonical composition:
```
normalized = [language, kind, canonical_path, squashed_signature]\n  |> Enum.map(&String.downcase/1) (language, kind only)\n  |> Enum.join("|")
hash = :crypto.hash(:sha256, normalized) |> Base.encode16(case: :lower)
```
Retain full 64 hex chars initially; consider short form later.

### Test Vectors
Will live in `priv/test_vectors/hasher.json` to ensure cross-runtime determinism.

---

## Temporal Cache
Location: `.quality_graph/cache.json`

Entry schema:
```json
{
  "first_seen": "<iso8601>",
  "last_modified": "<iso8601>",
  "last_signature_hash": "<sha256>",
  "observation_count": 3
}
```

Update rules:
| Scenario | Action |
|----------|--------|
| New node | Initialize all fields, count=1 |
| Same signature | Increment count, keep last_modified |
| Changed signature | Update last_modified=now, increment count |

---

## Integrity Checks (Initial Set)
| Code | Severity | Description |
|------|----------|-------------|
| dangling_edge | error | Edge references missing node |
| undocumented_public | warn | Public node missing required docs |

Checks are defined or parameterized in each template’s `integrity_checks` block where feasible.

---

## Live (NIF) vs Ingested Mode
`--source=live` (default): parse on demand through Rust NIFs – freshest view, higher CPU.
`--source=ingested`: rely on previously persisted DB rows – faster, eventual consistency.

---

## Roadmap Phases (Condensed)

P0: Schema, validator, hashing, minimal exporter, temporal, 1 integrity rule
P1: Error taxonomy, RAG segmentation, embeddings staging, parallel export, query hints, collision detection
P2: Performance, advanced integrity set, drift reporting, tombstones, remediation engine

---

## Adding Graph Support for a New Language
1. Create/augment `*_production.json` with `graph_model` + `rag_indexing`.
2. Ensure parser (NIF or ingestion) populates required fields (name, signature, file, span, relations).
3. Run `mix quality.validate_templates` – fix schema errors.
4. Run `mix quality.export_graph --languages=<lang>` – inspect outputs.
5. Add integrity and error semantics gradually.

---

## Future Enhancements
- Embedding pipeline integration with `db_service`
- Telemetry dashboards (PromEx / OpenTelemetry)
- Spec drift reporter + CHANGELOG automation
- Deletion/tombstone propagation for historical graph diffs

---

## Contributing
Open a PR adjusting a template or adding a rule; always run:
```
mix quality.validate_templates
mix quality.export_graph --languages=elixir --source=live --dry-run
```
Include updated test vectors if hashing logic changes.

---

## Status

### Spec Versioning
- `spec_version` field denotes the capabilities level:
  - `1.0` => capabilities: ["quality"] only.
  - `2.0` => capabilities must include at least ["quality","graph"]. `"rag"` optional but recommended when rag_indexing present.
- Upgrade path: introduce new fields under feature flags; bump minor if additive, major if breaking structure.

### Manifest
`TEMPLATE_MANIFEST.json` centralizes declared templates, spec versions, and capability sets for validation & CI drift detection.
Initial migration toward graph-enabled templates is in progress. See `todo.md` in this directory for current task breakdown.
