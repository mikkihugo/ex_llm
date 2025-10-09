# Rust Engine & Library Architecture Map

## Overview

Singularity has **three** Rust directory structures with different purposes:

1. **`rust/`** - Active workspace (current architecture)
2. **`rust_backup/`** - Old engine-based architecture (being phased out)
3. **`rust_global/`** - Global services (analysis, embedding engines)

---

## 1. Active Architecture: `rust/`

**Status:** ✅ **CURRENT** - Domain-organized workspace

### Structure

```
rust/
├── architecture/           # Architecture analysis
├── code_analysis/          # Code quality & metrics
├── embedding/              # High-level embedding wrapper
├── framework/              # Framework detection & patterns
├── knowledge/              # Knowledge management
├── package/                # Package registry intelligence
├── parser/                 # Multi-language parsing (Tree-sitter)
│   ├── core/              # Parser core abstractions
│   ├── polyglot/          # Multi-language support (NIF)
│   ├── formats/           # Format parsers (TOML, JSON)
│   ├── languages/         # Language-specific parsers
│   └── analyzers/         # rust_code_analysis integration
├── prompt/                 # Prompt generation
├── quality/                # Code quality standards
├── semantic/               # Semantic analysis (NIF)
├── service/                # Microservices
│   ├── intelligence_hub/  # Central intelligence service
│   ├── package_intelligence/ # Package analysis service
│   └── knowledge_cache/   # Knowledge caching service
└── template/               # Template system
```

### Key Files

| Component | Cargo.toml | Purpose |
|-----------|------------|---------|
| **embedding** | `rust/embedding/Cargo.toml` | Wrapper around `semantic_engine` (⚠️ broken reference) |
| **semantic** | `rust/semantic/Cargo.toml` | Semantic NIF (`nif.rs`) |
| **parser/polyglot** | `rust/parser/polyglot/Cargo.toml` | Multi-language parser NIF |
| **package** | `rust/package/Cargo.toml` | Package intelligence |

### Workspace Members (24 crates)

From `rust/Cargo.toml`:
```toml
members = [
    "architecture",
    "code_analysis",
    "embedding",               # ⚠️ References missing engine/semantic_engine
    "framework",
    "knowledge",
    "package",
    "parser/core",
    "parser/polyglot",         # ✅ Main parser NIF
    "parser/formats/dependency",
    "parser/formats/template_definitions",
    "parser/languages/rust",
    "parser/languages/elixir",
    "parser/languages/python",
    "parser/languages/javascript",
    "parser/languages/typescript",
    "parser/languages/gleam",
    "prompt",
    "quality",
    "semantic",                # ✅ Semantic NIF
    "template",
]
```

---

## 2. Legacy Architecture: `rust_backup/engine/`

**Status:** 📦 **DEPRECATED** - Old engine-based architecture

### Structure

```
rust_backup/engine/
├── architecture_engine/    # Architecture analysis engine
├── code_engine/            # Code analysis engine
├── framework_engine/       # Framework detection engine
├── knowledge_engine/       # Knowledge management engine
├── package_engine/         # Package analysis engine
├── parser_engine/          # Code parsing engine
├── prompt_engine/          # Prompt generation engine
├── quality_engine/         # Code quality engine
└── semantic_engine/        # ⚠️ Semantic & embedding engine
```

### Key Finding: `semantic_engine`

**Location:** `rust_backup/engine/semantic_engine/`

This is what `rust/embedding/Cargo.toml` references but is in the wrong location:

```toml
# rust/embedding/Cargo.toml line 16
semantic_engine = { path = "../../engine/semantic_engine" }
```

**Issue:** The path should be `../../rust_backup/engine/semantic_engine` but the reference is outdated.

---

## 3. Global Services: `rust_global/`

**Status:** 🌐 **GLOBAL** - Shared services for multiple instances

### Structure

```
rust_global/
├── analysis_engine/              # Unified analysis engine
├── semantic_embedding_engine/    # ✅ ACTIVE embedding engine (Jina v3, CodeT5)
├── tech_detection_engine/        # Technology detection
├── intelligent_namer/            # Smart naming suggestions
├── dependency_parser/            # Dependency analysis
└── package_analysis_suite/       # Package ecosystem tools
```

### Key Component: `semantic_embedding_engine`

**Location:** `rust_global/semantic_embedding_engine/`

**Purpose:** High-performance embedding generation with GPU support

#### Features

From `rust_global/semantic_embedding_engine/Cargo.toml`:

```toml
[package]
name = "embedding_engine"
description = "Embedding engine for generating vector embeddings using Jina v3 and CodeT5 models"

[dependencies]
# ONNX Runtime for Jina v3 with CUDA support
ort = { version = "2.0.0-rc.10", features = ["load-dynamic"], optional = true }

# Candle for Qodo-Embed-1 with CUDA support
candle-core = { version = "0.9", optional = true }
candle-nn = { version = "0.9", optional = true }
candle-transformers = { version = "0.9", optional = true }

[features]
default = ["cpu"]
cpu = ["candle-core", "candle-nn", "candle-transformers", "ort"]
cuda = ["candle-core/cuda", "candle-nn/cuda", "candle-transformers/cuda", "ort/cuda"]
```

#### Source Files

```
rust_global/semantic_embedding_engine/src/
├── lib.rs                # Main NIF interface
├── models.rs             # Model management (Jina v3, Qodo-Embed-1)
├── downloader.rs         # Model downloading
├── tokenizer_cache.rs    # Tokenizer caching
├── training.rs           # Training infrastructure
└── training_config.rs    # Training configuration
```

#### Supported Models

1. **Jina v3** (jinaai/jina-embeddings-v3)
   - 1024 dimensions
   - ONNX Runtime
   - CUDA support

2. **Qodo-Embed-1** (Qodo/qodo-embed-1)
   - 768 dimensions
   - Candle framework
   - CUDA support

3. **CodeT5** Integration
   - Training support (`training.rs`)
   - Custom fine-tuning

---

## Broken Reference Analysis

### The Problem

`rust/embedding/Cargo.toml` references:
```toml
semantic_engine = { path = "../../engine/semantic_engine" }
```

This path resolves to: `/home/mhugo/code/singularity/engine/semantic_engine` (doesn't exist)

### Actual Locations

1. **Old engine:** `rust_backup/engine/semantic_engine/` (deprecated)
2. **New engine:** `rust_global/semantic_embedding_engine/` (active)

### Solution Options

#### Option 1: Fix Reference (Use rust_global)
```toml
# rust/embedding/Cargo.toml
[dependencies]
embedding_engine = { path = "../../rust_global/semantic_embedding_engine" }
```

#### Option 2: Remove Wrapper (Use rust_global directly)
Delete `rust/embedding/` and use `rust_global/semantic_embedding_engine/` directly from Elixir.

#### Option 3: Inline Implementation
Move embedding logic into `rust/semantic/` and remove dependency.

---

## Current State Summary

### ✅ Working Components

1. **Parser System** (`rust/parser/`)
   - `polyglot` NIF for multi-language parsing
   - Tree-sitter integration
   - Used by `Singularity.ParserEngine`

2. **Semantic NIF** (`rust/semantic/`)
   - Basic semantic analysis
   - NIF interface (`nif.rs`)

3. **Global Embedding Engine** (`rust_global/semantic_embedding_engine/`)
   - Jina v3 + Qodo-Embed-1 + CodeT5
   - GPU acceleration (CUDA)
   - Training infrastructure

### ⚠️ Broken Components

1. **Embedding Wrapper** (`rust/embedding/`)
   - References non-existent `../../engine/semantic_engine`
   - Should reference `rust_global/semantic_embedding_engine`

### 📦 Deprecated Components

1. **All of `rust_backup/engine/`**
   - Old architecture being phased out
   - Contains `semantic_engine` that embedding wrapper references

---

## Recommendations

### Immediate Actions

1. **Fix `rust/embedding/Cargo.toml`:**
   ```bash
   # Option A: Update path
   cd rust/embedding
   # Edit Cargo.toml to reference rust_global/semantic_embedding_engine

   # Option B: Delete wrapper, use rust_global directly
   rm -rf rust/embedding
   ```

2. **Update Elixir Code:**
   ```elixir
   # If using rust/embedding (broken)
   alias Singularity.EmbeddingEngine  # Currently broken

   # Use Google AI instead (working)
   alias Singularity.EmbeddingGenerator  # Uses Google AI (FREE)
   ```

3. **Test Rust Global Engine:**
   ```bash
   cd rust_global/semantic_embedding_engine
   cargo build --features cuda  # With GPU
   cargo build                   # CPU only
   ```

### Long-Term Strategy

1. **Consolidate Architecture:**
   - Move `rust_global/semantic_embedding_engine` → `rust/embedding/`
   - Update all references
   - Remove `rust_backup/`

2. **NIF Integration:**
   - Expose `embedding_engine` as Elixir NIF
   - Replace Google AI calls with local Jina v3/Qodo-Embed-1
   - GPU acceleration for faster embeddings

3. **Training Pipeline:**
   - Use `training.rs` for CodeT5 fine-tuning
   - Integrate with `ai-server/scripts/train_rust_elixir_t5.py`
   - Store models in `~/.cache/singularity/models/`

---

## Quick Reference

### Where is X?

| What | Location | Status |
|------|----------|--------|
| **Parser (Tree-sitter)** | `rust/parser/polyglot/` | ✅ Active |
| **Semantic NIF** | `rust/semantic/` | ✅ Active |
| **Embedding Engine (Jina/CodeT5)** | `rust_global/semantic_embedding_engine/` | ✅ Active |
| **Embedding Wrapper** | `rust/embedding/` | ⚠️ Broken |
| **Old Semantic Engine** | `rust_backup/engine/semantic_engine/` | 📦 Deprecated |
| **Package Intelligence** | `rust/package/` | ✅ Active |
| **Services** | `rust/service/` | ✅ Active |

### Build Commands

```bash
# Build entire workspace
cd rust
cargo build --workspace

# Build specific component
cd rust/parser/polyglot
cargo build --release

# Build embedding engine (GPU)
cd rust_global/semantic_embedding_engine
cargo build --release --features cuda

# Build embedding engine (CPU)
cd rust_global/semantic_embedding_engine
cargo build --release
```

### Test Commands

```bash
# Test workspace
cd rust
cargo test --workspace

# Test specific component
cd rust/parser/polyglot
cargo test

# Benchmark embedding engine
cd rust_global/semantic_embedding_engine
cargo bench
```

---

## Next Steps

1. Run: `cd rust/embedding && cat Cargo.toml` to verify the broken reference
2. Decide: Use rust_global engine directly OR fix the wrapper
3. Update: Elixir code to use correct engine
4. Test: Generate embeddings with Jina v3 (faster than Google AI)
5. Train: Fine-tune CodeT5 on your Rust/Elixir code
