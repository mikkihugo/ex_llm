# Rust Monolib: 3-Layer Architecture with Trios

## 🎯 Design Principles

1. **3 Layers:** NIFs (client) → Libs (logic) → Services (NATS central)
2. **Global Gateway:** All requests flow through `knowledge_service` for caching
3. **Trios:** Each capability is a trio: `{name}_nif`, `{name}_lib`, `{name}_service`
4. **Package Suite:** Separate from trios - specialized tool for package registry indexing

---

## 📁 Directory Structure

```
rust/
├── nifs/                    # Layer 1: Rustler NIFs (Elixir .so bindings)
│   ├── parse_nif/           # Parser NIF
│   ├── analyze_nif/         # Analysis NIF
│   ├── generate_nif/        # Code generation NIF
│   ├── quality_nif/         # Quality checks NIF
│   └── embed_nif/           # Embeddings NIF
│
├── lib/                     # Layer 2: Pure Rust libraries
│   ├── parse_lib/           # Parser logic (tree-sitter, AST)
│   ├── analyze_lib/         # Analysis logic (graphs, architecture)
│   ├── generate_lib/        # Generation logic (templates, codegen)
│   ├── quality_lib/         # Quality logic (linting, metrics)
│   ├── embed_lib/           # Embedding logic (vectors, similarity)
│   └── knowledge_lib/       # 🌟 Caching/routing library
│
├── service/                 # Layer 3: NATS central services
│   ├── parse_service/       # Parser central (NATS: parse.central.*)
│   ├── analyze_service/     # Analysis central (NATS: analyze.central.*)
│   ├── generate_service/    # Generation central (NATS: generate.central.*)
│   ├── quality_service/     # Quality central (NATS: quality.central.*)
│   ├── embed_service/       # Embeddings central (NATS: embed.central.*)
│   └── knowledge_service/   # 🌟 Global gateway (NATS: knowledge.*)
│
└── tools/                   # Standalone CLI tools (NOT part of trios)
    └── package_indexer/     # Package registry indexer (npm/cargo/hex/pypi)
                             # (moved from rust-central/package_analysis_suite)
```

---

## 🔧 The 6 Core Trios

### 1. **Parse** (Code Parsing & AST)

| Layer | Component | Description |
|-------|-----------|-------------|
| **NIF** | `parse_nif` | Elixir-callable parser (Rustler) |
| **Lib** | `parse_lib` | Tree-sitter, AST extraction, multi-language |
| **Service** | `parse_service` | NATS central parser (`parse.central.*`) |

**Shared name:** `parse`

**What it does:**
- Parse source code into AST
- Extract symbols, imports, exports
- Support 30+ languages via tree-sitter

**Symlink:** `singularity_app/native/parse_nif → rust/nifs/parse_nif`

---

### 2. **Analyze** (Architecture & Code Analysis)

| Layer | Component | Description |
|-------|-----------|-------------|
| **NIF** | `analyze_nif` | Elixir-callable analyzer (Rustler) |
| **Lib** | `analyze_lib` | Dependency graphs, architecture analysis |
| **Service** | `analyze_service` | NATS central analyzer (`analyze.central.*`) |

**Shared name:** `analyze`

**What it does:**
- Build dependency graphs
- Detect circular dependencies
- Architecture pattern detection
- Call graph analysis

**Symlink:** `singularity_app/native/analyze_nif → rust/nifs/analyze_nif`

---

### 3. **Generate** (Code Generation)

| Layer | Component | Description |
|-------|-----------|-------------|
| **NIF** | `generate_nif` | Elixir-callable generator (Rustler) |
| **Lib** | `generate_lib` | Template engine, AST transformation |
| **Service** | `generate_service` | NATS central generator (`generate.central.*`) |

**Shared name:** `generate`

**What it does:**
- Template-based code generation
- AST transformation/refactoring
- Scaffold creation

**Symlink:** `singularity_app/native/generate_nif → rust/nifs/generate_nif`

---

### 4. **Quality** (Linting & Quality Checks)

| Layer | Component | Description |
|-------|-----------|-------------|
| **NIF** | `quality_nif` | Elixir-callable quality checker (Rustler) |
| **Lib** | `quality_lib` | Clippy integration, custom lints, metrics |
| **Service** | `quality_service` | NATS central quality checker (`quality.central.*`) |

**Shared name:** `quality`

**What it does:**
- Run Clippy/ESLint/etc
- Custom quality rules
- Code metrics (complexity, duplication)
- Security analysis

**Symlink:** `singularity_app/native/quality_nif → rust/nifs/quality_nif`

---

### 5. **Embed** (Embeddings & Semantic Search)

| Layer | Component | Description |
|-------|-----------|-------------|
| **NIF** | `embed_nif` | Elixir-callable embedder (Rustler) |
| **Lib** | `embed_lib` | Vector operations, similarity scoring |
| **Service** | `embed_service` | NATS central embedder (`embed.central.*`) |

**Shared name:** `embed`

**What it does:**
- Generate code embeddings
- Semantic similarity search
- Vector operations

**Symlink:** `singularity_app/native/embed_nif → rust/nifs/embed_nif`

---

## 🌟 Special: Knowledge Service (Global Gateway)

| Layer | Component | Description |
|-------|-----------|-------------|
| **NIF** | ❌ None | (Pure NATS service, no NIF needed) |
| **Lib** | `knowledge_lib` | Caching logic, routing algorithms |
| **Service** | `knowledge_service` | 🌟 Global caching gateway (`knowledge.*`) |

**Special role:** ALL other services route through this for:
- Multi-level caching (memory → redb → PostgreSQL)
- Request deduplication
- Rate limiting
- Cross-service coordination
- Distributed caching

**NATS Subjects:**
- `knowledge.get` - Fetch from cache
- `knowledge.set` - Store in cache
- `knowledge.invalidate` - Clear cache

---

## 🛠️ Standalone Tools (Not Trios)

### Package Indexer (`rust/tools/package_indexer`)

**Type:** Standalone CLI + NATS service (NOT a trio)

**Purpose:** Index package registries (npm, cargo, hex, pypi) for semantic search

**Features:**
- Crawl package registries
- Extract metadata (version, deps, docs, examples)
- Store in PostgreSQL with embeddings
- NATS service: `packages.registry.*`

**Why separate?**
- Different domain (package metadata vs. code analysis)
- Specialized storage (package_registry table)
- Runs independently from core trios
- Uses its own NATS subjects

**Migration:** `rust-central/package_analysis_suite` → `rust/tools/package_indexer`

---

## 🔄 Request Flow Examples

### Fast Path (NIF → Lib)

```
Elixir: Singularity.Parse.parse_file("foo.ex")
    ↓
parse_nif::parse_file()
    ↓
parse_lib::parse()
    ↓
AST (returned to Elixir)
```

### Slow Path (Service via Gateway)

```
Elixir: Singularity.Parse.parse_file_remote("foo.ex")
    ↓ NATS: knowledge.get
knowledge_service (check cache)
    ↓ (cache miss)
    ↓ NATS: parse.central.request
parse_service
    ↓ uses parse_lib
AST
    ↓ NATS: knowledge.set (cache result)
knowledge_service
    ↓ NATS: knowledge.response
Elixir: AST
```

### Package Search (Standalone Tool)

```
Elixir: PackageRegistry.search("async runtime", ecosystem: :cargo)
    ↓ NATS: packages.registry.search
package_indexer service
    ↓ Query PostgreSQL (package_registry table)
Results
    ↓ NATS: packages.registry.response
Elixir: [%{package: "tokio", version: "1.35"}]
```

---

## 📦 Dependencies Between Layers

### NIFs depend on Libs (no NATS)

```toml
# rust/nifs/parse_nif/Cargo.toml
[dependencies]
rustler = { workspace = true }
parse_lib = { path = "../../lib/parse_lib" }
# NO async-nats (NIFs are synchronous)
```

### Services depend on Libs + Knowledge Lib (with NATS)

```toml
# rust/service/parse_service/Cargo.toml
[dependencies]
async-nats = { workspace = true }
parse_lib = { path = "../../lib/parse_lib" }
knowledge_lib = { path = "../../lib/knowledge_lib" }  # For caching
```

### Libs are pure (no external dependencies)

```toml
# rust/lib/parse_lib/Cargo.toml
[dependencies]
tree-sitter = { workspace = true }
serde = { workspace = true }
# NO rustler, NO async-nats
```

### Tools are standalone

```toml
# rust/tools/package_indexer/Cargo.toml
[dependencies]
async-nats = { workspace = true }
tokio-postgres = "0.7"
reqwest = { workspace = true }
# Does NOT depend on trios
```

---

## 🔗 Elixir Integration

### NIFs (Symlinked)

```bash
singularity_app/native/
├── parse_nif -> ../../rust/nifs/parse_nif/
├── analyze_nif -> ../../rust/nifs/analyze_nif/
├── generate_nif -> ../../rust/nifs/generate_nif/
├── quality_nif -> ../../rust/nifs/quality_nif/
└── embed_nif -> ../../rust/nifs/embed_nif/
```

### Elixir Modules

```elixir
# NIFs (fast path)
Singularity.Parse.NIF.parse_file(path)          # Calls parse_nif
Singularity.Analyze.NIF.analyze_deps(path)      # Calls analyze_nif

# Services (slow path, via NATS + gateway)
Singularity.Parse.Service.parse_remote(path)    # NATS → knowledge_service → parse_service
Singularity.Analyze.Service.analyze_remote(path) # NATS → knowledge_service → analyze_service

# Smart wrappers (tries NIF, falls back to service)
Singularity.Parse.parse_file(path)              # NIF first, then service
Singularity.Analyze.analyze_deps(path)          # NIF first, then service

# Package search (standalone)
Singularity.PackageRegistry.search(query, opts) # NATS → package_indexer service
```

---

## 🚀 Migration Plan

### Step 1: Create Structure

```bash
# Already done
mkdir -p rust/{nifs,lib,service,tools}
```

### Step 2: Migrate Trios

| From (rust-central/) | To Trio |
|---------------------|---------|
| `parser_engine/` → | `parse_nif`, `parse_lib`, `parse_service` |
| `architecture_engine/` + `analysis_engine/` → | `analyze_nif`, `analyze_lib`, `analyze_service` |
| `generator_engine/` + `code_engine/` → | `generate_nif`, `generate_lib`, `generate_service` |
| `quality_engine/` + `linting_engine/` → | `quality_nif`, `quality_lib`, `quality_service` |
| `semantic_engine/` + `embedding_engine/` → | `embed_nif`, `embed_lib`, `embed_service` |

### Step 3: Migrate Gateway

| From | To |
|------|-----|
| `knowledge_central_service/` → | `knowledge_lib`, `knowledge_service` |

### Step 4: Migrate Tools

| From | To |
|------|-----|
| `package_analysis_suite/` → | `tools/package_indexer/` |

### Step 5: Update Symlinks

```bash
cd singularity_app/native
ln -sf ../../rust/nifs/parse_nif parse_nif
ln -sf ../../rust/nifs/analyze_nif analyze_nif
ln -sf ../../rust/nifs/generate_nif generate_nif
ln -sf ../../rust/nifs/quality_nif quality_nif
ln -sf ../../rust/nifs/embed_nif embed_nif
```

---

## 📝 Summary: All Components

### Trios (5)

| Trio Name | NIF | Lib | Service | Shared Name |
|-----------|-----|-----|---------|-------------|
| Parser | `parse_nif` | `parse_lib` | `parse_service` | `parse` |
| Analyzer | `analyze_nif` | `analyze_lib` | `analyze_service` | `analyze` |
| Generator | `generate_nif` | `generate_lib` | `generate_service` | `generate` |
| Quality | `quality_nif` | `quality_lib` | `quality_service` | `quality` |
| Embeddings | `embed_nif` | `embed_lib` | `embed_service` | `embed` |

### Gateway (1)

| Component | NIF | Lib | Service | Role |
|-----------|-----|-----|---------|------|
| Knowledge | ❌ None | `knowledge_lib` | `knowledge_service` | 🌟 Global caching gateway |

### Tools (1)

| Tool | Type | Purpose |
|------|------|---------|
| `package_indexer` | Standalone CLI + NATS service | Index package registries (npm/cargo/hex/pypi) |

---

## ✅ Benefits

1. **Clear layering:** NIFs ≠ Services ≠ Libs
2. **Reusable logic:** Libs shared by NIFs and Services
3. **Global caching:** All requests flow through `knowledge_service`
4. **Testable:** Libs are pure Rust
5. **Scalable:** Services run distributed
6. **Separation of concerns:** Package indexing separate from code analysis
