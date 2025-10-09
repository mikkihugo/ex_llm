# Template Merge - Start Here

**Merging templates from `rust/package/templates/` into `templates_data/`**

---

## 🎯 TL;DR (30 seconds)

```bash
./resolve_conflicts.sh    # Resolve 3 conflicts
./migrate_templates.sh    # Copy 50 files
moon run templates_data:validate
```

**Done!** 50 templates merged, 3 conflicts resolved, 9 duplicates skipped.

---

## 📚 Full Documentation

→ **Start with:** [TEMPLATE_MERGE_INDEX.md](TEMPLATE_MERGE_INDEX.md)

This index links to:
- Quick start guide (5 minutes)
- Detailed analysis report (complete findings)
- Manual review guide (understand decisions)
- Raw comparison data

---

## 📊 At a Glance

| Status | Count | Description |
|--------|-------|-------------|
| 🆕 New | 50 | Unique files to copy |
| ⚠️ Conflict | 3 | Different versions (auto-resolved) |
| ✅ Same | 9 | Identical files (skip) |
| **Total** | **62** | Files analyzed |

---

## 🚀 Quick Actions

### For the Impatient
```bash
cat TEMPLATE_MERGE_QUICKSTART.md  # 1-page guide
./resolve_conflicts.sh && ./migrate_templates.sh
```

### For the Thorough
```bash
cat TEMPLATE_MERGE_INDEX.md       # Full index
cat TEMPLATE_MERGE_FINAL_REPORT.md # Complete analysis
cat MANUAL_REVIEW_GUIDE.md        # Understand conflicts
```

### For the Validator
```bash
moon run templates_data:validate
moon run templates_data:sync-to-db
moon run templates_data:embed-all
```

---

## 📁 What You Get

After migration, `templates_data/` will have:

- **7 new system prompts** (beast-mode, plan-mode, etc.)
- **Complete SPARC workflow** (phases 0-8)
- **Cloud templates** (AWS, Azure, GCP)
- **AI frameworks** (CrewAI, LangChain, MCP)
- **Messaging systems** (Kafka, NATS, RabbitMQ, Redis)
- **Monitoring tools** (Grafana, Prometheus, etc.)
- **Security tools** (Falco, OPA)
- **Language patterns** (Python, Rust, TypeScript, etc.)
- **10 application templates** (APIs, microservices, consumers)

---

## ⚡ Scripts

All executable and documented:

- `resolve_conflicts.sh` - Auto-resolve 3 conflicts
- `migrate_templates.sh` - Copy 50 unique files
- `compare_templates.sh` - Generate comparison report
- `compare_bits.sh` - Compare markdown files

---

## 🎓 Learn More

**[→ Go to Index](TEMPLATE_MERGE_INDEX.md)** for complete documentation.

---

**Ready? Go!** → `./resolve_conflicts.sh && ./migrate_templates.sh`
