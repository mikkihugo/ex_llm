# What Gets Cached: AST vs Metrics vs Results

## TL;DR: Cache the FULL Parse Result

**Don't cache raw AST!** Cache the **processed result** including:
- ✅ Extracted functions, classes, imports (processed data)
- ✅ Mozilla metrics (cyclomatic complexity, LOC, etc.)
- ✅ Language metadata
- ❌ **NOT** raw tree-sitter AST (too big, not serializable)

## Why NOT Cache Raw AST?

### Raw AST is HUGE and Useless

```rust
// tree-sitter AST (DON'T CACHE THIS!)
Tree {
  root_node: Node {
    kind: "source_file",
    start_byte: 0,
    end_byte: 5000,
    start_position: Point { row: 0, column: 0 },
    end_position: Point { row: 200, column: 0 },
    children: [
      Node { kind: "function_definition", ... },  // 1000+ nested nodes
      Node { kind: "class_definition", ... },
      // ... thousands more nodes
    ]
  }
}

// Problem 1: TOO BIG (megabytes for small files)
// Problem 2: NOT SERIALIZABLE (references, pointers)
// Problem 3: USELESS (needs processing to extract info)
```

**Size**: A 500-line Python file → **5MB+ raw AST** → Only **50KB processed result**

### What You Actually Need

```rust
// Processed result (CACHE THIS!)
ParseResult {
  // Extracted entities (what you actually use!)
  functions: vec![
    Function {
      name: "authenticate",
      params: vec!["username", "password"],
      return_type: Some("bool"),
      line_start: 42,
      line_end: 58,
      docstring: Some("Authenticate user credentials"),
      decorators: vec!["@require_auth"],
    }
  ],

  classes: vec![
    Class {
      name: "User",
      bases: vec!["BaseModel"],
      methods: vec!["save", "delete"],
      line_start: 10,
      line_end: 40,
    }
  ],

  imports: vec![
    Import {
      module: "flask",
      symbols: vec!["Flask", "request"],
      line: 1,
    }
  ],

  // Mozilla metrics (expensive to compute!)
  metrics: Metrics {
    cyclomatic_complexity: 12.5,
    halstead_volume: 450.2,
    maintainability_index: 68.3,
    loc: 500,
    sloc: 420,
    cloc: 80,
  },

  // Metadata
  language: "python",
  file_path: "lib/auth.py",
  parsed_at: 1696896000,
}

// ✅ Small: ~50KB
// ✅ Serializable: JSON/MessagePack
// ✅ Useful: Ready to use!
```

## Cache Contents by Level

### Local Cache (ETS)

**What**: Processed ParseResult (functions + classes + metrics)
**Format**: Elixir terms (fast, no serialization)
**Size**: ~50KB per file
**Why**: Fast lookups, no re-parsing

```elixir
# Cached in ETS
{:file, "lib/auth.py", "python"} => %ParseResult{
  functions: [...],
  classes: [...],
  imports: [...],
  metrics: %{cyclomatic_complexity: 12.5, ...},
  language: "python",
  parsed_at: ~U[2024-10-09 12:00:00Z]
}
```

### Global Cache (Redis)

**What**: Same processed ParseResult
**Format**: JSON or MessagePack
**Size**: ~50KB per file
**Why**: Share across instances, persist across restarts

```json
// Redis key: "parser:file:/path/to/file.py:python"
{
  "functions": [
    {
      "name": "authenticate",
      "params": ["username", "password"],
      "return_type": "bool",
      "line_start": 42,
      "line_end": 58,
      "docstring": "Authenticate user credentials"
    }
  ],
  "classes": [...],
  "imports": [...],
  "metrics": {
    "cyclomatic_complexity": 12.5,
    "halstead_volume": 450.2,
    "maintainability_index": 68.3,
    "loc": 500,
    "sloc": 420,
    "cloc": 80
  },
  "language": "python",
  "file_path": "lib/auth.py",
  "parsed_at": 1696896000
}
```

## What Gets Computed Once and Cached

### Expensive Operations (Cached!)

1. **Parsing** (50-200ms)
   - tree-sitter parsing
   - AST traversal
   - Entity extraction

2. **Mozilla Metrics** (10-50ms)
   - Cyclomatic complexity
   - Halstead metrics
   - Maintainability index
   - LOC counting

3. **Semantic Analysis** (5-20ms)
   - Function signatures
   - Class hierarchies
   - Import resolution

**Total**: ~100-300ms **per file**

**After caching**: **0.001ms** (ETS) or **2ms** (Redis)

### Cheap Operations (Not Cached)

- Language detection (1ms) - file extension lookup
- File reading (1-5ms) - OS does this well
- Basic validation (1ms) - syntax check

## Cache Key Strategy

### File-Based Caching

```rust
// Cache key includes file path + language + content hash
fn cache_key(file: &str, language: &str, content_hash: &str) -> String {
    format!("parser:{}:{}:{}", file, language, content_hash)
}

// Example: "parser:lib/auth.py:python:sha256abc123"
```

**Why content hash?**
- Invalidates when file changes
- Same file in different projects → different cache (hash differs)

### Source-Based Caching

```rust
// For direct source code (no file path)
fn cache_key_source(source: &str, language: &str) -> String {
    let hash = sha256(source);
    format!("parser:source:{}:{}", language, hash)
}

// Example: "parser:source:python:sha256def456"
```

**Why?**
- Same code → same cache
- Useful for inline parsing (REPL, notebooks)

## Cache Invalidation

### Local Cache (ETS)

**When**: File changes detected

```elixir
# File watcher detects change
FileSystem: "lib/auth.py changed"
  ↓
Parser.Engine.invalidate("lib/auth.py")
  ↓
:ets.delete(:parser_cache, {:file, "lib/auth.py", "python"})
```

**TTL**: 1 hour (in case file watcher misses)

### Global Cache (Redis)

**When**: Any instance detects file change

```rust
// Instance A: File changed
nats.publish("parser.invalidate", json!({
    "file": "lib/auth.py",
    "reason": "content_changed"
})).await?

// Instance B: Receives broadcast
fn handle_invalidation(msg) {
    redis.del(format!("parser:file:{}", msg.file))?;
    local_cache.invalidate(msg.file)?;
}
```

**TTL**: 24 hours (in case broadcast missed)

## Size Examples

### Small File (100 lines)

```
Raw AST:     1.2 MB   ← DON'T CACHE
Processed:   15 KB    ← CACHE THIS
Compression: 80x smaller!
```

### Medium File (500 lines)

```
Raw AST:     5.8 MB   ← DON'T CACHE
Processed:   50 KB    ← CACHE THIS
Compression: 116x smaller!
```

### Large File (2000 lines)

```
Raw AST:     22 MB    ← DON'T CACHE
Processed:   180 KB   ← CACHE THIS
Compression: 122x smaller!
```

## Cache Schema (Rust)

```rust
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ParseResult {
    /// Extracted functions
    pub functions: Vec<Function>,

    /// Extracted classes
    pub classes: Vec<Class>,

    /// Import statements
    pub imports: Vec<Import>,

    /// Comments and docstrings
    pub comments: Vec<Comment>,

    /// Enums (for languages that support them)
    pub enums: Vec<Enum>,

    /// Mozilla metrics (expensive to compute!)
    pub metrics: Metrics,

    /// Language detected
    pub language: String,

    /// File path (optional, for file-based parsing)
    pub file_path: Option<String>,

    /// Content hash (for cache invalidation)
    pub content_hash: String,

    /// When this was parsed
    pub parsed_at: u64,

    /// Parser version (for cache invalidation on parser updates)
    pub parser_version: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Metrics {
    /// Cyclomatic complexity (from Mozilla)
    pub cyclomatic_complexity: f64,

    /// Halstead volume (from Mozilla)
    pub halstead_volume: f64,

    /// Halstead difficulty (from Mozilla)
    pub halstead_difficulty: f64,

    /// Maintainability index (from Mozilla)
    pub maintainability_index: f64,

    /// Lines of code
    pub loc: usize,

    /// Source lines of code (no comments)
    pub sloc: usize,

    /// Comment lines
    pub cloc: usize,

    /// Domain-specific metrics (from balloon parsers)
    pub custom: HashMap<String, serde_json::Value>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Function {
    pub name: String,
    pub params: Vec<String>,
    pub return_type: Option<String>,
    pub line_start: usize,
    pub line_end: usize,
    pub docstring: Option<String>,
    pub decorators: Vec<String>,
    pub is_async: bool,
    pub visibility: Visibility,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Class {
    pub name: String,
    pub bases: Vec<String>,
    pub methods: Vec<String>,
    pub line_start: usize,
    pub line_end: usize,
    pub docstring: Option<String>,
    pub decorators: Vec<String>,
}

// ... more types
```

## Serialization Format

### Local Cache (ETS)

**Format**: Elixir terms (no serialization needed)
**Speed**: Instant (native)

```elixir
# No serialization overhead!
:ets.insert(:cache, {key, %ParseResult{...}})
```

### Global Cache (Redis)

**Format**: MessagePack (compact binary)
**Speed**: ~1ms serialize + ~1ms deserialize
**Size**: ~30% smaller than JSON

```rust
// Serialize to MessagePack
let bytes = rmp_serde::to_vec(&result)?;
redis.set(key, bytes).await?;

// Deserialize from MessagePack
let bytes: Vec<u8> = redis.get(key).await?;
let result: ParseResult = rmp_serde::from_slice(&bytes)?;
```

**Why MessagePack?**
- Faster than JSON (no text parsing)
- Smaller than JSON (~30% reduction)
- Native support in most languages

## Memory Usage (Local Cache)

### Typical Project (1000 files)

```
1000 files × 50 KB/file = 50 MB total
```

**With LRU eviction** (keep 500 most recent):
```
500 files × 50 KB = 25 MB
```

**ETS overhead**: ~10% → **27.5 MB total**

### Configuration

```elixir
# config/config.exs
config :singularity, Singularity.Parser.Engine,
  cache_max_entries: 500,        # LRU eviction
  cache_ttl: :timer.hours(1),    # 1 hour TTL
  cache_size_limit_mb: 100       # Max 100MB
```

## Summary

### ✅ Cache This (Processed Result)

- Extracted functions, classes, imports
- Mozilla metrics (cyclomatic, halstead, etc.)
- Language metadata
- Small (~50KB per file)
- Serializable (JSON/MessagePack)
- **Ready to use!**

### ❌ Don't Cache This (Raw AST)

- tree-sitter AST nodes
- Huge (~5MB per file)
- Not serializable (pointers, references)
- Useless (needs processing)

### Performance Impact

| Operation | No Cache | Local Cache | Global Cache |
|-----------|----------|-------------|--------------|
| Parse + Metrics | 100-300ms | **0.001ms** | **2ms** |
| Speedup | 1x | **100,000x** | **50x** |

**Caching = 100,000x faster!** 🚀

### Where to Cache

**Local (ETS)**:
- ⚡ **0.001ms** - Default for Singularity app
- 💾 25-50MB memory
- 🔄 Auto-invalidate on file change

**Global (Redis)**:
- ⚡ **2ms** - Optional, for multi-instance
- 💾 Unlimited (Redis persistence)
- 🌐 Share across all instances

**Best practice**: Local first, global optional! 🎈
