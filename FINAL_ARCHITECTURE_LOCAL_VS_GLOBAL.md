# Final Architecture: Local vs Global

## The Complete Picture

```
┌────────────────────────────────────────────────────────────────────────┐
│ SINGULARITY PRO (Global/Central Intelligence)                          │
│                                                                        │
│ "What do ALL projects across the world know?"                         │
│                                                                        │
│ Components:                                                            │
│ • central_services_app/     (Elixir orchestration)                    │
│ • rust-central/             (Global Rust services)                     │
│ • rust/service/             (NATS services - ALL GLOBAL)               │
│   ├── template_service/     ⭐ Templates for everyone                  │
│   ├── package_service/      ⭐ External packages (npm/cargo/hex)       │
│   ├── prompt_service/       ⭐ Prompt templates                        │
│   ├── embedding_service/    ⭐ Global embeddings                       │
│   └── ...                                                              │
│                                                                        │
│ Data Sources:                                                          │
│ • templates_data/           ⭐ GLOBAL TEMPLATES (Git-backed)           │
│   ├── code_generation/      (Code templates)                          │
│   ├── frameworks/           (Framework patterns)                      │
│   ├── workflows/            (SPARC workflows)                         │
│   └── microsnippets/        (Reusable snippets)                       │
│                                                                        │
│ Storage:                                                               │
│ • PostgreSQL (global knowledge, cross-project patterns)               │
│ • redb (external package cache)                                        │
│ • JetStream KV (distributed cache)                                    │
└────────────────────────────────────────────────────────────────────────┘
                             ↑ learns from / shares to ↑
       ┌─────────────────────┴──────────┬───────────────┴──────────────┐
       ↓                                ↓                              ↓
┌──────────────────┐         ┌──────────────────┐         ┌──────────────────┐
│ SINGULARITY #1   │         │ SINGULARITY #2   │         │ SINGULARITY #3   │
│                  │         │                  │         │                  │
│ Project: Web App │         │ Project: ML Pipe │         │ Project: Game    │
│ (React + Elixir) │         │ (Python + Rust)  │         │ Engine (Rust)    │
│                  │         │                  │         │                  │
│ Components:      │         │ Components:      │         │ Components:      │
│ • singularity_app│         │ • singularity_app│         │ • singularity_app│
│ • rust/          │         │ • rust/          │         │ • rust/          │
│   (LOCAL NIFS)   │         │   (LOCAL NIFS)   │         │   (LOCAL NIFS)   │
│                  │         │                  │         │                  │
│ Local Analysis:  │         │ Local Analysis:  │         │ Local Analysis:  │
│ • MY code search │         │ • MY code search │         │ • MY code search │
│ • MY patterns    │         │ • MY patterns    │         │ • MY patterns    │
│ • MY quality     │         │ • MY quality     │         │ • MY quality     │
│                  │         │                  │         │                  │
│ Local Storage:   │         │ Local Storage:   │         │ Local Storage:   │
│ • PostgreSQL     │         │ • PostgreSQL     │         │ • PostgreSQL     │
│ • Project cache  │         │ • Project cache  │         │ • Project cache  │
└──────────────────┘         └──────────────────┘         └──────────────────┘
```

## Global Services (Shared by ALL)

### 🌍 rust/service/ (NATS Services)
**All services here are GLOBAL - run once, serve all instances**

```
rust/service/
├── template_service/          ⭐ GLOBAL - ALL templates
│   ├── src/
│   │   ├── code_templates.rs
│   │   ├── prompt_templates.rs
│   │   ├── quality_templates.rs
│   │   └── framework_templates.rs
│   └── Cargo.toml
│
├── package_service/           ⭐ GLOBAL - External packages
│   ├── src/
│   │   ├── npm_collector.rs
│   │   ├── cargo_collector.rs
│   │   └── hex_collector.rs
│   └── Cargo.toml
│
├── prompt_service/            ⭐ GLOBAL - Prompt templates
├── embedding_service/         ⭐ GLOBAL - Embeddings
├── knowledge_service/         ⭐ GLOBAL - Cross-project knowledge
└── quality_service/           ⭐ GLOBAL - Quality benchmarks
```

**Why GLOBAL?**
- ✅ Templates are learned from ALL projects
- ✅ Package registry serves all projects
- ✅ Prompt templates evolve from collective usage
- ✅ Quality benchmarks aggregate across projects
- ✅ Embeddings trained on all codebases

### 🌍 templates_data/ (Git-Backed Templates)
**Global template repository - single source of truth**

```
templates_data/
├── code_generation/           ⭐ Code templates (all languages)
│   ├── elixir/
│   ├── rust/
│   ├── typescript/
│   └── python/
│
├── frameworks/                ⭐ Framework-specific patterns
│   ├── phoenix.json
│   ├── react.json
│   └── django.json
│
├── workflows/                 ⭐ SPARC workflows
│   ├── research.json
│   ├── architecture.json
│   └── implementation.json
│
└── microsnippets/            ⭐ Reusable code patterns
    ├── error_handling/
    ├── authentication/
    └── testing/
```

**Why Git-Backed?**
- ✅ Version control for templates
- ✅ Easy review/approve learned templates
- ✅ Sync between machines
- ✅ Rollback if bad template added

### 🌍 rust-central/ (Legacy Central Services)
**Being migrated to rust/service/, but currently:**

```
rust-central/
├── package_analysis_suite/    ⭐ GLOBAL - Package analysis
├── tech_detection_engine/     ⭐ GLOBAL - Framework detection
├── analysis_engine/           ⭐ GLOBAL - Code analysis
└── semantic_embedding_engine/ ⭐ GLOBAL - Embeddings
```

## Local Components (Per-Project)

### 🏠 singularity_app/ (Elixir App)
**Project-specific Elixir application - copied per project**

```
singularity_app/
├── lib/singularity/
│   ├── code_search.ex         (uses local rust/ NIFs)
│   ├── quality_analyzer.ex    (uses local rust/ NIFs)
│   └── architecture_analyzer.ex
│
└── config/
    └── config.exs             (project-specific config)
```

### 🏠 rust/ (Local NIFs)
**Fast local analysis - compiled into BEAM**

```
rust/
├── architecture/              🏠 LOCAL NIF
│   ├── src/
│   │   ├── lib.rs            (core functionality)
│   │   └── nif.rs            (NIF wrapper, feature-gated)
│   └── Cargo.toml            [features] nif = ["rustler"]
│
├── code_analysis/             🏠 LOCAL NIF
│   ├── src/
│   │   ├── lib.rs
│   │   ├── nif.rs
│   │   ├── quality/
│   │   ├── search/
│   │   └── patterns/
│   └── Cargo.toml
│
└── knowledge/                 🏠 LOCAL NIF
    ├── src/
    │   ├── lib.rs
    │   └── nif.rs
    └── Cargo.toml
```

**Why LOCAL?**
- ✅ Fast: No NATS overhead
- ✅ Project-specific: Analyzes YOUR code
- ✅ Lightweight: Just NIFs, no services
- ✅ Embedded: Runs in BEAM process

## Communication Examples

### Example 1: Get Template (Global Service)

```
Local Instance #1
     ↓ NATS: "templates.code.get" {language: "elixir", pattern: "genserver"}
     ↓
Template Service (rust/service/template_service/)
     ↓ Load from templates_data/code_generation/elixir/genserver.json
     ↓ Return template
     ↓
Local Instance #1
     ↓ Use template to generate code
```

### Example 2: Analyze Local Code (Local NIF)

```
Local Instance #1
     ↓ Elixir: CodeAnalysis.search("payment processing")
     ↓ NIF call (no network!)
     ↓
rust/code_analysis (NIF)
     ↓ Search local PostgreSQL
     ↓ Return results
     ↓
Elixir
     ↓ Display results
```

### Example 3: Search External Packages (Global Service)

```
Local Instance #1
     ↓ NATS: "packages.search" {query: "async runtime", ecosystem: "cargo"}
     ↓
Package Service (rust/service/package_service/)
     ↓ Check JetStream KV cache
     ↓ MISS → Query redb
     ↓ MISS → Query PostgreSQL
     ↓ Return ["tokio", "async-std", "smol"]
     ↓
Local Instance #1
     ↓ Display package results
```

## Consolidation Strategy (REVISED)

### ✅ KEEP GLOBAL as Services

**DO NOT consolidate these - they stay as services:**
```
rust/service/template_service/     ← KEEP (global templates)
rust/service/package_service/      ← KEEP (external packages)
rust/service/prompt_service/       ← KEEP (prompt templates)
rust/service/embedding_service/    ← KEEP (global embeddings)
rust/service/knowledge_service/    ← KEEP (cross-project patterns)
rust/service/quality_service/      ← KEEP (quality benchmarks)
```

**Data:**
```
templates_data/                    ← KEEP (Git-backed templates)
rust-central/                      ← MIGRATE to rust/service/ gradually
```

### ✅ CONSOLIDATE LOCAL (Per-Project)

**Merge lib + engine for local NIFs:**
```
# Before (confusing)
rust/lib/code_lib/
rust/engine/code_engine/

# After (clear)
rust/code_analysis/
  ├── src/
  │   ├── lib.rs
  │   └── nif.rs   (feature-gated)
  └── Cargo.toml

# Same for all local domains:
rust/architecture/
rust/knowledge/
rust/semantic/
rust/quality/
```

## Summary: What Goes Where?

### 🌍 GLOBAL (rust/service/ + templates_data/)
- Templates (code, prompts, quality, frameworks)
- External packages (npm, cargo, hex, pypi)
- Cross-project learning
- Quality benchmarks
- Security vulnerability DB
- Framework detection patterns

**Runs:** Once, serves all instances
**Storage:** Central PostgreSQL, redb, Git (templates_data/)

### 🏠 LOCAL (rust/ NIFs + singularity_app/)
- YOUR code analysis
- YOUR project patterns
- YOUR quality metrics
- YOUR architecture

**Runs:** Per-project instance
**Storage:** Local PostgreSQL, local cache

## Migration Priority

1. **Phase 1:** Fix code_engine NIF (immediate)
2. **Phase 2:** Consolidate local rust/ (lib + engine merges)
3. **Phase 3:** Ensure rust/service/ templates work
4. **Phase 4:** Migrate rust-central/ to rust/service/ (gradual)

**Template service is GLOBAL and CRITICAL - don't touch during consolidation!**
