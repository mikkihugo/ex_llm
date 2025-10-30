# Singularity Smart Package Context - Backend

Unified backend for all 4 distribution channels (MCP, VS Code, CLI, API).

## Architecture

```
┌─────────────────────────────────────┐
│   SmartPackageContext               │
│   (5 core functions)                │
├─────────────────────────────────────┤
│   Integrations Layer                │
│   - package_intelligence (Rust NIF) │
│   - CentralCloud patterns (Elixir)  │
│   - Embeddings service              │
├─────────────────────────────────────┤
│   Cache Layer (LRU)                 │
├─────────────────────────────────────┤
│   Underlying Systems                │
│   - npm/cargo/hex/pypi registries   │
│   - GitHub API                      │
│   - PostgreSQL (embeddings)         │
└─────────────────────────────────────┘
```

## The 5 Core Functions

### 1. `get_package_info(name, ecosystem)`
Get complete package metadata including quality score.

```ignore
let pkg = ctx.get_package_info("react", Ecosystem::Npm).await?;
println!("{}: {} (quality: {})", pkg.name, pkg.version, pkg.quality_score);
```

### 2. `get_package_examples(name, ecosystem, limit)`
Get code examples from official documentation and GitHub.

```ignore
let examples = ctx.get_package_examples("react", Ecosystem::Npm, 5).await?;
for ex in examples {
    println!("{}\n{}\n", ex.title, ex.code);
}
```

### 3. `get_package_patterns(name)`
Get community consensus patterns for a package.

```ignore
let patterns = ctx.get_package_patterns("react").await?;
for pattern in patterns.iter().filter(|p| p.confidence > 0.9) {
    println!("Highly recommended: {}", pattern.name);
}
```

### 4. `search_patterns(query, limit)`
Semantic search across all patterns using embeddings.

```ignore
let results = ctx.search_patterns("async error handling in javascript", 10).await?;
for m in results {
    println!("{} (relevance: {})", m.pattern.name, m.relevance);
}
```

### 5. `analyze_file(content, file_type)`
Analyze code and suggest improvements based on patterns.

```ignore
let suggestions = ctx.analyze_file(code_content, FileType::JavaScript).await?;
for s in suggestions {
    println!("{}: {}", s.severity, s.title);
}
```

## Type System

### Core Types

- **`Ecosystem`** - npm, cargo, hex, pypi, go, maven, nuget
- **`PackageInfo`** - Complete package metadata with quality score
- **`CodeExample`** - Code snippet with description and source
- **`PatternConsensus`** - Consensus pattern with confidence score (0.0-1.0)
- **`PatternMatch`** - Search result with relevance score
- **`FileType`** - JavaScript, Python, Rust, Elixir, etc.
- **`Suggestion`** - Code improvement suggestion with severity level

### Error Handling

All functions return `Result<T>` which is `std::result::Result<T, Error>`.

Error types:
- `PackageNotFound` - Package doesn't exist
- `InvalidEcosystem` - Unknown ecosystem
- `EmbeddingFailed` - Embedding generation error
- `AnalysisFailed` - Code analysis error
- `RateLimited` - Rate limit exceeded
- `Timeout` - Operation timed out

## Caching

Uses LRU cache with configurable TTL (default 1 hour).

```rust
// Cache is automatic - no API needed
// Expired entries are automatically evicted
// Clear cache with ctx.cache.clear()
```

## Integration Points

### Package Intelligence (Rust NIF)
Called via the `package_intelligence` crate to fetch metadata from registries.

### CentralCloud (Elixir)
Called via HTTP or direct IPC to get consensus patterns.

```text
Singularity.EmbeddingGenerator ← embeddings
CentralCloud.Evolution.Patterns ← patterns
```

### Embeddings Service (Nx)
Called to generate and search semantic embeddings.

## Building

```bash
# Build library
cargo build --release

# Run tests
cargo test

# Build binary
cargo build --bin smart-package-context-server --release

# Check code
cargo clippy
cargo fmt -- --check
```

## Testing

Comprehensive test suite:

```bash
# Unit tests (fast)
cargo test --lib

# Integration tests
cargo test --test '*'

# All tests with output
cargo test -- --nocapture
```

## Development Notes

### Why 5 Functions?

These 5 functions are the minimal set needed to answer:
1. **What's this package?** - `get_package_info()`
2. **How do I use it?** - `get_package_examples()`
3. **How do the best developers use it?** - `get_package_patterns()`
4. **What patterns work for my problem?** - `search_patterns()`
5. **Is my code following best practices?** - `analyze_file()`

### Design Principles

- **One backend, many frontends** - MCP, VS Code, CLI, and API all wrap this same backend
- **Type-safe** - Strong Rust types prevent runtime errors
- **Async-first** - All I/O is async with Tokio
- **Error-safe** - Comprehensive error types guide users
- **Cached** - Reduces load on underlying services
- **Documented** - Every public function has examples

### Integration Strategy

Instead of directly calling external services, the backend has an `Integrations` layer that acts as a facade. This allows:

- Easy mocking for tests
- Easy swapping of implementations
- Clear documentation of external dependencies
- Centralized error handling

## Next Steps

### Week 1-2 (Backend Phase)
- ✅ Design backend interface (done)
- ⏳ Implement integration points
- ⏳ Write comprehensive tests (30+ tests)
- ⏳ Document API and error handling

### Week 3 (MCP Phase)
- Use this backend in MCP server wrapper
- Register 5 functions as MCP tools

### Week 4-5 (VS Code Phase)
- Use this backend in VS Code extension
- Create UI components for each function

### Week 6 (CLI Phase)
- Use this backend in CLI tool
- Create command structure for each function

### Week 7 (API Phase)
- Use this backend in HTTP API
- Create REST endpoints for each function

## File Structure

```
backend/
├── Cargo.toml                 ← Dependencies
├── README.md                  ← This file
├── src/
│   ├── lib.rs                ← Library entry point
│   ├── api/
│   │   └── mod.rs            ← SmartPackageContext (5 core functions)
│   ├── integrations.rs       ← Integration facade
│   ├── types.rs              ← Core data types
│   ├── error.rs              ← Error types
│   ├── cache.rs              ← LRU caching layer
│   ├── bin/
│   │   └── main.rs           ← Server binary
│   └── tests/
│       └── integration_test.rs
└── tests/
    └── api_test.rs
```

## API Stability

Current status: **Alpha**

- Type signatures may change
- Return types will be expanded
- Error handling will be refined
- Integration points may be refactored

## Contributing

When adding new functions:
1. Add type definitions to `types.rs`
2. Add function signature to `SmartPackageContext`
3. Implement in `integrations.rs`
4. Add unit tests to `integrations.rs`
5. Add integration tests to `tests/`
6. Update documentation

## License

Part of Singularity Products ecosystem.
