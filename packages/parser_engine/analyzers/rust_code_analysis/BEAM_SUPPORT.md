# BEAM Language Support in Singularity Code Analysis

## Overview

Full support for BEAM languages (Elixir, Erlang, Gleam) has been implemented in singularity-code-analysis with comprehensive complexity metrics.

## Implementation Date

2025-01-14

## Supported Languages

### 1. Elixir (tree-sitter-elixir 0.3.4)

**Features:**
- Full AST parsing via tree-sitter
- Comment detection
- Function detection (def, defp)
- Anonymous function (closure) detection
- Function call detection
- String literal detection (String, Charlist, QuotedContent)
- Primitive type detection (Atom, Integer, Float, Boolean, Nil)
- All complexity metrics: Cyclomatic, Halstead, MI, ABC, Cognitive, etc.

**Node Types:** 66 distinct node types including Call, DoBlock, AnonymousFunction, StabClause, Map, Tuple, List, etc.

### 2. Erlang (tree-sitter-erlang 0.15.0)

**Features:**
- Full AST parsing via tree-sitter
- Comment detection
- Function declaration detection (FunDecl, FunctionClause)
- Anonymous function detection (fun ... end)
- Function call detection
- Character literal detection (Erlang strings are lists)
- Primitive type detection (Atom, Integer, Float)
- Guard clause support
- Pattern matching support (case, receive, try/catch)
- All complexity metrics

**Node Types:** 101 distinct node types including FunDecl, CaseExpr, ReceiveExpr, TryExpr, Guard, MapExpr, Record, etc.

### 3. Gleam (tree-sitter-gleam 1.0.0)

**Features:**
- Full AST parsing via tree-sitter
- Multiple comment types (ModuleComment, StatementComment, Comment)
- Function detection (pub fn, fn)
- Anonymous function detection
- Function call detection
- String literal detection
- Primitive type detection (Integer, Float)
- Type system support (TypeDefinition, TypeAlias)
- Pattern matching support (case expressions)
- All complexity metrics

**Node Types:** 129 distinct node types including Function, Case, Let, Use, Assert, Record, Tuple, List, BitString, etc.

## Metrics Supported

All BEAM languages support the full suite of code metrics:

1. **ABC** - Assignment, Branch, Condition complexity
2. **Cognitive** - Cognitive complexity metric
3. **Cyclomatic** - Cyclomatic complexity (McCabe)
4. **Exit** - Exit point counting
5. **Halstead** - Halstead complexity measures
6. **LOC** - Lines of Code (SLOC, CLOC, PLOC)
7. **MI** - Maintainability Index
8. **NArgs** - Number of Arguments
9. **Nom** - Number of Methods
10. **Npa** - Number of Public Attributes
11. **Npm** - Number of Public Methods
12. **WMC** - Weighted Methods per Class

## File Extensions

- **Elixir**: `.ex`, `.exs`
- **Erlang**: `.erl`, `.hrl`
- **Gleam**: `.gleam`

## Architecture

### Language Enums

Each language has a complete enum with node types extracted from the actual tree-sitter grammar:

- `src/languages/language_elixir.rs` - 66 node types
- `src/languages/language_erlang.rs` - 101 node types
- `src/languages/language_gleam.rs` - 129 node types

### Trait Implementations

Each language implements:

1. **Checker** - Code structure analysis (comments, functions, closures, calls, strings, primitives)
2. **Alterator** - AST node transformation for network serialization
3. **Getter** - Name and identifier extraction
4. **All Metric Traits** - ABC, Cognitive, Cyclomatic, Exit, Halstead, LOC, MI, NArgs, Nom, Npa, Npm, WMC

### Registration

Languages are registered in `src/langs.rs`:

```rust
(Elixir, "The `Elixir` language", "elixir", ElixirCode, ElixirParser, tree_sitter_elixir, [ex, exs], ["elixir"]),
(Erlang, "The `Erlang` language", "erlang", ErlangCode, ErlangParser, tree_sitter_erlang, [erl, hrl], ["erlang"]),
(Gleam, "The `Gleam` language", "gleam", GleamCode, GleamParser, tree_sitter_gleam, [gleam], ["gleam"])
```

## Examples

Test examples provided in `examples/` directory:

- `inspect_elixir.rs` - Demonstrates Elixir AST parsing
- `inspect_erlang.rs` - Demonstrates Erlang AST parsing
- `inspect_gleam.rs` - Demonstrates Gleam AST parsing

Run with:
```bash
cargo run --example inspect_elixir
cargo run --example inspect_erlang
cargo run --example inspect_gleam
```

## Testing

### Sample Files Created

- `/tmp/test_elixir.ex` - Elixir test code (defmodule, def, defp, if, case)
- `/tmp/test_erlang.erl` - Erlang test code (factorial, guards, case)
- `/tmp/test_gleam.gleam` - Gleam test code (pub fn, case, pattern matching)

### Build Status

✅ **All builds pass cleanly**
- Debug build: ✅ Success
- Release build: ✅ Success
- No errors, only minor unused variable warnings

## Dependencies

```toml
tree-sitter-elixir = "0.3.4"   # Latest stable
tree-sitter-erlang = "0.15.0"   # Latest stable
tree-sitter-gleam = "1.0.0"     # Latest stable
```

## Key Implementation Details

### Elixir

- Functions detected via `Call` nodes with `def`/`defp` identifiers
- Closures are `AnonymousFunction` nodes
- String types include `String`, `Charlist`, `QuotedContent`
- Primitives: `Atom`, `Integer`, `Float`, `Boolean`, `Nil`

### Erlang

- Functions are `FunDecl` and `FunctionClause` nodes
- Closures are `AnonymousFun` nodes
- Strings are character lists (no dedicated string type)
- Primitives: `Atom`, `Integer`, `Float`
- Rich support for OTP patterns: guards, pattern matching, receive blocks

### Gleam

- Functions are `Function` nodes with optional `VisibilityModifier` (pub)
- Closures are `AnonymousFunction` nodes
- Strings are `String` with `QuotedContent`
- Primitives: `Integer`, `Float`
- Strong type system support with `TypeDefinition` and `TypeAlias`

## Future Enhancements

Potential improvements:

1. **Enhanced Function Detection** - More precise def/defp detection in Elixir
2. **Module Boundary Detection** - Track defmodule boundaries for better metrics
3. **OTP Pattern Recognition** - Detect GenServer, Supervisor patterns in Erlang/Elixir
4. **Macro Expansion** - Handle Elixir macros for more accurate metrics
5. **Type-aware Metrics** - Leverage Gleam's type system for additional insights

## Comparison with Other Languages

BEAM languages now have the same level of support as:
- Rust
- Python
- JavaScript/TypeScript/TSX
- C/C++
- Java

Making singularity-code-analysis one of the most comprehensive BEAM-aware complexity analyzers available.

## Credits

Implementation based on:
- Singularity's rust-code-analysis framework
- tree-sitter-elixir by @elixir-lang
- tree-sitter-erlang by @WhatsApp
- tree-sitter-gleam by @gleam-lang

## License

MIT OR Apache-2.0 (same as singularity-code-analysis)
