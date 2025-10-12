# Rust Service Status - Active vs Deprecated

**Date:** 2025-10-12
**Purpose:** Clarify which Rust services are ACTIVE vs DEPRECATED after intelligence_hub rewrite

---

## Executive Summary

**Active Rust Services:** 1
**Deprecated Rust Services:** 1 (replaced by Elixir)
**Central Cloud Services:** 3 (2 Elixir + 1 coordinating with Rust)

---

## Active Rust Services

### 1. Package Intelligence Service ✅

**Location:** `/rust/service/package_intelligence/`
**Status:** ✅ **ACTIVE** - Production service
**Type:** Standalone binary with NATS integration
**Size:** ~500+ lines across multiple modules

**Purpose:**
- External package registry analysis (npm, cargo, hex, pypi)
- Package metadata collection
- Technology detection
- Version analysis
- Dependency resolution

**Binaries:**
- `src/bin/main.rs` - CLI binary
- `src/bin/service.rs` - NATS service binary

**Integration:**
- NATS subjects: `package.analyze`, `package.search`, `package.metadata`
- Called by: `central_cloud/lib/central_cloud/package_service.ex`
- Storage: PostgreSQL via central_cloud

**Workspace Status:** ✅ Included in workspace, actively compiled

---

## Deprecated Rust Services

### 1. Intelligence Hub Service ❌

**Location:** `/rust/service/intelligence_hub/`
**Status:** ❌ **DEPRECATED** (2025-10-10)
**Replacement:** Elixir `central_cloud/lib/central_cloud/intelligence_hub.ex`

**Why Deprecated:**
- Rewritten in pure Elixir for better BEAM integration
- Simpler NATS subscription handling
- Direct Ecto/PostgreSQL access
- No FFI overhead
- Easier to maintain alongside other GenServers

**Deprecation Evidence:**
1. README explicitly says "Deprecated" (line 1)
2. NOT in Cargo workspace (neither `/rust/Cargo.toml` nor root `Cargo.toml`)
3. Not compiled during build
4. Elixir version is 381 lines of production code

**Rust Stub Status:**
- Files exist: `src/main.rs` (reference only, 4KB)
- Cargo.toml exists but unused
- Kept for historical reference only
- **DO NOT ADD NEW CODE HERE**

---

## Central Cloud Services (Elixir)

### 1. Framework Learning Agent ✅

**Location:** `central_cloud/lib/central_cloud/framework_learning_agent.ex`
**Type:** Elixir GenServer
**Status:** ✅ **ACTIVE**

**Purpose:**
- Reactive framework discovery
- Triggers on-demand when framework not found
- Calls LLM via NATS (`ai.llm.request`)
- Caches results in PostgreSQL

### 2. Intelligence Hub ✅

**Location:** `central_cloud/lib/central_cloud/intelligence_hub.ex`
**Type:** Elixir GenServer
**Status:** ✅ **ACTIVE**
**Size:** 381 lines

**Purpose:**
- Aggregates code/architecture/data intelligence
- Subscribes to 6 NATS subjects:
  - `intelligence.code.pattern.learned`
  - `intelligence.architecture.pattern.learned`
  - `intelligence.data.schema.learned`
  - `intelligence.insights.query`
  - `intelligence.quality.aggregate`
  - `intelligence.query` (template context)
- Template context injection for code generation
- PostgreSQL persistence

**Key Features:**
- Full GenServer lifecycle
- NATS subscription management
- Template context query handler
- Quality metrics aggregation
- Pattern learning storage

### 3. Template Service ✅

**Location:** `central_cloud/lib/central_cloud/template_service.ex`
**Type:** Elixir module
**Status:** ✅ **ACTIVE**

**Purpose:**
- Template context injection
- Framework metadata enrichment
- Quality standards injection
- Package recommendations
- Coordinates with Intelligence Hub

---

## Architecture Diagram (Corrected)

```
┌─────────────────────────────────────────────────────────────┐
│  Singularity (Elixir/BEAM)                                  │
│  ┌────────────────────────────────────────────────────┐     │
│  │  NIF Engines (Rust compiled to .so/.dll)          │     │
│  │  - architecture_engine  → rust-central/            │     │
│  │  - code_engine         → rust-central/             │     │
│  │  - parser_engine       → rust-central/             │     │
│  │  - quality_engine      → rust-central/             │     │
│  │  - knowledge_engine    → rust-central/             │     │
│  │  - embedding_engine    → rust-central/             │     │
│  │  - prompt_engine       → rust-central/             │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                           ↕ NATS
┌─────────────────────────────────────────────────────────────┐
│  Central_Cloud (Elixir/BEAM) - 3 Services                   │
│  1. Framework Learning Agent (Elixir GenServer)             │
│  2. Intelligence Hub (Elixir GenServer - 381 lines)         │
│  3. Template Service (Elixir - template context injection)  │
└─────────────────────────────────────────────────────────────┘
                           ↕ NATS
┌─────────────────────────────────────────────────────────────┐
│  Rust Services (Standalone) - 1 Active Service              │
│  ✅ package_intelligence (rust/service/package_intelligence) │
│  ❌ intelligence_hub (DEPRECATED - see Elixir version above) │
└─────────────────────────────────────────────────────────────┘
```

---

## Migration History

### Intelligence Hub: Rust → Elixir

**Date:** October 10, 2025
**Reason:** Better BEAM integration, simpler maintenance

**Before (Rust):**
- Location: `rust/service/intelligence_hub/`
- Binary service with NATS
- FFI complexity for PostgreSQL
- Separate process management

**After (Elixir):**
- Location: `central_cloud/lib/central_cloud/intelligence_hub.ex`
- Native GenServer
- Direct Ecto/PostgreSQL
- Part of supervision tree
- 381 lines of clean Elixir

**Benefits:**
- ✅ Simpler NATS subscription handling
- ✅ No FFI overhead
- ✅ Direct database access
- ✅ Better error handling
- ✅ Hot code reloading
- ✅ Easier debugging

---

## What This Means for Development

### When Adding Intelligence Features:

**✅ DO:** Extend `central_cloud/lib/central_cloud/intelligence_hub.ex`
```elixir
# Add new NATS subscriptions
NatsClient.subscribe("intelligence.new.subject", &handle_new_intel/1)

# Add new handlers
defp handle_new_intel(msg) do
  # Your logic here
end
```

**❌ DON'T:** Add code to `rust/service/intelligence_hub/`
- It's not compiled
- It won't run
- It will be deleted in future cleanup

### When Adding Package Features:

**✅ DO:** Extend `rust/service/package_intelligence/`
```rust
// This service is active and maintained
pub fn new_package_feature() {
    // Your Rust code here
}
```

---

## Cleanup Recommendations

### Phase 1: Documentation (DONE)
- [x] Mark intelligence_hub as DEPRECATED in docs
- [x] Update RUST_ENGINES_INVENTORY.md
- [x] Update rust/README.md
- [x] Create RUST_SERVICE_STATUS.md (this file)

### Phase 2: Code Cleanup (Future)
- [ ] Archive `rust/service/intelligence_hub/` → `rust/_archive/`
- [ ] Remove from any remaining references
- [ ] Update CI/CD to skip building it

### Phase 3: Verification (Future)
- [ ] Confirm no code depends on Rust intelligence_hub
- [ ] Verify all intelligence queries go to Elixir version
- [ ] Performance test Elixir version vs old Rust version

---

## Summary Table

| Service | Type | Location | Status | Lines | Purpose |
|---------|------|----------|--------|-------|---------|
| Package Intelligence | Rust Binary | `rust/service/package_intelligence/` | ✅ Active | 500+ | External package registries |
| Intelligence Hub | Rust Binary | `rust/service/intelligence_hub/` | ❌ Deprecated | 4KB stub | REPLACED by Elixir |
| Intelligence Hub | Elixir GenServer | `central_cloud/lib/central_cloud/intelligence_hub.ex` | ✅ Active | 381 | Intelligence aggregation |
| Framework Learning | Elixir GenServer | `central_cloud/lib/central_cloud/framework_learning_agent.ex` | ✅ Active | ~200 | Framework discovery |
| Template Service | Elixir Module | `central_cloud/lib/central_cloud/template_service.ex` | ✅ Active | ~300 | Template context |

---

## Questions & Answers

**Q: Why keep the Rust intelligence_hub directory if it's deprecated?**
A: Historical reference only. Will be archived to `_archive/` in future cleanup.

**Q: Can I add features to Rust intelligence_hub?**
A: NO. It's not compiled, not in workspace. Add to Elixir version instead.

**Q: Is package_intelligence being replaced too?**
A: NO. It's actively maintained and will remain Rust.

**Q: Should I write new services in Rust or Elixir?**
A: Depends on use case:
- **Elixir:** If needs NATS subscriptions, PostgreSQL, OTP supervision
- **Rust:** If needs CPU-intensive processing, external library integration

---

## See Also

- [RUST_ENGINES_INVENTORY.md](RUST_ENGINES_INVENTORY.md) - Complete Rust engine inventory
- [EMBEDDING_ENGINE_MIGRATION.md](EMBEDDING_ENGINE_MIGRATION.md) - Embedding engine migration
- [CENTRAL_CLOUD_NATS_IMPLEMENTATION_COMPLETE.md](CENTRAL_CLOUD_NATS_IMPLEMENTATION_COMPLETE.md) - NATS integration
- `central_cloud/lib/central_cloud/intelligence_hub.ex` - Active Intelligence Hub implementation
