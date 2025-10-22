# Code Ingestion Systems - Which One to Use?

Singularity has **3 separate code ingestion systems** for different purposes:

---

## 1. HTDAGAutoBootstrap (Self-Ingestion) ✅ **PRIMARY**

**File:** `lib/singularity/execution/planning/htdag_auto_bootstrap.ex`

**Purpose:** Learn and persist **Singularity's OWN code** for self-improvement

**When:** Runs **automatically on EVERY server startup** (async, non-blocking)

**What it ingests:** All `.ex` files in `singularity/lib/` (~288 modules)

**Database:** `code_files` table (uses `project_name = "singularity"`)

**AST:** ✅ Full tree-sitter AST stored in `metadata.ast_json`

**Status:** ✅ **WORKING** (WithClauseError fixed)

### Use This For:
- **Nothing (it's automatic!)** - Runs on startup without intervention
- Self-diagnosis and auto-fixing broken code
- Understanding codebase structure for AI-assisted development

---

## 2. CodeFileWatcher (Real-time Updates) ⚡ **AUTOMATIC**

**File:** `lib/singularity/execution/planning/code_file_watcher.ex`

**Purpose:** Automatically re-ingest **Singularity's code** when files change during development

**When:** Runs **continuously** - monitors `lib/` directory for file changes

**What it does:** When you save a `.ex` file, it automatically re-ingests it to the database

**Database:** `code_files` table (same as HTDAGAutoBootstrap)

**AST:** ✅ Full tree-sitter AST stored in `metadata.ast_json`

**Status:** ✅ **WORKING** (newly added)

### How It Works:
```
File Modified (editor save)
    ↓
FileSystem Event (inotify)
    ↓
CodeFileWatcher re-ingests file
    ↓
PostgreSQL updated immediately
```

---

## 3. mix code.ingest (Semantic Search) 🔍 **DIFFERENT SYSTEM**

**File:** `lib/mix/tasks/code.ingest.ex`

**Purpose:** Generate embeddings for **semantic code search** (vector search)

**When:** Run manually when you want to enable semantic search

**What it ingests:** Any codebase (internal or external)

**Database:** `codebase_metadata` table (**DIFFERENT table!** Not `code_files`)

**AST:** ❌ No full AST (just embeddings for search)

**Status:** 📊 **Separate system** (not related to self-improvement)

### Use This For:
```bash
# Enable semantic search for singularity codebase
mix code.ingest

# Enable semantic search for external project
mix code.ingest --path /path/to/project --id project-name
```

---

## Quick Decision Guide

| What do you want? | Use this |
|-------------------|----------|
| **Singularity learns itself (startup)** | HTDAGAutoBootstrap (automatic) |
| **Singularity learns itself (runtime)** | CodeFileWatcher (automatic) |
| **Semantic code search** | `mix code.ingest` CLI |
| **Nothing, just run the server** | HTDAGAutoBootstrap + CodeFileWatcher run automatically |

---

## Database Schema Differences

### `code_files` table (HTDAGAutoBootstrap + CodeFileWatcher)
```sql
- project_name (VARCHAR) -- "singularity"
- file_path (VARCHAR)
- content (TEXT)
- language (VARCHAR)
- size_bytes (INTEGER)
- metadata (JSONB) -- Includes: ast_json, symbols, imports, exports
```

### `codebase_metadata` table (mix code.ingest)
```sql
- codebase_id (VARCHAR)
- chunk_text (TEXT)
- embedding (VECTOR) -- For semantic search
```

**They are SEPARATE tables for SEPARATE purposes!**

---

## Common Confusion Resolved

**Q: Why do we have multiple ingestion systems?**

**A:** They serve **different use cases**:
- **HTDAGAutoBootstrap** = Self-improvement on startup (comprehensive scan)
- **CodeFileWatcher** = Real-time updates during development (incremental)
- **mix code.ingest** = Vector search (different table)

**Q: Do they conflict?**

**A:** No! Both HTDAGAutoBootstrap and CodeFileWatcher use the same `code_files` table with PostgreSQL UPSERT:
- Startup: HTDAGAutoBootstrap ingests all 288 files
- Runtime: CodeFileWatcher re-ingests only changed files
- Database: Uses `(project_name, file_path)` unique constraint

**Q: Which one stores full AST?**

**A:** Both HTDAGAutoBootstrap and CodeFileWatcher store full AST in `metadata.ast_json`

**Q: Is startup-only ingestion enough?**

**A:** No - CodeFileWatcher was added because files need to be re-parsed when they change, not just on next startup!

---

## Recent Changes (2025-10-14)

1. ✅ Fixed HTDAGAutoBootstrap `WithClauseError` - NIF returns struct directly, not `{:ok, struct}`
2. ✅ **Added CodeFileWatcher** - Real-time file-watching for automatic re-ingestion
3. ✅ **Removed CodeIngestionService** - Was never actually called (dead import)
4. ✅ Removed dead files: `central_repo.ex`, `lua_api.ex`, `runner_temp.ex`
5. ✅ Verified 288 files successfully ingested with full AST

**Code ingestion now works at startup AND runtime!** 🎉
