# Full Repository Ingestion

**Complete multi-language code ingestion across entire repository** 🚀

---

## What Changed

### Before (Only lib/)
```
StartupCodeIngestion scans:
  ✅ singularity/lib/**/*.ex  (251 files)
  ❌ rust/**/*.rs             (NOT scanned)
  ❌ llm-server/**/*.ts       (NOT scanned)
```

### After (Full Repo!)
```
StartupCodeIngestion scans:
  ✅ singularity/**/*.ex      (416 files)
  ✅ rust/**/*.rs             (394 files)
  ✅ llm-server/**/*.ts       (100 files)
  ✅ **/*.js, *.py, *.go      (22 files)
  ✅ **/*.nix, *.toml, *.md   (config + docs)

  Total: ~933 source files ingested on EVERY startup!
```

---

## Languages Supported

### Fully Parsed (20+ languages via CodeEngine)
- **Elixir** (`.ex`, `.exs`)
- **Rust** (`.rs`)
- **TypeScript** (`.ts`, `.tsx`)
- **JavaScript** (`.js`, `.jsx`)
- **Python** (`.py`)
- **Go** (`.go`)
- **Nix** (`.nix`)
- **Config files** (`.toml`, `.json`, `.yaml`, `.yml`)
- **Shell scripts** (`.sh`)
- **Documentation** (`.md`)

---

## What Gets Ingested

### Source Files (933 files)
```
Project root: /Users/mhugo/code/singularity-incubation

Scanned directories:
  rust/                     394 Rust files
  llm-server/               100 TypeScript files
  singularity/lib/          416 Elixir files
  centralcloud/             (if exists)

Config files:
  flake.nix, Cargo.toml, package.json, mix.exs, etc.
```

### What Gets EXCLUDED (deps, build artifacts)

**Hardcoded exclusions** (never ingested):
```
/deps/              # Elixir dependencies
/node_modules/      # npm dependencies
/target/            # Cargo build artifacts
/.cargo/            # Cargo registry cache
/_build/            # Elixir build artifacts
/dist/              # TypeScript/JavaScript build
/.git/              # Git metadata
/.nix/              # Nix store
/result             # Nix build symlink
*.log, *.tmp        # Temporary files
*.so, *.dylib       # Binary artifacts
```

**`.gitignore` patterns** (respected):
- All patterns from `.gitignore` are checked
- Prevents ingesting generated files, test fixtures, etc.

**`.singularityignore` patterns** (optional):
- Custom exclusions specific to code ingestion
- Use for files tracked in Git but not needed for analysis
- Example: `test-fixtures/`, `legacy/`, `*.generated.ex`

---

## How It Works

### Startup Flow
```
Application starts
    ↓
StartupCodeIngestion.start_link()
    ↓
Phase 1: Scan entire repo
    project_root = Path.expand("..", File.cwd!())  # Go up from singularity/ to repo root
    files = find_source_files()                     # Scan rust/, llm-server/, singularity/, etc.
    ↓
Phase 2: Filter files
    - Check hardcoded patterns (deps/, node_modules/, target/)
    - Check .gitignore patterns
    - Check .singularityignore patterns
    ↓
Phase 3: Ingest files (parallel, 10 workers)
    codebase_id = CodebaseDetector.detect(format: :full)  # "mikkihugo/singularity-incubation"
    UnifiedIngestionService.ingest_file(file, codebase_id: codebase_id)
    ↓
Phase 4: Store in PostgreSQL
    INSERT INTO code_files (project_name, file_path, language, content, ...)
    VALUES ('mikkihugo/singularity-incubation', 'rust/code_engine/src/lib.rs', 'rust', ...)
    ↓
✅ Ready for analysis!
```

### Ignore Pattern Matching

FullRepoScanner checks files in this order:

1. **Hardcoded patterns** (fast path)
   ```elixir
   if String.contains?(file_path, "/deps/") do
     :ignore  # ✅ Fast - no regex, no file I/O
   end
   ```

2. **`.gitignore` patterns** (if exists)
   ```elixir
   gitignore_patterns = File.read!(".gitignore")
   if matches_pattern?(file_path, gitignore_patterns) do
     :ignore  # ✅ Respects Git ignore rules
   end
   ```

3. **`.singularityignore` patterns** (if exists)
   ```elixir
   singularityignore_patterns = File.read!(".singularityignore")
   if matches_pattern?(file_path, singularityignore_patterns) do
     :ignore  # ✅ Custom ingestion rules
   end
   ```

---

## Configuration

### Auto-Detected (Zero Config!)

Just start the app - everything works automatically:

```bash
cd singularity
iex -S mix

# Automatically:
# ✓ Detects repo root (Path.expand("..", File.cwd!()))
# ✓ Scans 933 files across rust/, llm-server/, singularity/
# ✓ Excludes deps/, node_modules/, target/, .git/
# ✓ Respects .gitignore and .singularityignore
# ✓ Ingests to PostgreSQL with codebase_id "mikkihugo/singularity-incubation"
# ✓ Ready in seconds!
```

### Custom Exclusions (Optional)

Create `.singularityignore` in repo root:

```bash
# .singularityignore
test-fixtures/
legacy/
*.generated.ex
scripts/old/
```

---

## Database Storage

### PostgreSQL Table: `code_files`

```sql
SELECT
  id,
  project_name,  -- "mikkihugo/singularity-incubation"
  file_path,     -- "rust/code_engine/src/lib.rs"
  language,      -- "rust"
  line_count,
  size_bytes
FROM code_files
WHERE project_name = 'mikkihugo/singularity-incubation'
ORDER BY inserted_at DESC;

-- Result:
-- 933 rows (416 Elixir + 394 Rust + 100 TypeScript + 23 other)
```

### Query Examples

```elixir
alias Singularity.{Repo, Schemas.CodeFile}
import Ecto.Query

# All Rust files
rust_files = Repo.all(
  from f in CodeFile,
  where: f.project_name == "mikkihugo/singularity-incubation" and f.language == "rust"
)
# => 394 files

# All TypeScript files
ts_files = Repo.all(
  from f in CodeFile,
  where: f.project_name == "mikkihugo/singularity-incubation" and f.language == "typescript"
)
# => 100 files

# Count by language
Repo.all(
  from f in CodeFile,
  where: f.project_name == "mikkihugo/singularity-incubation",
  group_by: f.language,
  select: {f.language, count(f.id)}
)
# => [{"elixir", 416}, {"rust", 394}, {"typescript", 100}, ...]
```

---

## Performance

### Startup Time
```
On M1 Max (10-core):
  Scan 933 files:           ~500ms
  Parse + ingest (10 workers): ~3000ms
  Total startup overhead:    ~3.5s
```

### File Watching (Hot Reload)
```
Edit rust/code_engine/src/lib.rs
    ↓ (500ms debounce)
CodeFileWatcher detects change
    ↓
Re-ingest single file (~50ms)
    ↓
✅ Updated in database
```

---

## Verification

### Check What Got Ingested

```bash
# Count files by language
psql -d singularity -c "
  SELECT language, COUNT(*)
  FROM code_files
  WHERE project_name = 'mikkihugo/singularity-incubation'
  GROUP BY language
  ORDER BY COUNT(*) DESC;
"

# Expected output:
#   language    | count
# --------------+-------
#   elixir      |   416
#   rust        |   394
#   typescript  |   100
#   javascript  |    17
#   python      |     5
#   nix         |     1
```

### Check Specific Files

```elixir
iex> alias Singularity.{Repo, Schemas.CodeFile}
iex> import Ecto.Query

# Verify Rust code_engine was ingested
iex> Repo.one(from f in CodeFile, where: f.file_path == "rust/code_engine/src/lib.rs")
%CodeFile{
  project_name: "mikkihugo/singularity-incubation",
  file_path: "rust/code_engine/src/lib.rs",
  language: "rust",
  line_count: 1234,
  size_bytes: 45678
}

# Verify TypeScript llm-server was ingested
iex> Repo.one(from f in CodeFile, where: f.file_path == "llm-server/src/index.ts")
%CodeFile{
  project_name: "mikkihugo/singularity-incubation",
  file_path: "llm-server/src/index.ts",
  language: "typescript",
  line_count: 567,
  size_bytes: 12345
}
```

---

## Benefits

### 1. Complete Codebase Understanding
- **Before**: Only knew about Elixir code
- **After**: Understands Rust NIFs, TypeScript AI server, config files

### 2. Cross-Language Analysis
```elixir
# Find all Rust functions called from Elixir
elixir_files = Repo.all(from f in CodeFile, where: f.language == "elixir")
rust_nifs = find_rust_nif_calls(elixir_files)

# Find all TypeScript endpoints used by Elixir NATS client
ts_files = Repo.all(from f in CodeFile, where: f.language == "typescript")
nats_subjects = extract_nats_subjects(ts_files)
```

### 3. Better Code Search
```elixir
# Search across ALL languages
CodeSearch.search("embedding generation", codebase_id: "mikkihugo/singularity-incubation")
# Returns:
# - lib/singularity/embedding_service.ex  (Elixir)
# - rust/embedding_engine/src/lib.rs      (Rust)
# - llm-server/src/embeddings.ts          (TypeScript)
```

### 4. Unified Documentation
```bash
# Generate docs from all languages
mix docs --all-languages

# Includes:
# - Elixir @moduledoc
# - Rust /// doc comments
# - TypeScript /** JSDoc */
```

---

## Troubleshooting

### Problem: Too many files ingested

**Solution**: Add patterns to `.singularityignore`

```bash
# .singularityignore
test-fixtures/
archive/
*.test.ts
*.spec.js
```

### Problem: Important files missing

**Check**: Is it in `.gitignore`?

```bash
# View what .gitignore excludes
cat .gitignore

# Verify file isn't git-ignored
git check-ignore -v path/to/file
```

### Problem: Slow startup

**Cause**: Too many files (>2000)

**Solution**: Add more patterns to exclude:

```bash
# .singularityignore
examples/
benchmarks/
legacy/
```

---

## Summary

✅ **Scans entire repo** (rust/, llm-server/, singularity/, centralcloud/)
✅ **20+ languages** (Elixir, Rust, TypeScript, Python, Go, Nix, etc.)
✅ **~933 files** ingested on every startup
✅ **Excludes deps** (/deps/, /node_modules/, /target/)
✅ **Respects .gitignore** and `.singularityignore`
✅ **Auto-detects codebase_id** from Git
✅ **Hot reload** for file changes (500ms debounce)
✅ **Cross-language search** and analysis

**Your entire codebase is now in the knowledge base!** 🎉
