# rust-central/ Monorepo Structure

**Single source of truth for all Rust code in Singularity**

Created: 2025-10-09

## Directory Structure

```
rust-central/              # Independent Rust monorepo
├── NIFs (Elixir-consumed)
│   ├── architecture_engine/    ✅ Active (420KB .so)
│   ├── code_engine/            ⚠️  Has NIF, needs .so build
│   ├── embedding_engine/       ✅ Active (391KB .so)
│   ├── parser_engine/          ✅ Active (11MB .so)
│   ├── prompt_intelligence/    ✅ Active (691KB .so)
│   ├── quality_engine/         ⚠️  Has NIF, needs .so build
│   ├── generator_engine/       ❌ Stub, not used
│   ├── knowledge_cache_engine/ ❌ Stub, not used
│   ├── knowledge_central_service/ ❌ Stub, not used
│   └── semantic_engine/        ❌ Stub, not used
│
├── Standalone Tools
│   ├── analysis_engine/
│   ├── analysis_suite/
│   ├── code_parsing_engine/
│   ├── linting_engine/
│   ├── package_analysis_suite/
│   ├── prompt_engine/
│   ├── semantic_embedding_engine/
│   ├── tech_detection_engine/
│   └── tool_doc_index/
│
├── Services
│   ├── codeintelligence_server/
│   ├── consolidated_detector/
│   └── unified_server/
│
└── Other
    ├── dependency-parser/
    ├── dependency_parser/     # Duplicate?
    ├── intelligent_namer/
    ├── mozilla-code-analysis/
    └── parser_framework/
```

## Active NIFs (6 total)

### 1. architecture_engine ✅
**Status:** Working
**Binary:** `libarchitecture_engine.so` (420KB)
**Elixir:** `Singularity.ArchitectureEngine`
**Functions:**
- Architecture detection
- Meta-registry integration
- Naming suggestions

**Rust NIF module:** `Elixir.Singularity.ArchitectureEngine`

---

### 2. code_engine ⚠️
**Status:** NIF exists, needs .so build
**Binary:** Missing (need to build)
**Elixir:** `Singularity.CodeEngine` + `Singularity.RustAnalyzer`
**Functions:**
- `analyze_control_flow/1` - Control flow analysis

**Rust NIF module:** `Elixir.Singularity.RustAnalyzer`

**TODO:** Build with `cargo build --release --lib` in `rust-central/code_engine`

---

### 3. embedding_engine ✅
**Status:** Working
**Binary:** `libembedding_engine.so` (391KB)
**Elixir:** `Singularity.EmbeddingEngine`
**Functions:**
- GPU-accelerated embeddings
- Semantic search

**Rust NIF module:** `Elixir.Singularity.EmbeddingEngine`

---

### 4. parser_engine ✅
**Status:** Working
**Binary:** `libparser_engine.so` (11MB)
**Elixir:** `Singularity.ParserEngine.Native`
**Functions:**
- `parse_file/1`
- `parse_tree/1`

**Rust NIF module:** `Elixir.parsing_engine` (Erlang atom)

**Note:** Largest NIF (11MB) - contains tree-sitter parsers for 10+ languages

---

### 5. prompt_intelligence ✅
**Status:** Working
**Binary:** `libprompt_intelligence.so` (691KB)
**Elixir:** `Singularity.PromptEngine.Native`
**Functions:**
- Prompt optimization
- DSPy integration
- Caching

**Rust NIF module:** `Elixir.Singularity.PromptEngine.Native`

---

### 6. quality_engine ⚠️
**Status:** NIF exists, needs .so build
**Binary:** Missing (need to build)
**Elixir:** `Singularity.QualityEngine` (currently pure Elixir stub)
**Functions:**
- `analyze_code_quality/2`
- `run_quality_gates/1`
- `calculate_quality_metrics/2`
- `detect_ai_patterns/2`
- `get_quality_config/0`
- `update_quality_config/1`
- `get_supported_languages/0`
- `get_quality_rules/1`
- `add_quality_rule/1`
- `remove_quality_rule/1`
- `get_version/0`
- `health_check/0`

**Rust NIF module:** `Elixir.Singularity.QualityEngine`

**TODO:** Replace Elixir stub with Rustler binding and build .so

---

## Symlink Structure

All NIFs are accessed via symlinks from `singularity_app/native/`:

```bash
singularity_app/native/
├── architecture_engine -> ../../rust-central/architecture_engine
├── code_engine -> ../../rust-central/code_engine
├── embedding_engine -> ../../rust-central/embedding_engine
├── parser-engine -> ../../rust-central/parser_engine  # Note: dash in native/, underscore in rust-central
├── prompt_intelligence -> ../../rust-central/prompt_intelligence
├── quality_engine -> ../../rust-central/quality_engine
└── ... (other symlinks)
```

**All directories in `singularity_app/native/` are symlinks - no real code!**

## Cargo Workspace

Root `Cargo.toml` workspace members point to `rust-central/`:

```toml
[workspace]
members = [
    "rust-central/parser_engine/dependency",
    "rust-central/parser_engine/engine",
    "rust-central/parser_engine/language_framework",
    "rust-central/parser_engine/languages/*",
    "rust-central/architecture_engine",
    "rust-central/code_engine",
    "rust-central/embedding_engine",
    "rust-central/prompt_intelligence",
]
```

## Moon Workspace

`.moon/workspace.yml` tracks all rust-central projects:

```yaml
projects:
  - 'rust-central'
  - 'rust-central/architecture_engine'
  - 'rust-central/code_engine'
  - 'rust-central/embedding_engine'
  - 'rust-central/parser_engine'
  - 'rust-central/prompt_intelligence'
  - 'rust-central/quality_engine'
  - 'rust-central/analysis_suite'
  # ... etc
```

## Build Commands

### Build ALL NIFs
```bash
# From root
cargo build --release --lib

# Build specific NIF
cd rust-central/quality_engine
cargo build --release --lib
```

### Copy .so to priv/native/
```bash
# Rustler automatically copies during compilation when `skip_compilation?: false`
# OR manually:
cp rust-central/code_engine/target/release/libcode_engine.so \
   singularity_app/priv/native/
```

### Compile Elixir with NIFs
```bash
cd singularity_app
mix compile  # Uses prebuilt .so files with skip_compilation?: true
```

## Adding a New NIF

1. **Create Rust crate in `rust-central/my_nif/`**
   ```bash
   cd rust-central
   cargo new --lib my_nif
   ```

2. **Add rustler dependency**
   ```toml
   [dependencies]
   rustler = "0.34"

   [lib]
   crate-type = ["cdylib"]
   ```

3. **Create NIF functions**
   ```rust
   #[rustler::nif]
   fn my_function(arg: String) -> String {
       format!("Hello {}", arg)
   }

   rustler::init!("Elixir.MyModule", [my_function]);
   ```

4. **Add to root Cargo workspace**
   ```toml
   members = ["rust-central/my_nif"]
   ```

5. **Create symlink from native/**
   ```bash
   cd singularity_app/native
   ln -s ../../rust-central/my_nif my_nif
   ```

6. **Add to mix.exs**
   ```elixir
   {:my_nif, path: "native/my_nif", runtime: false, app: false, compile: false}
   ```

7. **Create Elixir module**
   ```elixir
   defmodule MyModule do
     use Rustler,
       otp_app: :singularity,
       crate: :my_nif,
       skip_compilation?: true  # Use prebuilt .so

     def my_function(_arg), do: :erlang.nif_error(:nif_not_loaded)
   end
   ```

8. **Build and copy .so**
   ```bash
   cd rust-central/my_nif
   cargo build --release
   cp target/release/libmy_nif.so ../../singularity_app/priv/native/
   ```

## Benefits

1. ✅ **Single source of truth** - All Rust code in one place
2. ✅ **No duplication** - Symlinks point to canonical location
3. ✅ **Moon tracking** - All projects visible to monorepo tool
4. ✅ **Shared dependencies** - Cargo workspace shares deps
5. ✅ **Fast compilation** - Skip NIF rebuilds with prebuilt .so files
6. ✅ **Easy discovery** - All Rust code under `rust-central/`

## TODOs

- [ ] Build `code_engine` .so file
- [ ] Replace `quality_engine.ex` with Rustler NIF binding
- [ ] Build `quality_engine` .so file
- [ ] Remove unused NIF stubs (generator_engine, etc.)
- [ ] Consolidate duplicate `dependency-parser` / `dependency_parser`
- [ ] Document each standalone tool's purpose
