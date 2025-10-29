# Rust Engines Inventory & Reorganization Plan

## Executive Summary

**Status:** Multiple Rust directories with NIF engines and services need consolidation  
**Goal:** Organize Rust engines into clear structure without losing features  
**Strategy:** Use `rustv2/` as new base, preserve all NIFs, link with `central_cloud` services  
**Architecture:** Rust NIFs run in Singularity (Elixir), Rust services connect via NATS to `central_cloud`

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  Singularity (Elixir/BEAM)                                  │
│  ┌────────────────────────────────────────────────────┐     │
│  │  NIF Engines (Rust compiled to .so/.dll)          │     │
│  │  - ~~architecture_engine~~  → (removed; now pure Elixir)       │     │
│  │  - code_engine         → rust/code_analysis       │     │
│  │  - parser_engine       → rust/parser/*            │     │
│  │  - quality_engine      → rust/quality             │     │
│  │  - knowledge_engine    → rust/knowledge           │     │
│  │  - embedding_engine    → rust/embedding           │     │
│  │  - semantic_engine     → rust/semantic            │     │
│  │  - prompt_engine       → rust/prompt_engine       │ ✅ │
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
│  Rust Services (Standalone)                                 │
│  - package_intelligence (rust/service/package_intelligence) │
└─────────────────────────────────────────────────────────────┘
```

---

## Current State - Rust Directories

### 1. `/rust` (Primary Engines - 14 modules) ✅ **ACTIVE NIFs**

**NIF Engines (loaded by Singularity):**
- `architecture/` → ~~`architecture_engine` NIF~~ (removed; replaced by pure Elixir architecture engine)
- `code_analysis/` → `code_engine` NIF - Code quality and analysis
- `embedding/` → `embedding_engine` NIF - Embedding generation
- `framework/` - Framework detection (not NIF, library)
- `knowledge/` → `knowledge_engine` NIF - Knowledge management
- `package/` - Package analysis (library)
- `prompt/` - Prompt engineering (library, superseded by rustv2)
- `quality/` → `quality_engine` NIF - Code quality checks
- `semantic/` - ❌ **DELETED** (2025-10-12) - replaced by `rust_global/semantic_embedding_engine`
- `template/` - Template management (library)

**Parser Suite (NIF):**
- `parser/core/` - Core parsing logic
- `parser/polyglot/` → `parser_engine` NIF - Multi-language support
- `parser/languages/` - Language-specific parsers (Python, JavaScript, TypeScript, Rust, Gleam, Elixir)
- `parser/formats/` - Format parsers (templates, dependencies)
- `parser/analyzers/` - Analysis tools (rust_code_analysis)

**Services (Standalone Binaries):**
- `service/package_intelligence/` - Package intelligence service with NATS support
  - `src/bin/main.rs` - Main binary
  - `src/bin/service.rs` - NATS service binary
- `service/intelligence_hub/` - ❌ **DELETED** (2025-10-12) - replaced by Elixir `central_cloud/lib/central_cloud/intelligence_hub.ex`
  - Not in workspace, not compiled

**Status:** ✅ **ACTIVE** - Main production engines, both NIFs and services

---

### 2. `/rustv2` (Removed - Was experimental prompt engine) ❌ **DELETED**

**Status:** ❌ **REMOVED** - Experimental `rustv2/prompt/` deleted 2025-10-12
**Reason:** Never reached production, replaced by enhanced `rust/prompt_engine/`
**Impact:** Cleaner codebase, no version confusion

---

### 3. `/rust_global` (Global Services - 1 module) ✅ **CLEAN**

**Active Services:**
- `package_registry/` - External package analysis (npm, cargo, hex, pypi) ✅ ACTIVE

**Archive:**
- `_archive/analysis_engine/` - Archived (duplicate of rust/code_analysis)
- `_archive/dependency_parser/` - Archived (duplicate of rust/parser)
- `_archive/intelligent_namer/` - Archived (duplicate of singularity/native/architecture_engine)
- `_archive/semantic_embedding_engine/` - **WILL BE ARCHIVED** (migrated to rust-central/embedding_engine)
- `_archive/tech_detection_engine/` - Archived (duplicate of singularity/native/architecture_engine)
- `_archive/mozilla-code-analysis/` - Archived Mozilla tools
- `_archive/codeintelligence_server/` - Archived intelligence server
- `_archive/consolidated_detector/` - Archived detector
- `_archive/unified_server/` - Archived unified server

**Status:** ✅ **CLEAN** - Only essential global service remains, all duplicates archived

---

### 4. `/rust_backup` (Backup - Legacy) ❌ **REMOVED**

**Contents:** Was full backup of old Rust structure (200+ duplicate files)

**Status:** ❌ **REMOVED** - Eliminated during duplicate cleanup (2025-01-10)

---

### 5. `/central_cloud` (Elixir/BEAM Service) ✅ **ACTIVE**

**Purpose:** Central cloud orchestration services linking to Rust engines via NATS

**Three Servers:**
1. **Framework Learning Agent** (Elixir GenServer)
   - Reactive framework discovery
   - Triggers on-demand when framework not found
   - Calls LLM via NATS (`llm.request`)
   - Caches results in PostgreSQL

2. **Package Intelligence Service** (Rust Binary via NATS)
   - Package analysis and metadata
   - Technology detection
   - Links to `rust/service/package_intelligence`

3. **Intelligence Hub Service** (Elixir GenServer)
   - Intelligence aggregation (code/architecture/data patterns)
   - NATS subscription handler (6 subjects)
   - Implemented in `central_cloud/lib/central_cloud/intelligence_hub.ex` (381 lines)
   - ❌ Rust stub at `rust/service/intelligence_hub` was DELETED (2025-10-12)

**Infrastructure:**
- NATS client for communication
- PostgreSQL with Ecto
- Database schemas (packages, prompts, code snippets, analysis results)
- pgvector extension for embeddings

**Status:** ✅ **ACTIVE** - Orchestrates Rust services via NATS

---

## NIF Function Mapping (Singularity → Rust)

**Critical:** These NIFs are loaded by Singularity and must be preserved in reorganization.

| Elixir Module | Rust Crate | Functions Exported | Status |
|---------------|------------|-------------------|--------|
| `Singularity.ArchitectureEngine` | `architecture` | suggest_function_names, suggest_module_names, validate_naming | ✅ NIF |
| `Singularity.CodeEngine` | `code_analysis` | analyze_quality, calculate_metrics, detect_patterns | ✅ NIF |
| `Singularity.ParserEngine` | `parser-code` (polyglot) | parse_file, parse_directory, extract_ast | ✅ NIF |
| `Singularity.QualityEngine` | `quality` | check_quality, calculate_score, suggest_improvements | ✅ NIF |
| `Singularity.KnowledgeIntelligence` | `knowledge` | search_artifacts, index_knowledge, retrieve_templates | ✅ NIF |
| `Singularity.EmbeddingEngine` | `embedding` | generate_embedding, batch_embed, similarity_search | ✅ NIF |
| `Singularity.SemanticEngine` | `semantic` (library) | analyze_semantics, extract_meaning | ⚠️ Not NIF yet |
| `Singularity.PromptEngine` | `prompt` (rustv2) | optimize_prompt, generate_prompt, validate_prompt | 🟡 New NIF |

**Total NIFs:** 8 modules (7 active + 1 new)

---

## Feature Inventory by Category

### 🎯 Core Analysis Engines

| Engine | Location | Type | Features | Status |
|--------|----------|------|----------|--------|
| Code Analysis | `/rust/code_analysis/` | NIF | Quality checks, metrics, linting | ✅ Active |
| Architecture | `/rust/architecture/` | NIF | System design, patterns, naming suggestions | ✅ Active |
| Semantic Analysis | `/rust_global/semantic_embedding_engine/` | Semantic understanding | ✅ Active |
| Global Analysis | `/rust_global/analysis_engine/` | Cross-project analysis | ✅ Active |

**Recommendation:** Keep both, different scope levels

---

### 📦 Package & Dependency

| Engine | Location | Features | Status |
|--------|----------|----------|--------|
| Package Analysis | `/rust/package/` | Package metadata, versions | ✅ Active |
| Package Suite | `/rust_global/package_analysis_suite/` | Comprehensive analysis | ✅ Active |
| Dependency Parser | `/rust_global/dependency_parser/` | Dependency graphs | ✅ Active |
| Package Intelligence | `/rust/service/package_intelligence/` | AI-powered insights | ✅ Active |

**Recommendation:** Consolidate into unified package analysis system

---

### 🧠 AI & Embeddings

| Engine | Location | Features | Status |
|--------|----------|----------|--------|
| Embedding | `/rust/embedding/` | Vector embeddings | ✅ Active |
| Semantic Embedding | `/rust-central/embedding_engine/` | Advanced embeddings (GPU: Jina v3 + Qodo-Embed-1) | ✅ Active |
| Prompt Engineering | `/rust/prompt_engine/` | DSPy optimization + Central Intelligence Hub integration | ✅ Active |

**Recommendation:** Use enhanced `rust/prompt_engine/` with central integration, embeddings separate

---

### 🔍 Detection & Discovery

| Engine | Location | Features | Status |
|--------|----------|----------|--------|
| Framework Detection | `/rust/framework/` | Framework identification | ✅ Active |
| Tech Detection | `/rust_global/tech_detection_engine/` | Technology stack detection | ✅ Active |
| Intelligent Namer | `/rust_global/intelligent_namer/` | Smart naming suggestions | ✅ Active |

**Recommendation:** Consolidate detection engines

---

### 📝 Parsers & Languages

| Parser | Location | Languages | Status |
|--------|----------|-----------|--------|
| Core Parser | `/rust/parser/core/` | Base parsing | ✅ Active |
| Polyglot | `/rust/parser/polyglot/` | Multi-language | ✅ Active |
| Language Parsers | `/rust/parser/languages/` | Python, JS, TS, Rust, Gleam, Elixir | ✅ Active |
| Format Parsers | `/rust/parser/formats/` | Templates, dependencies | ✅ Active |
| Rust Analysis | `/rust/parser/analyzers/rust_code_analysis/` | Rust-specific analysis | ✅ Active |

**Recommendation:** Keep as-is, well organized

---

### 📚 Knowledge & Templates

| Engine | Location | Features | Status |
|--------|----------|----------|--------|
| Knowledge | `/rust/knowledge/` | Knowledge base | ✅ Active |
| Template | `/rust/template/` | Template management | ✅ Active |
| Quality | `/rust/quality/` | Quality templates | ✅ Active |

**Recommendation:** Keep as-is, integrate with PostgreSQL knowledge base

---

### 🌐 Services & Hub

| Service | Location | Features | Status |
|--------|----------|----------|--------|
| Framework Learning Agent | `central_cloud/` (Elixir) | Framework pattern learning | ✅ Active |
| Package Intelligence | `/rust/service/package_intelligence/` | External package indexing (npm, cargo, hex, pypi) | ✅ Active |
| Knowledge Cache Service | NATS service | Central code knowledge hub (patterns, templates, metadata) | ✅ Active |

**Note:** Three distinct services in central_cloud ecosystem:
- **Framework Learning Agent** (Elixir) - Framework pattern learning
- **Package Intelligence** (Rust) - External registry indexing  
- **Knowledge Cache** (Rust/NATS) - Code knowledge distribution

**Recommendation:** All three services link via NATS for distributed coordination

---

## Reorganization Plan

### Phase 1: Structure Definition (1 hour)

```
rustv2/                          # New base directory
├── core/                        # Core engines (migrate from /rust)
│   ├── analysis/               # From /rust/code_analysis
│   ├── architecture/           # From /rust/architecture
│   ├── embedding/              # From /rust/embedding
│   ├── knowledge/              # From /rust/knowledge
│   ├── quality/                # From /rust/quality
│   └── semantic/               # From /rust/semantic
│
├── parsers/                     # Parser suite (migrate from /rust/parser)
│   ├── core/
│   ├── polyglot/
│   ├── languages/
│   ├── formats/
│   └── analyzers/
│
├── detection/                   # Detection engines (consolidate)
│   ├── framework/              # From /rust/framework
│   ├── technology/             # From /rust_global/tech_detection_engine
│   └── intelligent_namer/      # From /rust_global/intelligent_namer
│
├── packages/                    # Package analysis (consolidate)
│   ├── analysis/               # From /rust/package
│   ├── intelligence/           # From /rust/service/package_intelligence
│   ├── dependencies/           # From /rust_global/dependency_parser
│   └── suite/                  # From /rust_global/package_analysis_suite
│
├── ai/                          # AI engines
│   ├── prompt/                 # From /rustv2/prompt (already here)
│   ├── embeddings/             # Consolidated embeddings
│   └── semantic/               # Advanced semantic analysis
│
├── services/                    # Service layer
│   ├── intelligence_hub/       # From /rust/service/intelligence_hub
│   └── nats_bridge/            # New: NATS communication
│
└── templates/                   # Template management
    └── engine/                 # From /rust/template
```

---

### Phase 2: Central Cloud Integration (2 hours)

```
central_cloud/                   # Elixir orchestration service
├── lib/central_cloud/
│   ├── nats_client.ex          # ✅ Exists - NATS communication
│   ├── rust_bridge.ex          # 🆕 Create - Bridge to Rust engines
│   ├── package_service.ex      # 🆕 Create - Package analysis API
│   ├── analysis_service.ex     # 🆕 Create - Code analysis API
│   └── embedding_service.ex    # 🆕 Create - Embedding API
│
└── Rust Engine Communication via NATS:
    - Subject: rust.analysis.request
    - Subject: rust.package.analyze
    - Subject: rust.embedding.generate
    - Subject: rust.detection.framework
```

---

### Phase 3: Migration Strategy (3 hours)

**Step 1: Create rustv2 structure**
```bash
# Create directory structure
mkdir -p rustv2/{core,parsers,detection,packages,ai,services,templates}
mkdir -p rustv2/core/{analysis,architecture,embedding,knowledge,quality,semantic}
mkdir -p rustv2/parsers/{core,polyglot,languages,formats,analyzers}
mkdir -p rustv2/detection/{framework,technology,intelligent_namer}
mkdir -p rustv2/packages/{analysis,intelligence,dependencies,suite}
mkdir -p rustv2/ai/{prompt,embeddings,semantic}
mkdir -p rustv2/services/{intelligence_hub,nats_bridge}
mkdir -p rustv2/templates/engine
```

**Step 2: Copy engines (preserving features)**
```bash
# Core engines
cp -r rust/code_analysis/* rustv2/core/analysis/
cp -r rust/architecture/* rustv2/core/architecture/
cp -r rust/embedding/* rustv2/core/embedding/
cp -r rust/knowledge/* rustv2/core/knowledge/
cp -r rust/quality/* rustv2/core/quality/
cp -r rust/semantic/* rustv2/core/semantic/

# Parsers
cp -r rust/parser/* rustv2/parsers/

# Detection (consolidate)
cp -r rust/framework/* rustv2/detection/framework/
cp -r rust_global/tech_detection_engine/* rustv2/detection/technology/
cp -r rust_global/intelligent_namer/* rustv2/detection/intelligent_namer/

# Packages (consolidate)
cp -r rust/package/* rustv2/packages/analysis/
cp -r rust/service/package_intelligence/* rustv2/packages/intelligence/
cp -r rust_global/dependency_parser/* rustv2/packages/dependencies/
cp -r rust_global/package_analysis_suite/* rustv2/packages/suite/

# AI engines (already have prompt/)
cp -r rust/embedding/* rustv2/ai/embeddings/
cp -r rust-central/embedding_engine/* rustv2/ai/semantic/

# Services
cp -r rust/service/intelligence_hub/* rustv2/services/intelligence_hub/

# Templates
cp -r rust/template/* rustv2/templates/engine/
```

**Step 3: Create workspace Cargo.toml**
```toml
# rustv2/Cargo.toml
[workspace]
members = [
    "core/analysis",
    "core/architecture",
    "core/embedding",
    "core/knowledge",
    "core/quality",
    "core/semantic",
    "parsers/core",
    "parsers/polyglot",
    "parsers/languages/*",
    "parsers/formats/*",
    "parsers/analyzers/*",
    "detection/framework",
    "detection/technology",
    "detection/intelligent_namer",
    "packages/analysis",
    "packages/intelligence",
    "packages/dependencies",
    "packages/suite",
    "ai/prompt",
    "ai/embeddings",
    "ai/semantic",
    "services/intelligence_hub",
    "services/nats_bridge",
    "templates/engine",
]

[workspace.dependencies]
# Shared dependencies
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
anyhow = "1"
async-nats = "0.33"
```

**Step 4: Update central_cloud integration**
```elixir
# central_cloud/lib/central_cloud/rust_bridge.ex
defmodule CentralCloud.RustBridge do
  use GenServer
  alias CentralCloud.NatsClient

  def analyze_code(code, language) do
    NatsClient.request("rust.analysis.request", %{
      code: code,
      language: language
    })
  end

  def detect_framework(code) do
    NatsClient.request("rust.detection.framework", %{
      code: code
    })
  end

  def analyze_package(package_name, version) do
    NatsClient.request("rust.package.analyze", %{
      name: package_name,
      version: version
    })
  end

  def generate_embedding(text) do
    NatsClient.request("rust.embedding.generate", %{
      text: text
    })
  end
end
```

---

## Feature Preservation Checklist

### ✅ No Feature Loss

- [ ] **Code Analysis** - All quality checks preserved
- [ ] **Architecture** - All design patterns preserved
- [ ] **Embeddings** - All embedding models preserved
- [ ] **Parsers** - All language parsers preserved (Python, JS, TS, Rust, Gleam, Elixir)
- [ ] **Framework Detection** - All framework patterns preserved
- [ ] **Technology Detection** - All tech stack patterns preserved
- [ ] **Package Analysis** - All package features preserved
- [ ] **Dependency Parsing** - All dependency features preserved
- [ ] **Intelligent Naming** - All naming algorithms preserved
- [ ] **Prompt Engineering** - V1 + V2 both available
- [ ] **Quality Checks** - All quality rules preserved
- [ ] **Knowledge Base** - All knowledge features preserved
- [ ] **Templates** - All template features preserved
- [ ] **Services** - Intelligence hub preserved

---

## Integration Points

### 1. NATS Communication
```
Elixir (central_cloud) <--NATS--> Rust (rustv2/services/nats_bridge) <--> Rust Engines
```

### 2. PostgreSQL Storage
```
Rust Engines --> Analysis Results --> central_cloud --> PostgreSQL
```

### 3. Service Endpoints
```
rustv2/services/nats_bridge/
├── analysis_handler.rs     # Handle analysis requests
├── detection_handler.rs    # Handle detection requests
├── package_handler.rs      # Handle package requests
└── embedding_handler.rs    # Handle embedding requests
```

---

## Testing Strategy

### Unit Tests
```bash
# Test each engine individually
cd rustv2/core/analysis && cargo test
cd rustv2/detection/framework && cargo test
cd rustv2/packages/analysis && cargo test
```

### Integration Tests
```bash
# Test NATS communication
cd rustv2/services/nats_bridge && cargo test

# Test from Elixir side
cd central_cloud && mix test
```

### End-to-End Tests
```bash
# Full workflow test
cd singularity && mix test test/integration/rust_engines_test.exs
```

---

## Rollout Plan

### Week 1: Structure & Migration
- Day 1: Create rustv2 structure
- Day 2-3: Copy engines preserving features
- Day 4: Create workspace Cargo.toml
- Day 5: Initial compilation and fixes

### Week 2: Integration
- Day 1-2: Build NATS bridge service
- Day 3: Update central_cloud integration
- Day 4-5: Integration testing

### Week 3: Validation
- Day 1-2: Feature validation (all checklist items)
- Day 3: Performance testing
- Day 4-5: Documentation updates

---

## Deprecation Timeline

1. **rustv2** becomes primary (Week 1)
2. **rust/** marked deprecated (Week 2)
3. **rust_global/** archived (Week 2)
4. **rust_backup/** can be deleted (Week 3)
5. **central_cloud** fully integrated (Week 3)

---

## Success Metrics

- ✅ All engines compile in rustv2
- ✅ All tests pass
- ✅ NATS communication working
- ✅ central_cloud integration complete
- ✅ No feature regression
- ✅ Performance maintained or improved
- ✅ Documentation complete

---

*This inventory ensures no Rust features are lost during reorganization. The new rustv2 structure provides clear organization while maintaining full functionality and improving integration with central_cloud via NATS.*
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
- Calls LLM via NATS (`llm.request`)
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
│  │  - ~~architecture_engine~~  → (removed; replaced by Elixir detectors)            │     │
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
