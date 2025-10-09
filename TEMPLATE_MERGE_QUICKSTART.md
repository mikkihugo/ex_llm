# Template Merge - Quick Start Guide

**One-page guide to merge templates from `rust/package/templates/` to `templates_data/`**

---

## TL;DR

```bash
# 1. Resolve conflicts (removes 2 files, renames 1)
./resolve_conflicts.sh

# 2. Copy 50 unique files
./migrate_templates.sh

# 3. Validate
moon run templates_data:validate

# 4. Done! Archive source if you want
mv rust/package/templates rust/package/templates.archived
```

---

## What Gets Copied (50 files)

| Category | Count | Destination |
|----------|-------|-------------|
| System Prompts | 7 | `prompt_library/` |
| SPARC Workflows | 6 | `workflows/sparc/` |
| Cloud Templates | 3 | `code_generation/patterns/cloud/` |
| AI Frameworks | 3 | `code_generation/patterns/ai/` |
| Messaging | 4 | `code_generation/patterns/messaging/` |
| Monitoring | 4 | `code_generation/patterns/monitoring/` |
| Security | 2 | `code_generation/patterns/security/` |
| Languages | 11 | `code_generation/patterns/languages/` |
| Root Templates | 10 | `code_generation/patterns/` |

---

## What Gets Skipped (9 files)

All bits/ files (7 markdown) and 2 SPARC workflows already exist and are identical.

---

## What Needs Manual Review (3 files)

| File | Decision | Reason |
|------|----------|--------|
| `elixir-nats-consumer.json` | **Remove source** | Target uses unified schema v1.0 |
| `schema.json` | **Rename source** | Different purposes (both needed) |
| `workflows/sparc/3-architecture.json` | **Remove source** | Target is v2.0.0 (compositional) |

---

## File Locations After Migration

```
templates_data/
├── prompt_library/
│   ├── beast-mode-prompt.json          # NEW
│   ├── cli-llm-system-prompt.json      # NEW
│   ├── initialize-prompt.json          # NEW
│   ├── plan-mode-prompt.json           # NEW
│   ├── summarize-prompt.json           # NEW
│   ├── system-prompt.json              # NEW
│   └── title-prompt.json               # NEW
│
├── workflows/sparc/
│   ├── 0-research.json                 # NEW
│   ├── 1-specification.json            # Exists (identical)
│   ├── 2-pseudocode.json               # Exists (identical)
│   ├── 3-architecture.json             # Exists (keep target v2.0.0)
│   ├── 4-architecture.json             # NEW
│   ├── 5-security.json                 # NEW
│   ├── 6-performance.json              # NEW
│   ├── 7-refinement.json               # NEW
│   └── 8-implementation.json           # NEW
│
└── code_generation/
    ├── patterns/
    │   ├── cloud/                      # NEW directory
    │   │   ├── aws.json
    │   │   ├── azure.json
    │   │   └── gcp.json
    │   │
    │   ├── ai/                         # NEW directory
    │   │   ├── crewai.json
    │   │   ├── langchain.json
    │   │   └── mcp.json
    │   │
    │   ├── messaging/
    │   │   ├── elixir-nats-consumer.json   # Exists (keep)
    │   │   ├── kafka.json                  # NEW
    │   │   ├── nats.json                   # NEW
    │   │   ├── rabbitmq.json               # NEW
    │   │   └── redis.json                  # NEW
    │   │
    │   ├── monitoring/                 # NEW directory
    │   │   ├── grafana.json
    │   │   ├── jaeger.json
    │   │   ├── opentelemetry.json
    │   │   └── prometheus.json
    │   │
    │   ├── security/                   # NEW directory
    │   │   ├── falco.json
    │   │   └── opa.json
    │   │
    │   ├── languages/                  # NEW directory
    │   │   ├── elixir.json
    │   │   ├── go.json
    │   │   ├── javascript.json
    │   │   ├── python.json
    │   │   ├── python/
    │   │   │   ├── _base.json
    │   │   │   └── fastapi/
    │   │   │       └── crud.json
    │   │   ├── rust.json
    │   │   ├── rust/
    │   │   │   ├── _base.json
    │   │   │   └── microservice.json
    │   │   ├── typescript.json
    │   │   └── typescript/
    │   │       └── _base.json
    │   │
    │   ├── gleam-nats-consumer.json    # NEW
    │   ├── python-django.json          # NEW
    │   ├── python-fastapi.json         # NEW
    │   ├── rust-api-endpoint.json      # NEW
    │   ├── rust-microservice.json      # NEW
    │   ├── rust-nats-consumer.json     # NEW
    │   ├── sparc-implementation.json   # NEW
    │   ├── typescript-api-endpoint.json # NEW
    │   ├── typescript-microservice.json # NEW
    │   └── UNIFIED_SCHEMA.json         # NEW (documentation)
    │
    └── bits/
        ├── architecture/
        │   └── rest-api.md             # Exists (identical)
        ├── performance/
        │   ├── async-optimization.md   # Exists (identical)
        │   └── caching.md              # Exists (identical)
        ├── security/
        │   ├── input-validation.md     # Exists (identical)
        │   ├── oauth2.md               # Exists (identical)
        │   └── rate-limiting.md        # Exists (identical)
        └── testing/
            └── pytest-async.md         # Exists (identical)
```

---

## Post-Migration Checklist

- [ ] Run `./resolve_conflicts.sh` (resolves 3 conflicts)
- [ ] Run `./migrate_templates.sh` (copies 50 files)
- [ ] Validate JSON: `moon run templates_data:validate`
- [ ] Sync to DB: `moon run templates_data:sync-to-db`
- [ ] Generate embeddings: `moon run templates_data:embed-all`
- [ ] Test semantic search in DB
- [ ] Archive source: `mv rust/package/templates rust/package/templates.archived`
- [ ] Commit changes: `git add templates_data && git commit -m "feat: merge templates from rust/package"`

---

## Validation Commands

```bash
# Check all JSON files are valid
find templates_data -name "*.json" -exec jq empty {} \;

# Count files by category
echo "Prompt Library:"; ls -1 templates_data/prompt_library/*.json | wc -l
echo "SPARC Workflows:"; ls -1 templates_data/workflows/sparc/*.json | wc -l
echo "Cloud Patterns:"; ls -1 templates_data/code_generation/patterns/cloud/*.json | wc -l
echo "AI Patterns:"; ls -1 templates_data/code_generation/patterns/ai/*.json | wc -l
echo "Messaging:"; ls -1 templates_data/code_generation/patterns/messaging/*.json | wc -l
echo "Monitoring:"; ls -1 templates_data/code_generation/patterns/monitoring/*.json | wc -l
echo "Security:"; ls -1 templates_data/code_generation/patterns/security/*.json | wc -l

# Check database
psql singularity -c "SELECT artifact_type, COUNT(*) FROM knowledge_artifacts GROUP BY artifact_type ORDER BY artifact_type;"
```

---

## Troubleshooting

**"File already exists" warnings during migration:**
- Safe to ignore - script skips existing files
- Check `SKIPPED` count in summary

**JSON validation errors:**
- Check which file: `moon run templates_data:validate`
- Validate single file: `jq empty templates_data/path/to/file.json`
- Fix syntax errors manually

**Database sync fails:**
- Check PostgreSQL is running: `psql singularity -c "SELECT 1;"`
- Check schema: `psql singularity -c "\d knowledge_artifacts"`
- Re-run migration: `mix knowledge.migrate`

**Embedding generation slow:**
- Normal - generates 1536-dim vectors for each template
- Run in background: `nohup moon run templates_data:embed-all &`
- Check progress: `psql singularity -c "SELECT COUNT(*) FROM knowledge_artifacts WHERE embedding IS NOT NULL;"`

---

## Key Decisions Summary

1. **Unified Schema:** All new templates use `templates_data/schema.json` (v1.0)
2. **Composition:** SPARC workflows v2.0 reference reusable bits/
3. **Living KB:** Templates sync Git ↔ PostgreSQL with usage tracking
4. **Quality First:** Templates require quality.score >= 0.80 for production

---

## Need Help?

- **Detailed analysis:** See `TEMPLATE_MERGE_FINAL_REPORT.md`
- **Manual review guide:** See `MANUAL_REVIEW_GUIDE.md`
- **Architecture docs:** See `CLAUDE.md` (Living Knowledge Base section)
- **Schema reference:** See `templates_data/schema.json`

---

**Ready? Let's go!**

```bash
./resolve_conflicts.sh && ./migrate_templates.sh
```
