# Clean rust-central Monorepo Structure

## Problem: Naming Confusion

Currently we have:
- `prompt_engine/` - Is this a lib or service?
- `code_engine/` - Is this a NIF or standalone?
- `knowledge_cache_engine/` - Rust or Elixir?

**Solution:** Clear naming convention like a proper Rust monorepo!

---

## Monorepo Structure (Like Cargo Workspaces)

```
rust-central/
├── Cargo.toml                      # Workspace root
│
├── libs/                           # Shared libraries
│   ├── prompt/                     # Prompt logic (DSPy, templates)
│   ├── knowledge/                  # Knowledge types, traits
│   ├── analysis/                   # Analysis utilities
│   ├── quality/                    # Quality checking logic
│   └── common/                     # Shared types, utilities
│
├── nifs/                           # Elixir NIFs
│   ├── architecture/               # Architecture detection
│   ├── code_analyzer/              # Code analysis
│   ├── embedding/                  # GPU embeddings
│   ├── parser/                     # AST parsing
│   └── quality/                    # Quality checks
│
└── services/                       # NATS standalone services
    ├── knowledge_central/          # Code knowledge hub
    ├── prompt_central/             # Prompt optimization
    └── unified_analysis/           # Unified analysis service
```

---

## Detailed Structure

### Workspace Root
```toml
# rust-central/Cargo.toml
[workspace]
members = [
    # Libraries
    "libs/prompt",
    "libs/knowledge",
    "libs/analysis",
    "libs/quality",
    "libs/common",

    # NIFs
    "nifs/architecture",
    "nifs/code_analyzer",
    "nifs/embedding",
    "nifs/parser",
    "nifs/quality",

    # Services
    "services/knowledge_central",
    "services/prompt_central",
    "services/unified_analysis",
]

[workspace.dependencies]
# Shared dependencies
anyhow = "1.0"
serde = { version = "1.0", features = ["derive"] }
tokio = { version = "1.0", features = ["full"] }
async-nats = "0.35"
rustler = "0.34"
```

---

## Libraries (`libs/`)

### `libs/prompt/`
**Purpose:** Prompt optimization, DSPy, template management
**Used by:** `services/prompt_central`, NIFs

```toml
# libs/prompt/Cargo.toml
[package]
name = "prompt"
version = "0.1.0"

[dependencies]
serde = { workspace = true }
anyhow = { workspace = true }
```

```rust
// libs/prompt/src/lib.rs
pub mod dspy;
pub mod templates;
pub mod optimization;

pub struct Prompt {
    pub content: String,
    pub version: String,
}

pub trait PromptOptimizer {
    fn optimize(&self, prompt: &str) -> Result<Prompt>;
}
```

### `libs/knowledge/`
**Purpose:** Knowledge types, asset definitions
**Used by:** All services and NIFs

```toml
# libs/knowledge/Cargo.toml
[package]
name = "knowledge"

[dependencies]
serde = { workspace = true }
```

```rust
// libs/knowledge/src/lib.rs
pub struct KnowledgeAsset {
    pub id: String,
    pub asset_type: AssetType,
    pub content: String,
}

pub enum AssetType {
    Pattern,
    Template,
    Package,
}
```

### `libs/common/`
**Purpose:** Shared utilities, types
**Used by:** Everything

```rust
// libs/common/src/lib.rs
pub mod error;
pub mod config;
pub mod nats;
```

---

## NIFs (`nifs/`)

### `nifs/architecture/`
**Purpose:** Architecture detection NIF
**Exports:** `libarchitecture.so`

```toml
# nifs/architecture/Cargo.toml
[package]
name = "architecture_nif"

[lib]
name = "architecture"
crate-type = ["cdylib"]

[dependencies]
rustler = { workspace = true }
knowledge = { path = "../../libs/knowledge" }
common = { path = "../../libs/common" }
```

```rust
// nifs/architecture/src/lib.rs
use rustler::NifResult;

#[rustler::nif]
fn detect_architecture(code: String) -> NifResult<String> {
    // Implementation
    Ok("Phoenix".to_string())
}

rustler::init!("Elixir.Singularity.Architecture", [detect_architecture]);
```

### `nifs/parser/`
**Purpose:** AST parsing NIF
**Exports:** `libparser.so`

```
nifs/parser/
├── Cargo.toml
├── src/
│   ├── lib.rs              # NIF entry point
│   └── parsers/
│       ├── elixir.rs
│       ├── rust.rs
│       └── typescript.rs
└── languages/              # Sub-crates
    ├── elixir/
    ├── rust/
    └── typescript/
```

---

## Services (`services/`)

### `services/knowledge_central/`
**Purpose:** NATS service for code knowledge
**Binary:** `knowledge_central`

```toml
# services/knowledge_central/Cargo.toml
[package]
name = "knowledge_central"

[[bin]]
name = "knowledge_central"
path = "src/main.rs"

[dependencies]
async-nats = { workspace = true }
tokio = { workspace = true }
knowledge = { path = "../../libs/knowledge" }
common = { path = "../../libs/common" }
sqlx = { version = "0.7", features = ["postgres"] }
```

```rust
// services/knowledge_central/src/main.rs
use knowledge::KnowledgeAsset;

#[tokio::main]
async fn main() {
    // Start NATS service
}
```

### `services/prompt_central/`
**Purpose:** NATS service for prompt optimization
**Binary:** `prompt_central`

```toml
# services/prompt_central/Cargo.toml
[package]
name = "prompt_central"

[[bin]]
name = "prompt_central"
path = "src/main.rs"

[dependencies]
async-nats = { workspace = true }
prompt = { path = "../../libs/prompt" }
common = { path = "../../libs/common" }
```

```rust
// services/prompt_central/src/main.rs
use prompt::{Prompt, PromptOptimizer};

#[tokio::main]
async fn main() {
    // Start NATS service for prompt optimization
}
```

---

## Migration Plan

### Current → New

| Current | New | Type |
|---------|-----|------|
| `prompt_engine/` | `libs/prompt/` | Library |
| `prompt_central_service/` | `services/prompt_central/` | Service |
| `knowledge_cache_engine/` | ❌ Delete (pure Elixir) | - |
| `architecture_engine/` | `nifs/architecture/` | NIF |
| `code_engine/` | `nifs/code_analyzer/` | NIF |
| `embedding_engine/` | `nifs/embedding/` | NIF |
| `parser_engine/` | `nifs/parser/` | NIF |
| `quality_engine/` | `nifs/quality/` | NIF |
| `analysis_engine/` | `libs/analysis/` | Library |

### Steps

1. **Create new structure:**
```bash
cd rust-central
mkdir -p libs/{prompt,knowledge,analysis,quality,common}
mkdir -p nifs/{architecture,code_analyzer,embedding,parser,quality}
mkdir -p services/{knowledge_central,prompt_central}
```

2. **Move libraries:**
```bash
mv prompt_engine/* libs/prompt/
mv analysis_engine/* libs/analysis/
```

3. **Move NIFs:**
```bash
mv architecture_engine/* nifs/architecture/
mv code_engine/* nifs/code_analyzer/
mv embedding_engine/* nifs/embedding/
mv parser_engine/* nifs/parser/
mv quality_engine/* nifs/quality/
```

4. **Move services:**
```bash
mv knowledge_central_service/* services/knowledge_central/
mv prompt_central_service/* services/prompt_central/
```

5. **Update Cargo.toml references:**
```toml
# In nifs/architecture/Cargo.toml
[dependencies]
knowledge = { path = "../../libs/knowledge" }

# In services/prompt_central/Cargo.toml
[dependencies]
prompt = { path = "../../libs/prompt" }
```

6. **Update native/ symlinks:**
```bash
cd singularity_app/native
rm architecture_engine
ln -s ../../rust-central/nifs/architecture architecture
```

---

## Benefits

### ✅ Clear Organization
```
libs/      → "These are libraries"
nifs/      → "These are Elixir NIFs"
services/  → "These are NATS services"
```

### ✅ No Naming Confusion
```
libs/prompt                  → Clearly a library
services/prompt_central      → Clearly a service
nifs/architecture           → Clearly a NIF
```

### ✅ Easy to Find
```
"Where's the prompt logic?"        → libs/prompt/
"Where's the prompt service?"      → services/prompt_central/
"Where's the architecture NIF?"    → nifs/architecture/
```

### ✅ Proper Dependency Graph
```
services/prompt_central
    ↓ depends on
libs/prompt
    ↓ depends on
libs/common
```

### ✅ Follows Rust Conventions
Like other large Rust projects:
- tokio: `tokio/`, `tokio-util/`, `tokio-stream/`
- serde: `serde/`, `serde_derive/`, `serde_json/`

---

## Final Structure

```
rust-central/
├── Cargo.toml                          # Workspace root
│
├── libs/                               # Shared libraries
│   ├── prompt/                         # DSPy, templates, optimization
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── dspy.rs
│   │       └── templates.rs
│   │
│   ├── knowledge/                      # Knowledge types, traits
│   │   └── src/lib.rs
│   │
│   ├── analysis/                       # Analysis utilities
│   │   └── src/lib.rs
│   │
│   ├── quality/                        # Quality rules, checks
│   │   └── src/lib.rs
│   │
│   └── common/                         # Shared utilities
│       └── src/
│           ├── error.rs
│           ├── config.rs
│           └── nats.rs
│
├── nifs/                               # Elixir NIFs (.so files)
│   ├── architecture/                   # Architecture detection
│   │   ├── Cargo.toml                  # crate-type = ["cdylib"]
│   │   └── src/lib.rs                  # rustler::init!()
│   │
│   ├── code_analyzer/                  # Code analysis
│   ├── embedding/                      # GPU embeddings
│   ├── parser/                         # AST parsing
│   └── quality/                        # Quality checks
│
└── services/                           # NATS services (binaries)
    ├── knowledge_central/              # Code knowledge hub
    │   ├── Cargo.toml                  # [[bin]]
    │   └── src/
    │       ├── main.rs                 # NATS server
    │       └── handlers/
    │
    └── prompt_central/                 # Prompt optimization
        ├── Cargo.toml                  # [[bin]]
        └── src/
            ├── main.rs                 # NATS server
            └── optimizer.rs
```

---

## Elixir Integration

### Symlinks from singularity_app/native/

```bash
singularity_app/native/
├── architecture -> ../../rust-central/nifs/architecture
├── code_analyzer -> ../../rust-central/nifs/code_analyzer
├── embedding -> ../../rust-central/nifs/embedding
├── parser -> ../../rust-central/nifs/parser
└── quality -> ../../rust-central/nifs/quality
```

### Mix.exs

```elixir
def deps do
  [
    {:architecture, path: "native/architecture", runtime: false, app: false, compile: false},
    {:code_analyzer, path: "native/code_analyzer", runtime: false, app: false, compile: false},
    {:embedding, path: "native/embedding", runtime: false, app: false, compile: false},
    {:parser, path: "native/parser", runtime: false, app: false, compile: false},
    {:quality, path: "native/quality", runtime: false, app: false, compile: false},
  ]
end
```

---

## Summary

**Question:** How should we rearrange as a real monorepo?

**Answer:**
1. **`libs/`** - Shared Rust libraries
2. **`nifs/`** - Elixir NIFs (cdylib)
3. **`services/`** - NATS services (binaries)

**Benefits:**
- ✅ Crystal clear organization
- ✅ No naming confusion
- ✅ Follows Rust conventions
- ✅ Easy to navigate
- ✅ Proper dependency management

**Next step:** Run the migration script to reorganize!
