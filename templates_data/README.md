# Singularity Template System

Centralized template repository for code generation, quality rules, and workflows.

## Structure

```
templates/
├─ code_generation/          # Code generation templates
│  ├─ quality/               # Quality rules (docs, specs, tests)
│  │  ├─ elixir.json         # Elixir quality standards
│  │  ├─ rust.json           # Rust quality standards
│  │  ├─ gleam.json          # Gleam quality standards
│  │  └─ ...
│  │
│  ├─ patterns/              # Proven code patterns
│  │  ├─ frameworks/         # Framework-specific patterns
│  │  │  ├─ phoenix.json     # Phoenix patterns
│  │  │  ├─ fastapi.json     # FastAPI patterns
│  │  │  └─ ...
│  │  ├─ messaging/          # Messaging patterns
│  │  │  ├─ nats-consumer.json
│  │  │  └─ kafka-producer.json
│  │  ├─ microservices/      # Microservice architectures
│  │  │  ├─ rust-api.json
│  │  │  └─ typescript-api.json
│  │  ├─ ai/                 # AI/ML patterns
│  │  ├─ cloud/              # Cloud provider patterns
│  │  └─ security/           # Security patterns
│  │
│  └─ bits/                  # Reusable code snippets
│     ├─ error-handling.json
│     ├─ logging.json
│     └─ testing.json
│
└─ workflows/                # SPARC/methodology workflows
   ├─ sparc-implementation.json
   └─ safe-iteration.json
```

## Template Schema

All templates follow a unified schema defined in `schema.json`:

```json
{
  "$schema": "https://singularity.dev/schemas/template/v1",
  "version": "1.0",
  "type": "code_pattern | quality_rule | workflow",
  "metadata": {
    "id": "unique-template-id",
    "name": "Human-readable name",
    "description": "What this template does",
    "language": "elixir | rust | typescript | python | ...",
    "tags": ["tag1", "tag2"],
    "created": "2025-10-06",
    "updated": "2025-10-06",
    "embedding": [...]  // Auto-populated by Qodo-Embed-1
  },
  "content": {
    "code": "// Implementation code",
    "tests": "// Test code",
    "docs": "// Documentation",
    "dependencies": ["dep1", "dep2"],
    "examples": ["// Example usage"]
  },
  "quality": {
    "rules": ["rule1", "rule2"],
    "score": 0.95,
    "validated": true
  },
  "usage": {
    "count": 0,
    "success_rate": 0.0,
    "last_used": null
  }
}
```

## Usage

### In Elixir

```elixir
# Get specific template
{:ok, template} = TemplateStore.get("elixir-nats-consumer")

# Search semantically (uses Qodo-Embed-1)
{:ok, templates} = TemplateStore.search("async worker pattern", language: "elixir", top_k: 5)

# Get best for task
{:ok, best} = TemplateStore.get_best_for_task("NATS consumer", "elixir", top_k: 3)

# Track usage
TemplateStore.record_usage("elixir-nats-consumer", success: true)
```

### In Rust

```rust
// Via template.rs
let template = load_template("rust-api-endpoint")?;
```

## Template Management

### Adding New Templates

1. Create JSON file in appropriate directory
2. Validate against schema: `mix templates.validate path/to/template.json`
3. Embed: `mix templates.embed path/to/template.json`
4. Template is now searchable!

### Updating Templates

1. Edit JSON file
2. Re-embed: `mix templates.reembed template_id`
3. Version is tracked automatically

### Migrating Old Templates

Old paths still work via symlinks:
- `singularity/priv/code_quality_templates/` → `templates/code_generation/quality/`
- `rust/tool_doc_index/templates/` → `templates/code_generation/patterns/`

## Indexing

All templates are automatically indexed with **Qodo-Embed-1**:

- Stored in PostgreSQL `templates` table
- Embeddings in `pgvector` column (1536 dims)
- Searchable via semantic similarity
- Usage tracking for continuous improvement

## Quality Standards

Templates must:
- ✅ Follow unified schema
- ✅ Include working code
- ✅ Include tests (for code_pattern type)
- ✅ Include documentation
- ✅ Have quality score ≥ 0.80
- ✅ Be validated before indexing

## Versioning

- Templates use semantic versioning
- Updates create new versions
- Old versions retained for 90 days
- Can rollback if template causes issues

## Migration Status

- [x] Directory structure created
- [ ] Schema defined
- [ ] TemplateStore module implemented
- [ ] Quality templates migrated
- [ ] Pattern templates migrated
- [ ] All templates embedded with Qodo-Embed-1
- [ ] Old paths symlinked

## References

- Schema: `schema.json`
- API: `singularity/lib/singularity/templates/template_store.ex`
- Database: `templates` table with pgvector
- Embedding: Uses Qodo-Embed-1 (CoIR: 68.53)
