# Final rust-central Structure

## Naming Convention: *_engine for Libraries, *_service for NATS Services

---

## Directory Structure

```
rust-central/
├── NIFs (Elixir-consumed libraries)
│   ├── architecture_engine/          # NIF
│   ├── code_engine/                  # NIF
│   ├── embedding_engine/             # NIF
│   ├── parser_engine/                # NIF (renamed from parser-engine)
│   ├── quality_engine/               # NIF
│   ├── generator_engine/             # NIF
│   └── knowledge_cache_engine/       # NIF (implements ETS + PG caching)
│
├── Libraries (Standalone Rust libs)
│   ├── prompt_engine/                # Library (DSPy, prompt optimization)
│   ├── analysis_engine/              # Library
│   ├── linting_engine/               # Library
│   └── semantic_embedding_engine/    # Library
│
├── Services (NATS standalone binaries)
│   ├── knowledge_central_service/    # NATS service (code knowledge hub)
│   ├── prompt_central_service/       # NATS service (prompt optimization)
│   ├── codeintelligence_server/      # NATS service
│   ├── consolidated_detector/        # NATS service
│   └── unified_server/               # NATS service
│
└── Tools
    ├── analysis_suite/
    ├── package_analysis_suite/
    └── tool_doc_index/
```

---

## Service Naming Rules

### Libraries End with `_engine`
- Used as dependencies by other code
- Can be NIFs or standalone libraries
- Examples: `prompt_engine`, `code_engine`, `quality_engine`

### Services End with `_service` or `_server`
- Standalone binaries that run as NATS services
- Examples: `knowledge_central_service`, `prompt_central_service`

---

## Prompt Architecture

### `prompt_engine/` (Library)
**Type:** Rust library
**Used by:** `prompt_central_service`, NIFs, other services
**Purpose:** Core prompt logic (DSPy, templates, optimization algorithms)

```toml
[package]
name = "prompt-engine"
```

**Features:**
- DSPy optimization algorithms
- Prompt template management
- Performance tracking
- Token usage calculation

### `prompt_central_service/` (NATS Service)
**Type:** Standalone binary (`src/main.rs`)
**Listens on:** `prompt.central.*` NATS subjects
**Purpose:** Centralized prompt management

```toml
[package]
name = "prompt_central_service"

[[bin]]
name = "prompt_central_service"
path = "src/main.rs"

[dependencies]
prompt-engine = { path = "../prompt_engine" }
```

**Features:**
- Serves prompts via NATS
- Runs DSPy optimization (using `prompt_engine` library)
- Tracks performance across all nodes
- A/B testing
- Broadcasts updated prompts

---

## Knowledge Cache Architecture

### `knowledge_cache_engine/` (NIF)
**Type:** Rustler NIF (but implements Elixir ETS + PostgreSQL pattern)
**Purpose:** Just the NIF interface, actual caching in Elixir

**Wait, confusion here!** Let me clarify:

### CORRECTED: `knowledge_cache_engine` Should Be Pure Elixir

Actually, for knowledge cache, we should **NOT have a Rust NIF**. It should be pure Elixir:

```elixir
# lib/singularity/knowledge_cache_engine.ex
defmodule Singularity.KnowledgeCacheEngine do
  use GenServer

  # L1: ETS
  # L2: PostgreSQL
  # L3: NATS → knowledge_central_service
end
```

### `knowledge_central_service/` (NATS Service)
**Type:** Standalone Rust binary
**Purpose:** Central hub for code knowledge

```toml
[package]
name = "knowledge_central_service"

[[bin]]
name = "knowledge_central_service"
```

---

## Updated rust-central Structure

```
rust-central/
├── NIFs (Elixir .so bindings)
│   ├── architecture_engine/          ✅ NIF
│   ├── code_engine/                  ✅ NIF
│   ├── embedding_engine/             ✅ NIF
│   ├── parser_engine/                ✅ NIF
│   ├── quality_engine/               ✅ NIF
│   └── generator_engine/             ✅ NIF
│
├── Libraries (Rust libs, not NIFs)
│   ├── prompt_engine/                ✅ Library
│   ├── analysis_engine/              ✅ Library
│   ├── linting_engine/               ✅ Library
│   └── semantic_embedding_engine/    ✅ Library
│
└── Services (NATS binaries)
    ├── knowledge_central_service/    ✅ NATS service
    ├── prompt_central_service/       ✅ NATS service
    ├── codeintelligence_server/      ✅ NATS service
    └── unified_server/               ✅ NATS service
```

**Note:** `knowledge_cache_engine` is **NOT in rust-central** - it's pure Elixir in `singularity_app/lib/singularity/knowledge_cache_engine.ex`

---

## Elixir Naming

### Elixir Modules (in singularity_app/lib/)

```elixir
# Cache engine (pure Elixir, no NIF)
Singularity.KnowledgeCacheEngine

# Central service client (calls NATS)
Singularity.KnowledgeCentralService

# Prompt service client (calls NATS)
Singularity.PromptCentralService

# NIFs (Rust bindings)
Singularity.ArchitectureEngine
Singularity.CodeEngine
Singularity.EmbeddingEngine
Singularity.QualityEngine
```

---

## Full Example

### 1. Elixir calls cache
```elixir
KnowledgeCacheEngine.get("pattern:async-worker")
# ↓ Check ETS
# ↓ Check PostgreSQL
# ↓ NATS → knowledge_central_service
```

### 2. Central service responds
```rust
// knowledge_central_service/src/main.rs
async fn handle_query(asset_id: String) -> Result<Asset> {
    query_postgres(&asset_id).await
}
```

### 3. Prompt optimization
```elixir
PromptCentralService.get_system_prompt("code-generation")
# ↓ NATS → prompt_central_service
```

```rust
// prompt_central_service/src/main.rs
use prompt_engine::DSpyOptimizer;

async fn handle_get_prompt(task: String) -> Result<Prompt> {
    // Use prompt_engine library
    let optimizer = DSpyOptimizer::new();
    optimizer.get_optimized_prompt(&task).await
}
```

---

## Summary

| Component | Type | Location |
|-----------|------|----------|
| **knowledge_cache_engine** | Pure Elixir | `singularity_app/lib/` |
| **knowledge_central_service** | Rust NATS service | `rust-central/knowledge_central_service/` |
| **prompt_engine** | Rust library | `rust-central/prompt_engine/` |
| **prompt_central_service** | Rust NATS service | `rust-central/prompt_central_service/` |
| **code_engine** | Rust NIF | `rust-central/code_engine/` |
| **quality_engine** | Rust NIF | `rust-central/quality_engine/` |

**Naming:**
- `*_engine` = Library (Rust lib or NIF)
- `*_service` = NATS service (standalone binary)
- `*_cache_engine` = Pure Elixir cache implementation
