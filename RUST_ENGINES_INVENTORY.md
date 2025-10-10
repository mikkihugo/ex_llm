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
│  │  - architecture_engine  → rust/architecture       │     │
│  │  - code_engine         → rust/code_analysis       │     │
│  │  - parser_engine       → rust/parser/*            │     │
│  │  - quality_engine      → rust/quality             │     │
│  │  - knowledge_engine    → rust/knowledge           │     │
│  │  - embedding_engine    → rust/embedding           │     │
│  │  - semantic_engine     → rust/semantic            │     │
│  │  - prompt_engine       → rustv2/prompt            │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
                           ↕ NATS
┌─────────────────────────────────────────────────────────────┐
│  Central_Cloud (Elixir/BEAM) - 3 Services                   │
│  1. Framework Learning Agent (Elixir GenServer)             │
│  2. Package Intelligence Service (Rust via NATS)            │
│  3. Knowledge Cache Service (Rust/NATS - code knowledge)    │
└─────────────────────────────────────────────────────────────┘
                           ↕ NATS
┌─────────────────────────────────────────────────────────────┐
│  Rust Services (Standalone)                                 │
│  - package_intelligence (bin/service.rs)                    │
│  - intelligence_hub (main.rs)                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Current State - Rust Directories

### 1. `/rust` (Primary Engines - 14 modules) ✅ **ACTIVE NIFs**

**NIF Engines (loaded by Singularity):**
- `architecture/` → `architecture_engine` NIF - Architecture analysis and design
- `code_analysis/` → `code_engine` NIF - Code quality and analysis
- `embedding/` → `embedding_engine` NIF - Embedding generation
- `framework/` - Framework detection (not NIF, library)
- `knowledge/` → `knowledge_engine` NIF - Knowledge management
- `package/` - Package analysis (library)
- `prompt/` - Prompt engineering (library, superseded by rustv2)
- `quality/` → `quality_engine` NIF - Code quality checks
- `semantic/` - Semantic analysis (library)
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
- `service/intelligence_hub/` - Intelligence aggregation service
  - `src/main.rs` - Main binary

**Status:** ✅ **ACTIVE** - Main production engines, both NIFs and services

---

### 2. `/rustv2` (New Prompt Engine - 1 module) 🟡 **IN DEVELOPMENT**

**Contents:**
- `prompt/` → `prompt_engine` NIF - Next-generation prompt engineering

**Status:** 🟡 **IN DEVELOPMENT** - User mentioned this as new base for reorganization

---

### 3. `/rust_global` (Global Services - 6 modules) 🟡 **MIXED**

**Core Services:**
- `analysis_engine/` - Global analysis engine
- `dependency_parser/` - Dependency parsing
- `intelligent_namer/` - Intelligent naming service
- `package_analysis_suite/` - Package analysis
- `semantic_embedding_engine/` - Semantic embeddings
- `tech_detection_engine/` - Technology detection

**Archive:**
- `_archive/mozilla-code-analysis/` - Archived Mozilla tools
- `_archive/codeintelligence_server/` - Archived intelligence server
- `_archive/consolidated_detector/` - Archived detector
- `_archive/unified_server/` - Archived unified server

**Status:** 🟡 **MIXED** - Some active, some archived, overlap with `/rust`

---

### 4. `/rust_backup` (Backup - Legacy) ❌ **ARCHIVED**

**Contents:** Full backup of old Rust structure

**Status:** ❌ **ARCHIVED** - For reference only

---

### 5. `/central_cloud` (Elixir/BEAM Service) ✅ **ACTIVE**

**Purpose:** Central cloud orchestration services linking to Rust engines via NATS

**Three Servers:**
1. **Framework Learning Agent** (Elixir GenServer)
   - Reactive framework discovery
   - Triggers on-demand when framework not found
   - Calls LLM via NATS (`ai.llm.request`)
   - Caches results in PostgreSQL

2. **Package Intelligence Service** (Rust Binary via NATS)
   - Package analysis and metadata
   - Technology detection
   - Links to `rust/service/package_intelligence`

3. **Intelligence Hub Service** (Rust Binary via NATS)
   - Intelligence aggregation
   - Coordinates multiple analysis engines
   - Links to `rust/service/intelligence_hub`

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
| Semantic Analysis | `/rust/semantic/` | Semantic understanding | ✅ Active |
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
| Semantic Embedding | `/rust_global/semantic_embedding_engine/` | Advanced embeddings | ✅ Active |
| Prompt Engineering | `/rust/prompt/` | Prompt templates | ✅ Active |
| Prompt V2 | `/rustv2/prompt/` | Next-gen prompts | 🟡 Dev |

**Recommendation:** Migrate to `rustv2/prompt/`, keep embeddings separate

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
cp -r rust_global/semantic_embedding_engine/* rustv2/ai/semantic/

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
cd singularity_app && mix test test/integration/rust_engines_test.exs
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
