# Package Collectors Architecture

## Overview

Collectors download and analyze packages from registries (crates.io, hex.pm, npm, pypi) to build comprehensive FactData - **even without GitHub access**.

## Data Source Hierarchy (Best → Fallback)

```
1. GitHub          [100 points] - Official repo with examples/tests
2. Package Source  [ 80 points] - Downloaded package analyzed locally ⭐ NEW
3. Registry Meta   [ 50 points] - README + API metadata
4. LLM Generated   [ 20 points] - AI-generated examples (last resort)
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  VersionedFactStorage (redb + JSON)                 │
│  fact:cargo:tokio:1.35.0                            │
└─────────────────────────────────────────────────────┘
                    ▲
                    │ stores FactData
                    │
┌─────────────────────────────────────────────────────┐
│  PackageCollector Trait                             │
│  - collect(package, version) → FactData             │
│  - exists(package, version) → bool                  │
│  - latest_version(package) → String                 │
│  - available_versions(package) → Vec<String>        │
└─────────────────────────────────────────────────────┘
                    ▲
        ┌───────────┼───────────────────┐
        │           │                   │
┌───────────┐  ┌────────┐         ┌────────┐
│ Cargo     │  │  NPM   │         │  Hex   │
│ Collector │  │Collector│         │ (future)
└───────────┘  └────────┘         └────────┘
```

## Example: Cargo Collector Flow

### 1. Download from crates.io
```rust
// Downloads tokio-1.35.0.crate (gzipped tar)
let crate_path = download_crate("tokio", "1.35.0").await?;
// → ~/.cache/sparc-engine/crates/tokio-1.35.0/
```

### 2. Analyze Source Code
```rust
// Parses all .rs files
let code_index = analyze_crate_source(&crate_path).await?;

// Extracts:
// - Public functions: pub fn spawn(), pub fn block_on()
// - Public types: pub struct Runtime, pub enum JoinError
// - Public traits: pub trait AsyncRead, pub trait AsyncWrite
// - Naming conventions: snake_case for functions, PascalCase for types
```

### 3. Extract Examples
```rust
// Reads examples/ directory
let snippets = extract_examples(&crate_path).await?;

// From: examples/hello_world.rs
// Creates: FactSnippet with full example code
```

### 4. Build FactData
```rust
FactData {
    tool: "tokio",
    version: "1.35.0",
    ecosystem: "cargo",
    source: "cargo:package",  // ← Indicates source is package analysis
    github_sources: vec![],   // ← Empty - no GitHub needed!

    code_index: Some(CodeIndex {
        files: vec![
            IndexedFile {
                path: "src/lib.rs",
                language: "rust",
                exports: vec!["spawn", "block_on", "Runtime"],
                functions: vec!["spawn", "block_on"],
                classes: vec!["Runtime", "JoinError"],
                line_count: 450,
            }
        ],
        exports: vec![
            Export {
                name: "spawn",
                from_file: "src/lib.rs",
                export_type: "function",
            }
        ],
        naming_conventions: NamingConventions {
            function_naming: "snake_case",
            class_naming: "PascalCase",
            file_naming: "snake_case",
        },
    }),

    snippets: vec![
        FactSnippet {
            title: "Example: hello_world",
            code: "use tokio::runtime::Runtime;\n...",
            language: "rust",
            description: "From examples/hello_world.rs",
            file_path: "examples/hello_world.rs",
            line_number: 1,
        }
    ],
}
```

### 5. Store with Versioning
```rust
storage.store_fact(&key, &fact_data).await?;
// Stored: fact:cargo:tokio:1.35.0
// Exported: ~/.cache/sparc-engine/global/knowledge/cargo/tokio/1.35.0.json
```

## What Gets Extracted

### From Source Files
- ✅ **Public API**: All `pub fn`, `pub struct`, `pub enum`, `pub trait`
- ✅ **Function Signatures**: Parameters, return types, generics
- ✅ **Type Definitions**: Struct fields, enum variants
- ✅ **Documentation**: Doc comments (`///`, `//!`)
- ✅ **Naming Patterns**: snake_case, PascalCase, SCREAMING_SNAKE_CASE
- ✅ **File Structure**: Module organization, exports

### From Examples/
- ✅ **Real Usage**: Working code examples from examples/ directory
- ✅ **Integration Patterns**: How to use multiple features together
- ✅ **Best Practices**: Idiomatic usage from official examples

### From tests/ (Future)
- 🔄 **Usage Patterns**: Common patterns from test suite
- 🔄 **Edge Cases**: How library handles errors, special cases
- 🔄 **Integration Tests**: Multi-component usage

## Extending to Other Ecosystems

### Hex.pm (Elixir/Erlang)
```rust
pub struct HexCollector {
    // Downloads from: https://hex.pm/api/packages/{package}
    // Analyzes: .ex, .exs files
    // Extracts: defmodule, defp, def, defstruct, @spec
}
```

### NPM (JavaScript/TypeScript) ✅ IMPLEMENTED
```rust
pub struct NpmCollector {
    // Downloads from: https://registry.npmjs.org/{package}/-/{package}-{version}.tgz
    // Analyzes: .js, .ts, .tsx, .jsx, .mjs, .mts files
    // Extracts: export, function, class, interface, type, const
    // Entry points: package.json main, module, types, exports fields
    // Examples: Extracts from examples/, test/, __tests__/ directories
}

// Usage Example
use fact_tools::collectors::npm::NpmCollector;

let collector = NpmCollector::default_cache()?;
let fact_data = collector.collect("react", "18.2.0").await?;
// Downloads, analyzes, and extracts React package API
```

### PyPI (Python)
```rust
pub struct PyPiCollector {
    // Downloads from: https://pypi.org/pypi/{package}/{version}/json
    // Analyzes: .py files
    // Extracts: def, class, @decorator, type hints
}
```

## Benefits

✅ **Works for Private Packages** - No GitHub access needed
✅ **Analyzes Published Code** - What users actually get
✅ **Extracts Real APIs** - Not just examples from docs
✅ **Finds Implementation Patterns** - How it's built internally
✅ **Builds Accurate Code Index** - Complete function/type catalog
✅ **On-Demand Collection** - Only collect what's requested
✅ **Version-Aware** - Each version analyzed separately

## Usage Example

```rust
use fact_tools::collectors::cargo::CargoCollector;
use fact_tools::storage::versioned_storage::VersionedFactStorage;

// Initialize
let collector = CargoCollector::default_cache()?;
let storage = VersionedFactStorage::new_global().await?;

// Collect package data (downloads + analyzes)
let fact_data = collector.collect("tokio", "1.35.0").await?;

// Store for future use
let key = FactKey::new("tokio".to_string(), "1.35.0".to_string(), "cargo".to_string());
storage.store_fact(&key, &fact_data).await?;

// Later: Query with semantic versioning fallback
let result = storage.get_with_fallback("cargo", "tokio", "1.35.2").await?;
// Returns: tokio 1.35.0 (closest match)
```

## Performance

| Operation | Time | Cache |
|-----------|------|-------|
| Download 5MB crate | ~2s | First time |
| Extract source | ~100ms | - |
| Analyze 100 files | ~500ms | - |
| **Total** | **~2.5s** | **First time** |
| Query from redb | **~0.1ms** | **Subsequent** |

## Future Enhancements

- 🔄 Use `syn` crate for accurate Rust AST parsing
- 🔄 Use `tree-sitter` for multi-language parsing
- 🔄 Extract dependencies from Cargo.toml/package.json
- 🔄 Analyze test coverage and common patterns
- 🔄 Generate usage examples with LLM from API signatures
- 🔄 Track API evolution between versions (breaking changes)
