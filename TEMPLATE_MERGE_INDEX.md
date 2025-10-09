# Template Merge Documentation - Index

**Complete guide to merging templates from `rust/package/templates/` into `templates_data/`**

---

## 📚 Document Overview

This directory contains comprehensive documentation for the template merge operation:

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **[TEMPLATE_MERGE_QUICKSTART.md](TEMPLATE_MERGE_QUICKSTART.md)** | Quick reference, one-page guide | Start here! TL;DR version |
| **[TEMPLATE_MERGE_FINAL_REPORT.md](TEMPLATE_MERGE_FINAL_REPORT.md)** | Detailed analysis, complete findings | Full context and reasoning |
| **[MANUAL_REVIEW_GUIDE.md](MANUAL_REVIEW_GUIDE.md)** | In-depth comparison of conflicting files | Understand the 3 conflicts |
| **[template_merge_report.md](template_merge_report.md)** | Auto-generated comparison report | Raw data from comparison script |

---

## 🚀 Quick Start (5 Minutes)

```bash
# 1. Read the quickstart
cat TEMPLATE_MERGE_QUICKSTART.md

# 2. Resolve 3 conflicts (automatic)
./resolve_conflicts.sh

# 3. Copy 50 unique files (automatic)
./migrate_templates.sh

# 4. Validate
moon run templates_data:validate

# 5. Done!
```

---

## 📊 Migration Statistics

**Total files analyzed:** 62 (55 JSON + 7 Markdown)

| Status | Count | Action Required |
|--------|-------|----------------|
| ✅ Identical | 9 | None (skip) |
| ⚠️ Different | 3 | Manual review (automated) |
| 🆕 Unique | 50 | Copy (automated) |

**Size:** ~123 KB of new templates

---

## 🛠️ Scripts Provided

All scripts are executable and ready to run:

| Script | Purpose | Output |
|--------|---------|--------|
| `resolve_conflicts.sh` | Resolve 3 conflicting files | Removes 2, renames 1 |
| `migrate_templates.sh` | Copy 50 unique files | Creates directories, copies files |
| `compare_templates.sh` | Generate comparison report | Creates `template_merge_report.md` |
| `compare_bits.sh` | Compare bits/ directory | Verifies markdown files |

---

## 📁 What Gets Added

### New Categories (Create Directories)
- `templates_data/code_generation/patterns/cloud/` - AWS, Azure, GCP
- `templates_data/code_generation/patterns/ai/` - CrewAI, LangChain, MCP
- `templates_data/code_generation/patterns/monitoring/` - Grafana, Prometheus, etc.
- `templates_data/code_generation/patterns/security/` - Falco, OPA
- `templates_data/code_generation/patterns/languages/` - Language-specific patterns

### New Files by Category

**System Prompts (7):**
- beast-mode-prompt.json
- cli-llm-system-prompt.json
- initialize-prompt.json
- plan-mode-prompt.json
- summarize-prompt.json
- system-prompt.json
- title-prompt.json

**SPARC Workflows (6):**
- 0-research.json (NEW - completes the sequence)
- 4-architecture.json
- 5-security.json
- 6-performance.json
- 7-refinement.json
- 8-implementation.json

**Infrastructure Templates (16):**
- Cloud: aws.json, azure.json, gcp.json
- AI: crewai.json, langchain.json, mcp.json
- Messaging: kafka.json, nats.json, rabbitmq.json, redis.json
- Monitoring: grafana.json, jaeger.json, opentelemetry.json, prometheus.json
- Security: falco.json, opa.json

**Language Templates (11):**
- Single files: elixir.json, go.json, javascript.json, python.json, rust.json, typescript.json
- Structured: python/_base.json, python/fastapi/crud.json, rust/_base.json, rust/microservice.json, typescript/_base.json

**Application Templates (10):**
- gleam-nats-consumer.json
- python-django.json
- python-fastapi.json
- rust-api-endpoint.json
- rust-microservice.json
- rust-nats-consumer.json
- sparc-implementation.json
- typescript-api-endpoint.json
- typescript-microservice.json
- UNIFIED_SCHEMA.json (documentation)

---

## ⚠️ Files Requiring Decisions (Resolved Automatically)

### 1. elixir-nats-consumer.json
- **Decision:** Keep target (templates_data/ version)
- **Reason:** Uses unified schema v1.0, better structure
- **Action:** `resolve_conflicts.sh` removes source

### 2. schema.json
- **Decision:** Keep both (rename source)
- **Reason:** Different purposes (detection vs patterns)
- **Action:** `resolve_conflicts.sh` renames to `technology_detection_schema.json`

### 3. workflows/sparc/3-architecture.json
- **Decision:** Keep target (v2.0.0)
- **Reason:** Newer version with compositional design
- **Action:** `resolve_conflicts.sh` removes source

---

## 🔍 Deep Dive Documents

### For Complete Analysis
→ **[TEMPLATE_MERGE_FINAL_REPORT.md](TEMPLATE_MERGE_FINAL_REPORT.md)**
- Executive summary
- Detailed file-by-file breakdown
- Size and category statistics
- Directory structure
- Post-migration checklist

### For Understanding Conflicts
→ **[MANUAL_REVIEW_GUIDE.md](MANUAL_REVIEW_GUIDE.md)**
- Side-by-side schema comparisons
- Key differences explained
- Code content analysis
- Recommendations with reasoning
- Quick action scripts

### For Quick Reference
→ **[TEMPLATE_MERGE_QUICKSTART.md](TEMPLATE_MERGE_QUICKSTART.md)**
- One-page TL;DR
- File location map
- Validation commands
- Troubleshooting tips

---

## 🎯 Recommended Reading Order

### First Time? Start Here:
1. **TEMPLATE_MERGE_QUICKSTART.md** (5 min) - Get oriented
2. Run `./resolve_conflicts.sh` (30 sec)
3. Run `./migrate_templates.sh` (30 sec)
4. Run `moon run templates_data:validate` (1 min)

### Want Full Context?
1. **TEMPLATE_MERGE_FINAL_REPORT.md** (15 min) - Complete picture
2. **MANUAL_REVIEW_GUIDE.md** (10 min) - Understand decisions
3. Review scripts: `cat migrate_templates.sh`

### Troubleshooting?
1. **TEMPLATE_MERGE_QUICKSTART.md** - Troubleshooting section
2. **MANUAL_REVIEW_GUIDE.md** - Post-resolution validation
3. Check logs from scripts

---

## 🔧 Post-Migration Tasks

### Immediate (Required)
```bash
# Validate JSON syntax
moon run templates_data:validate

# Sync to PostgreSQL
moon run templates_data:sync-to-db

# Generate embeddings
moon run templates_data:embed-all
```

### Follow-up (Recommended)
```bash
# Test semantic search
psql singularity -c "SELECT id, artifact_type FROM knowledge_artifacts WHERE artifact_type = 'code_pattern' ORDER BY id;"

# Archive source
mv rust/package/templates rust/package/templates.archived

# Commit changes
git add templates_data
git commit -m "feat: merge 50 templates from rust/package

- Add 7 system prompts to prompt_library
- Complete SPARC workflow (phases 0-8)
- Add cloud, AI, monitoring, security patterns
- Add language-specific templates
- Resolve schema conflicts (unified v1.0)
"
```

---

## 🧪 Validation & Testing

### JSON Validation
```bash
# All files
find templates_data -name "*.json" -exec jq empty {} \;

# Single file
jq empty templates_data/prompt_library/beast-mode-prompt.json
```

### Database Verification
```bash
# Check imports
psql singularity -c "SELECT artifact_type, COUNT(*) FROM knowledge_artifacts GROUP BY artifact_type;"

# Check embeddings
psql singularity -c "SELECT COUNT(*) FROM knowledge_artifacts WHERE embedding IS NOT NULL;"

# Test semantic search
psql singularity -c "SELECT id, metadata->>'name' FROM knowledge_artifacts WHERE artifact_type = 'code_pattern' LIMIT 5;"
```

### File Counts
```bash
# Should match expected counts
ls -1 templates_data/prompt_library/*.json | wc -l              # Should be 9+ (7 new)
ls -1 templates_data/workflows/sparc/*.json | wc -l             # Should be 9 (6 new)
ls -1 templates_data/code_generation/patterns/cloud/*.json | wc -l    # Should be 3
ls -1 templates_data/code_generation/patterns/ai/*.json | wc -l       # Should be 3
```

---

## 🐛 Troubleshooting

### "File already exists" during migration
**Cause:** File was copied in a previous run
**Solution:** Safe to ignore - script skips existing files

### JSON validation fails
**Cause:** Syntax error in JSON
**Solution:**
```bash
# Find the problematic file
moon run templates_data:validate 2>&1 | grep -i error

# Validate manually
jq empty path/to/file.json
```

### Database sync fails
**Cause:** PostgreSQL not running or schema mismatch
**Solution:**
```bash
# Check PostgreSQL
psql singularity -c "SELECT 1;"

# Check schema
psql singularity -c "\d knowledge_artifacts"

# Re-run migration
mix knowledge.migrate
```

### Embedding generation stuck
**Cause:** Large number of templates, API rate limits
**Solution:**
```bash
# Run in background
nohup moon run templates_data:embed-all > embed.log 2>&1 &

# Check progress
tail -f embed.log

# Or check database
psql singularity -c "SELECT COUNT(*) FROM knowledge_artifacts WHERE embedding IS NULL;"
```

---

## 📖 Related Documentation

- **Project Overview:** `/home/mhugo/code/singularity/CLAUDE.md`
- **Living Knowledge Base:** `KNOWLEDGE_ARTIFACTS_SETUP.md`
- **Schema Documentation:** `templates_data/schema.json`
- **SPARC Methodology:** `templates_data/workflows/sparc/`
- **Code Patterns:** `templates_data/code_generation/patterns/`

---

## 🤝 Contributing

After migration, to add new templates:

1. Create JSON following `templates_data/schema.json`
2. Validate: `jq empty your-template.json`
3. Place in appropriate directory
4. Run: `moon run templates_data:validate`
5. Sync: `moon run templates_data:sync-to-db`
6. Generate embedding: `moon run templates_data:embed-all`

---

## 📝 Change Log

**2025-10-09:** Initial template merge
- Analyzed 62 files (55 JSON + 7 Markdown)
- Identified 9 identical, 3 different, 50 unique
- Created migration scripts and documentation
- Resolved schema conflicts
- Established unified structure

---

## ✅ Completion Checklist

Use this to track your progress:

- [ ] Read TEMPLATE_MERGE_QUICKSTART.md
- [ ] Understand the 3 conflicts (see MANUAL_REVIEW_GUIDE.md)
- [ ] Run `./resolve_conflicts.sh`
- [ ] Run `./migrate_templates.sh`
- [ ] Validate JSON: `moon run templates_data:validate`
- [ ] Sync to DB: `moon run templates_data:sync-to-db`
- [ ] Generate embeddings: `moon run templates_data:embed-all`
- [ ] Test database queries (see validation section)
- [ ] Archive source: `mv rust/package/templates rust/package/templates.archived`
- [ ] Commit changes to git
- [ ] Update any external documentation (if needed)

---

## 🎉 Success Criteria

Migration is complete when:

1. ✅ All 50 unique files copied to templates_data/
2. ✅ JSON validation passes for all templates
3. ✅ Templates synced to PostgreSQL knowledge_artifacts table
4. ✅ Embeddings generated for semantic search
5. ✅ No conflicts remain in rust/package/templates/
6. ✅ Source directory archived or removed
7. ✅ Changes committed to git

---

## Questions or Issues?

- **Quick questions:** See TEMPLATE_MERGE_QUICKSTART.md troubleshooting
- **Deep dive:** See MANUAL_REVIEW_GUIDE.md
- **Schema questions:** Check `templates_data/schema.json`
- **Architecture:** See `CLAUDE.md` (Living Knowledge Base)

---

**Happy merging! 🚀**
