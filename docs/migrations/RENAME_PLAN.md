# Rename Plan: framework_patterns → technology_patterns

## Why Rename?

The `framework_patterns` table actually stores **ALL** technology patterns:
- ✅ Frameworks (React, Next.js, Django, Phoenix)
- ✅ Languages (Rust, Python, TypeScript, Elixir)
- ✅ Cloud platforms (AWS, GCP, Azure)
- ✅ Monitoring tools (Prometheus, Grafana, Jaeger)
- ✅ Security tools (Falco, OPA)
- ✅ AI frameworks (LangChain, CrewAI, MCP)
- ✅ Messaging systems (NATS, Kafka)

**Used by:**
- Technology detectors (Rust LayeredDetector, Elixir TechnologyDetector)
- Prompt builders (LLM context, code snippets)
- Embedding generators (semantic search)
- Template loaders (DSPy, SPARC)

The name `framework_patterns` is misleading - it's really a **universal technology knowledge base**.

## Migration Status

### ✅ Step 1: Database Schema (DONE)
- [x] Rename table: `framework_patterns` → `technology_patterns`
- [x] Rename columns: `framework_name` → `technology_name`, `framework_type` → `technology_type`
- [x] Update indexes and constraints
- [x] Migration: `20251005001000_rename_framework_patterns_to_technology_patterns.exs`

### 🔄 Step 2: Elixir Modules (TODO)

**Files to rename:**
1. `lib/singularity/framework_pattern_store.ex` → `technology_pattern_store.ex`
2. `lib/singularity/framework_pattern_sync.ex` → `technology_pattern_sync.ex`

**Module renames:**
- `Singularity.FrameworkPatternStore` → `Singularity.TechnologyPatternStore`
- `Singularity.FrameworkPatternSync` → `Singularity.TechnologyPatternSync`

**ETS table rename:**
- `:framework_patterns_cache` → `:technology_patterns_cache`

**NATS subject rename:**
- `facts.framework_patterns` → `facts.technology_patterns`

**References to update:**
- `singularity_app/lib/singularity/template_aware_embeddings.ex` (3 references)
- Any other files calling these modules

### 🔄 Step 3: Rust Code (TODO)

**Check if Rust uses the table name:**
```bash
grep -r "framework_patterns" rust/ --include="*.rs"
```

If yes, update:
- SQL queries
- Comments
- Module names

### 🔄 Step 4: JSON Export Path (TODO)

Current: `rust/tool_doc_index/framework_patterns.json`
New: `rust/tool_doc_index/technology_patterns.json`

Update in:
- `framework_pattern_sync.ex` (JSON export path)
- Rust detector (if it reads the JSON)

### 🔄 Step 5: NATS Subjects (TODO)

Current: `facts.framework_patterns`
New: `facts.technology_patterns`

**Impact:**
- NATS publishers (Elixir)
- NATS consumers (Rust SPARC fact system)
- Update `NATS_SUBJECTS.md`

### 🔄 Step 6: Documentation (TODO)

Update references in:
- [x] `PATTERN_SYSTEM.md` - Update terminology
- [ ] `README.md` - Update if mentioned
- [ ] `NATS_SUBJECTS.md` - Update subject names
- [ ] Code comments in migrations

## Rollout Strategy

### Option A: Big Bang (Fast, Risky)
1. Run migration (renames table)
2. Update all Elixir modules at once
3. Deploy
4. Hope nothing breaks 💥

### Option B: Gradual (Safe, Recommended) ✅
1. **Run migration** (table renamed, but old code still works)
2. **Create aliases** in Elixir:
   ```elixir
   defmodule Singularity.FrameworkPatternStore do
     # Deprecated: Use TechnologyPatternStore instead
     defdelegate get_pattern(name), to: Singularity.TechnologyPatternStore
     defdelegate learn_pattern(result), to: Singularity.TechnologyPatternStore
   end
   ```
3. **Update callsites** gradually (one PR at a time)
4. **Remove aliases** after all references updated
5. **Delete old module files**

### Option C: Feature Flag (Safest, Slowest)
1. Keep both names working simultaneously
2. Use environment variable to switch
3. Gradual rollout with monitoring
4. Remove old code after 100% adoption

## Recommended: Option B (Gradual with Aliases)

**Phase 1: Create new modules (this commit)**
```bash
# Copy modules with new names
cp lib/singularity/framework_pattern_store.ex lib/singularity/technology_pattern_store.ex
cp lib/singularity/framework_pattern_sync.ex lib/singularity/technology_pattern_sync.ex

# Update module names inside files
sed -i 's/FrameworkPatternStore/TechnologyPatternStore/g' lib/singularity/technology_pattern_store.ex
sed -i 's/FrameworkPatternSync/TechnologyPatternSync/g' lib/singularity/technology_pattern_sync.ex

# Update table references
sed -i 's/framework_patterns/technology_patterns/g' lib/singularity/technology_pattern_*.ex
sed -i 's/framework_name/technology_name/g' lib/singularity/technology_pattern_*.ex
sed -i 's/framework_type/technology_type/g' lib/singularity/technology_pattern_*.ex
```

**Phase 2: Add deprecation aliases (next commit)**
```elixir
# lib/singularity/framework_pattern_store.ex
defmodule Singularity.FrameworkPatternStore do
  @moduledoc """
  DEPRECATED: Use Singularity.TechnologyPatternStore instead.
  This module exists for backwards compatibility and will be removed in v2.0.
  """

  alias Singularity.TechnologyPatternStore

  defdelegate get_pattern(name), to: TechnologyPatternStore
  defdelegate learn_pattern(result), to: TechnologyPatternStore
  defdelegate update_success_rate(name, success), to: TechnologyPatternStore
end
```

**Phase 3: Update callsites (gradual PRs)**
```bash
# Find all callsites
grep -r "FrameworkPatternStore" singularity_app/lib --include="*.ex"
grep -r "FrameworkPatternSync" singularity_app/lib --include="*.ex"

# Update one by one
```

**Phase 4: Remove old modules (final cleanup)**
```bash
git rm lib/singularity/framework_pattern_store.ex
git rm lib/singularity/framework_pattern_sync.ex
```

## Testing

### Before Rename
```elixir
# Test old module still works (via aliases)
iex> Singularity.FrameworkPatternStore.get_pattern("nextjs")
{:ok, %{framework_name: "nextjs", ...}}
```

### After Rename
```elixir
# Test new module works
iex> Singularity.TechnologyPatternStore.get_pattern("nextjs")
{:ok, %{technology_name: "nextjs", ...}}

# Test detection still works
iex> Singularity.TechnologyDetector.detect_technologies(".")
```

### Integration Tests
```bash
# Run full E2E flow
mix test --only integration

# Test NATS flow
cd rust/tool_doc_index && cargo test --test integration_test

# Test pattern sync
iex> Singularity.TechnologyPatternSync.refresh_cache()
```

## Monitoring

After deployment, monitor:
- [ ] Detection success rate (should not change)
- [ ] Pattern cache hit rate
- [ ] NATS message throughput on `facts.technology_patterns`
- [ ] PostgreSQL query performance on `technology_patterns` table
- [ ] ETS table size (`:technology_patterns_cache`)

## Rollback Plan

If issues arise:

1. **Rollback migration:**
   ```bash
   mix ecto.rollback --step 1
   ```

2. **Restore old module names:**
   ```bash
   git revert <commit-hash>
   ```

3. **Clear ETS cache:**
   ```elixir
   :ets.delete_all_objects(:technology_patterns_cache)
   ```

## Timeline

- **Week 1**: Run database migration (table rename)
- **Week 2**: Create new Elixir modules + aliases
- **Week 3**: Update callsites (gradual)
- **Week 4**: Remove aliases and old modules
- **Week 5**: Cleanup and documentation

## Status

- [x] Create rename migration
- [x] Document plan
- [ ] Run migration in dev
- [ ] Create new Elixir modules
- [ ] Add deprecation aliases
- [ ] Update callsites
- [ ] Remove old modules
- [ ] Update documentation
