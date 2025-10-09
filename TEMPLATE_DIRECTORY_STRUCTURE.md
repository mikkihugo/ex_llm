# Template Directory Structure - After Migration

**Visual representation of `templates_data/` after merging from `rust/package/templates/`**

---

## Complete Directory Tree

```
templates_data/
│
├── schema.json                          # Master unified schema (KEEP)
│
├── prompt_library/
│   ├── framework_discovery.json         # Existing
│   ├── version_detection.json           # Existing
│   ├── beast-mode-prompt.json           # NEW ✨
│   ├── cli-llm-system-prompt.json       # NEW ✨
│   ├── initialize-prompt.json           # NEW ✨
│   ├── plan-mode-prompt.json            # NEW ✨
│   ├── summarize-prompt.json            # NEW ✨
│   ├── system-prompt.json               # NEW ✨
│   └── title-prompt.json                # NEW ✨
│
├── workflows/
│   └── sparc/
│       ├── 0-research.json              # NEW ✨ (completes sequence!)
│       ├── 1-specification.json         # Existing (identical)
│       ├── 2-pseudocode.json            # Existing (identical)
│       ├── 3-architecture.json          # Existing (v2.0.0 - kept)
│       ├── 3a-security.json             # Existing
│       ├── 3b-performance.json          # Existing
│       ├── 4-architecture.json          # NEW ✨
│       ├── 4-refinement.json            # Existing
│       ├── 5-implementation.json        # Existing
│       ├── 5-security.json              # NEW ✨
│       ├── 6-performance.json           # NEW ✨
│       ├── 7-refinement.json            # NEW ✨
│       └── 8-implementation.json        # NEW ✨
│
├── code_generation/
│   │
│   ├── quality/                         # Existing directory
│   │   ├── elixir_standard.json
│   │   ├── g16_gleam_production.json
│   │   ├── go_production.json
│   │   ├── java_production.json
│   │   ├── javascript_production.json
│   │   ├── tsx_component_production.json
│   │   ├── architecture.json
│   │   ├── registry.json
│   │   ├── graph_model.schema.json
│   │   └── TEMPLATE_MANIFEST.json
│   │
│   ├── patterns/
│   │   │
│   │   ├── detection/                   # Existing
│   │   │   └── build-tool-detection.json
│   │   │
│   │   ├── workspaces/                  # Existing
│   │   │   ├── bun-workspace.json
│   │   │   ├── deno-workspace.json
│   │   │   ├── elixir-umbrella-workspace.json
│   │   │   ├── erlang-rebar-workspace.json
│   │   │   ├── gleam-workspace.json
│   │   │   ├── node-npm-workspace.json
│   │   │   ├── rust-cargo-workspace.json
│   │   │   └── singularity-moon-workspace.json
│   │   │
│   │   ├── messaging/
│   │   │   ├── elixir-nats-consumer.json    # Existing (kept - unified schema)
│   │   │   ├── kafka.json                   # NEW ✨
│   │   │   ├── nats.json                    # NEW ✨
│   │   │   ├── rabbitmq.json                # NEW ✨
│   │   │   └── redis.json                   # NEW ✨
│   │   │
│   │   ├── cloud/                       # NEW DIRECTORY ✨
│   │   │   ├── aws.json                 # NEW ✨
│   │   │   ├── azure.json               # NEW ✨
│   │   │   └── gcp.json                 # NEW ✨
│   │   │
│   │   ├── ai/                          # NEW DIRECTORY ✨
│   │   │   ├── crewai.json              # NEW ✨
│   │   │   ├── langchain.json           # NEW ✨
│   │   │   └── mcp.json                 # NEW ✨
│   │   │
│   │   ├── monitoring/                  # NEW DIRECTORY ✨
│   │   │   ├── grafana.json             # NEW ✨
│   │   │   ├── jaeger.json              # NEW ✨
│   │   │   ├── opentelemetry.json       # NEW ✨
│   │   │   └── prometheus.json          # NEW ✨
│   │   │
│   │   ├── security/                    # NEW DIRECTORY ✨
│   │   │   ├── falco.json               # NEW ✨
│   │   │   └── opa.json                 # NEW ✨
│   │   │
│   │   ├── languages/                   # NEW DIRECTORY ✨
│   │   │   ├── elixir.json              # NEW ✨
│   │   │   ├── go.json                  # NEW ✨
│   │   │   ├── javascript.json          # NEW ✨
│   │   │   ├── python.json              # NEW ✨
│   │   │   ├── rust.json                # NEW ✨
│   │   │   ├── typescript.json          # NEW ✨
│   │   │   │
│   │   │   ├── python/
│   │   │   │   ├── _base.json           # NEW ✨
│   │   │   │   └── fastapi/
│   │   │   │       └── crud.json        # NEW ✨
│   │   │   │
│   │   │   ├── rust/
│   │   │   │   ├── _base.json           # NEW ✨
│   │   │   │   └── microservice.json    # NEW ✨
│   │   │   │
│   │   │   └── typescript/
│   │   │       └── _base.json           # NEW ✨
│   │   │
│   │   ├── UNIFIED_SCHEMA.json          # NEW ✨ (documentation)
│   │   ├── gleam-nats-consumer.json     # NEW ✨
│   │   ├── python-django.json           # NEW ✨
│   │   ├── python-fastapi.json          # NEW ✨
│   │   ├── rust-api-endpoint.json       # NEW ✨
│   │   ├── rust-microservice.json       # NEW ✨
│   │   ├── rust-nats-consumer.json      # NEW ✨
│   │   ├── sparc-implementation.json    # NEW ✨
│   │   ├── typescript-api-endpoint.json # NEW ✨
│   │   └── typescript-microservice.json # NEW ✨
│   │
│   ├── bits/                            # Existing directory
│   │   ├── architecture/
│   │   │   └── rest-api.md              # Existing (identical)
│   │   ├── performance/
│   │   │   ├── async-optimization.md    # Existing (identical)
│   │   │   └── caching.md               # Existing (identical)
│   │   ├── security/
│   │   │   ├── input-validation.md      # Existing (identical)
│   │   │   ├── oauth2.md                # Existing (identical)
│   │   │   └── rate-limiting.md         # Existing (identical)
│   │   └── testing/
│   │       └── pytest-async.md          # Existing (identical)
│   │
│   └── code_snippets/                   # Existing
│       ├── fastapi/
│       │   └── authenticated_api_endpoint.json
│       └── phoenix/
│           └── authenticated_json_api.json
│
└── frameworks/                          # Existing (symlinked from rust/package/templates)
    ├── express.json
    ├── fastapi.json
    ├── nestjs.json
    ├── nextjs.json
    ├── phoenix.json
    ├── phoenix_enhanced.json
    └── react.json
```

---

## Summary Statistics

### Files by Status

| Status | Count | Symbol |
|--------|-------|--------|
| New files | 50 | ✨ |
| Existing (kept) | 9 | ✓ |
| Existing (other) | ~25+ | - |

### New Directories Created

```bash
templates_data/code_generation/patterns/cloud/           # 3 files
templates_data/code_generation/patterns/ai/              # 3 files
templates_data/code_generation/patterns/monitoring/      # 4 files
templates_data/code_generation/patterns/security/        # 2 files
templates_data/code_generation/patterns/languages/       # 11 files (6 + 5 structured)
```

### Files by Category

| Category | New | Existing | Total |
|----------|-----|----------|-------|
| **Prompts** | 7 | 2 | 9 |
| **SPARC Workflows** | 6 | 5 | 11 |
| **Cloud** | 3 | 0 | 3 |
| **AI** | 3 | 0 | 3 |
| **Messaging** | 4 | 1 | 5 |
| **Monitoring** | 4 | 0 | 4 |
| **Security** | 2 | 0 | 2 |
| **Languages** | 11 | 0 | 11 |
| **Root Patterns** | 10 | 0 | 10 |
| **Bits (MD)** | 0 | 7 | 7 |

---

## Categorization Logic

### Where Files Go

**System Prompts → `prompt_library/`**
- beast-mode, cli-llm, initialize, plan-mode, summarize, system, title

**SPARC Workflows → `workflows/sparc/`**
- Phases 0-8 (sequential workflow)

**Infrastructure → `code_generation/patterns/{category}/`**
- **Cloud:** AWS, Azure, GCP
- **AI:** CrewAI, LangChain, MCP
- **Messaging:** Kafka, NATS, RabbitMQ, Redis
- **Monitoring:** Grafana, Jaeger, OpenTelemetry, Prometheus
- **Security:** Falco, OPA

**Languages → `code_generation/patterns/languages/`**
- Single files: elixir.json, go.json, etc.
- Structured: python/, rust/, typescript/ (with _base.json and subdirs)

**Application Templates → `code_generation/patterns/`**
- Microservices, API endpoints, consumers
- Framework-specific implementations

**Reusable Bits → `code_generation/bits/`**
- Architecture, performance, security, testing
- Markdown files for composition

---

## Access Patterns

### By Technology Stack

**Looking for Rust?**
```bash
templates_data/code_generation/patterns/languages/rust.json
templates_data/code_generation/patterns/languages/rust/_base.json
templates_data/code_generation/patterns/languages/rust/microservice.json
templates_data/code_generation/patterns/rust-api-endpoint.json
templates_data/code_generation/patterns/rust-microservice.json
templates_data/code_generation/patterns/rust-nats-consumer.json
```

**Looking for Python?**
```bash
templates_data/code_generation/patterns/languages/python.json
templates_data/code_generation/patterns/languages/python/_base.json
templates_data/code_generation/patterns/languages/python/fastapi/crud.json
templates_data/code_generation/patterns/python-django.json
templates_data/code_generation/patterns/python-fastapi.json
```

**Looking for TypeScript?**
```bash
templates_data/code_generation/patterns/languages/typescript.json
templates_data/code_generation/patterns/languages/typescript/_base.json
templates_data/code_generation/patterns/typescript-api-endpoint.json
templates_data/code_generation/patterns/typescript-microservice.json
```

### By Use Case

**Building an API?**
```bash
templates_data/code_generation/patterns/rust-api-endpoint.json
templates_data/code_generation/patterns/typescript-api-endpoint.json
templates_data/code_generation/patterns/python-fastapi.json
templates_data/code_generation/patterns/python-django.json
templates_data/frameworks/fastapi.json
templates_data/frameworks/express.json
```

**Building a Microservice?**
```bash
templates_data/code_generation/patterns/rust-microservice.json
templates_data/code_generation/patterns/typescript-microservice.json
templates_data/code_generation/patterns/languages/rust/microservice.json
```

**Working with NATS?**
```bash
templates_data/code_generation/patterns/messaging/nats.json
templates_data/code_generation/patterns/messaging/elixir-nats-consumer.json
templates_data/code_generation/patterns/rust-nats-consumer.json
templates_data/code_generation/patterns/gleam-nats-consumer.json
```

**Setting up Cloud Infrastructure?**
```bash
templates_data/code_generation/patterns/cloud/aws.json
templates_data/code_generation/patterns/cloud/azure.json
templates_data/code_generation/patterns/cloud/gcp.json
```

**Adding Monitoring?**
```bash
templates_data/code_generation/patterns/monitoring/grafana.json
templates_data/code_generation/patterns/monitoring/prometheus.json
templates_data/code_generation/patterns/monitoring/jaeger.json
templates_data/code_generation/patterns/monitoring/opentelemetry.json
```

---

## Search & Discovery

### Semantic Search (After Embeddings)

Once embeddings are generated, you can search semantically:

```elixir
# Search all templates
Singularity.Knowledge.ArtifactStore.search(
  "async message consumer with error handling",
  top_k: 5
)

# Filter by language
Singularity.Knowledge.ArtifactStore.search(
  "microservice with metrics",
  language: "rust",
  top_k: 3
)
```

### JSONB Queries

For structured queries:

```sql
-- Find all messaging patterns
SELECT id, metadata->>'name'
FROM knowledge_artifacts
WHERE metadata->'tags' ? 'messaging';

-- Find Rust templates
SELECT id, metadata->>'name'
FROM knowledge_artifacts
WHERE metadata->>'language' = 'rust';

-- Find high-quality patterns
SELECT id, metadata->>'name', quality->>'score'
FROM knowledge_artifacts
WHERE (quality->>'score')::float > 0.9;
```

---

## Maintenance

### Adding New Templates

When adding templates, follow this structure:

1. **Determine category:**
   - System prompt? → `prompt_library/`
   - Workflow? → `workflows/{workflow-name}/`
   - Language-specific? → `code_generation/patterns/languages/{lang}/`
   - Infrastructure? → `code_generation/patterns/{category}/`
   - Application? → `code_generation/patterns/`

2. **Use unified schema:** Follow `templates_data/schema.json`

3. **Validate:** `moon run templates_data:validate`

4. **Sync:** `moon run templates_data:sync-to-db`

### Updating Templates

1. Edit JSON file directly
2. Validate: `jq empty path/to/file.json`
3. Re-sync: `moon run templates_data:sync-to-db`
4. Regenerate embedding if content changed: `moon run templates_data:embed-all`

---

## Notes

- **Symlink:** `frameworks/` is symlinked from `rust/package/templates/framework`
- **Schema:** All templates use unified schema v1.0 (`templates_data/schema.json`)
- **Composition:** SPARC workflows v2.0 reference bits/ for reusable content
- **Living KB:** Templates sync Git ↔ PostgreSQL with usage tracking

---

**Ready to migrate?** → See [TEMPLATE_MERGE_README.md](TEMPLATE_MERGE_README.md)
