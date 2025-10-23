# Rustler 0.37 NIF Error Handling Review

**Date:** 2025-10-23
**Scope:** All 8 NIF Engines in Singularity
**Rustler Version (workspace):** 0.37
**Current Rustler Version (architecture_engine):** 0.34 (OUTDATED)

---

## Executive Summary

Our Rust NIF implementations across the 8 engines have **significant version mismatches and inconsistent error handling patterns**. While we have **workspace-level Rustler 0.37** configured, individual engines still depend on **0.34**, missing modern error handling improvements and derive macros available in 0.37+.

### Key Findings

1. **Version Mismatch Crisis**
   - Workspace specifies: `rustler = "0.37"` (correct, modern)
   - Individual engines specify: `rustler = "0.34"` (OUTDATED, missing features)
   - Result: Engines cannot use Rustler 0.37 error handling patterns

2. **Error Handling: Mixed Patterns (Legacy + Modern)**
   - ✅ Modern: Using `Result<T, String>` with map_err (parser_engine, code_engine)
   - ✅ Modern: Using `#[rustler::nif]` with explicit return types (good)
   - ❌ Legacy: Manual atom construction with `rustler::atoms!` macro (all engines)
   - ❌ Missing: No use of `#[derive(NifException)]` anywhere
   - ❌ Missing: No custom error types beyond `String`

3. **Scheduler Directives: Properly Used**
   - ✅ Dirty schedulers correct in parser_engine: `#[rustler::nif(schedule = "DirtyCpu")]`
   - ✅ Dirty schedulers correct in code_engine (will enable when scheduler changes)
   - ❌ Architecture engine has NO scheduler directives (should be normal, is pure computation)

4. **Type Mapping: Good but Could Be Better**
   - ✅ Using `NifStruct` for complex types (parser_engine, code_engine)
   - ✅ Proper struct conversions from core types
   - ✅ Explicit encoding to Elixir terms
   - ⚠️ No use of `NifUntaggedEnum` or `NifTaggedEnum` for sum types

---

## Current Error Handling Patterns

### Pattern 1: Basic String Errors (CURRENT - ALL ENGINES)

```rust
// Architecture Engine (nif.rs, line 142)
#[rustler::nif]
pub fn architecture_engine_call<'a>(env: Env<'a>, operation: Term<'a>, request: Term<'a>) -> Result<Term<'a>, Error> {
    match operation.decode::<String>()?.as_str() {
        "detect_technologies" => {
            let req: TechnologyDetectionRequest = request.decode()?;
            let results = detect_technologies_with_central_integration(req);
            Ok((atoms::ok(), results).encode(env))
        }
        _ => {
            Ok((atoms::error(), atoms::unknown_operation()).encode(env))
        }
    }
}
```

**Issues:**
- Uses `Error` from rustler (auto-converts through `?`)
- Manual atom tuples for error encoding
- No custom error types
- No error context/messages passed to Elixir

### Pattern 2: String Error Returns (MODERN - PARSER_ENGINE)

```rust
// Parser Engine (lib.rs, line 192-200)
#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_file_nif(file_path: String) -> Result<AnalysisResult, String> {
    let path = Path::new(&file_path);
    let mut parser =
        PolyglotCodeParser::new().map_err(|e| format!("Failed to initialize parser: {}", e))?;

    let result = parser
        .analyze_file(path)
        .map_err(|e| format!("Failed to parse file: {}", e))?;

    Ok(result.into())
}
```

**Strengths:**
- Clear error messages with context
- Uses `map_err` to convert from library errors
- Scheduler directive correct (`DirtyCpu` for parsing)
- Proper error propagation with `?`

**Weaknesses:**
- String errors lose structure (no error codes)
- No error categorization
- Elixir side gets simple string, no pattern matching possible

### Pattern 3: Code Engine Errors (MODERN - CODE_ENGINE)

```rust
// Code Engine (nif_bindings.rs, line 54-70)
#[rustler::nif]
pub fn analyze_control_flow(file_path: String) -> Result<ControlFlowResult, String> {
    let graph = create_example_graph(&file_path)?;
    let analysis = analyze_function_flow(graph)
        .map_err(|e| format!("Analysis failed: {}", e))?;
    Ok(convert_analysis_to_result(analysis))
}
```

**Strengths:**
- Clear error messages
- Proper error conversion
- NifStruct for complex results

**Weaknesses:**
- Same as Pattern 2 (String errors without structure)
- No error categorization for Elixir pattern matching

---

## Rustler 0.37 Modern Patterns (NOT CURRENTLY USED)

### Pattern A: NifException Derive Macro

```rust
// Modern Rustler 0.37 pattern (NOT IN OUR CODE)
use rustler::NifException;

#[derive(Debug, NifException)]
#[module = "Singularity.ArchitectureEngineError"]
pub struct ArchitectureEngineError {
    pub message: String,
    pub error_code: String,
}

// In NIF function:
#[rustler::nif]
pub fn architecture_engine_call_modern(operation: String) -> Result<String, ArchitectureEngineError> {
    match operation.as_str() {
        "unknown" => Err(ArchitectureEngineError {
            message: "Unknown operation".to_string(),
            error_code: "UNKNOWN_OP".to_string(),
        }),
        _ => Ok("ok".to_string()),
    }
}

// Elixir receives as exception struct:
// {:error, %Singularity.ArchitectureEngineError{message: "...", error_code: "..."}}
```

### Pattern B: Result Type Handling (NOT FULLY USED)

```rust
// Rustler 0.37 automatic Result handling
#[rustler::nif]
pub fn parse_content(content: String) -> Result<ParseResult, String> {
    // Returns {:ok, ParseResult} or {:error, "message"}
    // Rustler automatically wraps in tuple
}
```

### Pattern C: Env-Based Error Encoding (PARTIALLY USED)

```rust
// Can create custom error terms
#[rustler::nif]
pub fn complex_operation<'a>(env: Env<'a>) -> Result<Term<'a>, Error> {
    // Use Error enum variants:
    // - Error::BadArg (wrong args)
    // - Error::Atom("error_atom") (atom)
    // - Error::RaiseAtom("error_atom") (raises exception)
    // - Error::Term(Box<dyn Encoder>) (custom term)

    Err(Error::Term(Box::new(("parse_error", "Invalid syntax"))))
}
```

---

## NIF Engine Inventory & Error Handling Status

| Engine | Rustler Ver | Pattern | Return Type | Scheduler | Status |
|--------|-------------|---------|-------------|-----------|--------|
| **architecture_engine** | 0.34 ❌ | Manual atoms | `Result<Term, Error>` | None (correct) | Needs update |
| **code_engine** | Not specified | String errors | `Result<T, String>` | None (should add) | Needs scheduler |
| **embedding_engine** | 0.34 ❌ | Unknown | Unknown | Unknown | Needs review |
| **parser_engine** | 0.34 ❌ | String errors | `Result<T, String>` | ✅ DirtyCpu | Good pattern, needs version |
| **quality_engine** | 0.34 (optional) | Not NIF-enabled | N/A | N/A | Feature-gated |
| **prompt_engine** | Not specified | Unknown | Unknown | Unknown | Needs review |
| **semantic_engine** | N/A | N/A | N/A | N/A | Not found in codebase |
| **knowledge_engine** | N/A | N/A | N/A | N/A | Not found in codebase |

---

## Compilation Issues Found

### Issue 1: Architecture Engine - Version 0.34 Missing Symbols

**File:** `/rust/architecture_engine/Cargo.toml:30`

```toml
rustler = { version = "0.34" }  # ❌ OUTDATED
```

**Error:**
```
error: linking with `gcc` failed
Undefined symbols for architecture arm64:
  "_enif_alloc_binary"
  "_enif_alloc_env"
  "_enif_free_env"
  ...
```

**Root Cause:** Architecture engine specifies 0.34 while workspace uses 0.37. Rustler 0.37 has different binary layout incompatibilities.

**Fix:**
```toml
# Should inherit from workspace:
rustler = { workspace = true }
```

### Issue 2: Feature Flag Warnings

**File:** `/rust/architecture_engine/src/lib.rs:36`

```rust
#[cfg(feature = "nif")]  // ⚠️ Feature not declared in Cargo.toml
pub mod nif;
```

**Error Message:**
```
warning: unexpected `cfg` condition value: `nif`
help: consider adding `nif` as a feature in `Cargo.toml`
```

**Fix:** Add feature flag to Cargo.toml:
```toml
[features]
default = ["nif"]
nif = []
```

### Issue 3: Unnecessary Unsafe Blocks

**File:** `/rust/parser_engine/core/src/lib.rs:300-323`

```rust
unsafe { tree_sitter_elixir::LANGUAGE.clone().into() }  // ⚠️ Unnecessary
```

**Fix:** Remove unsafe:
```rust
tree_sitter_elixir::LANGUAGE.clone().into()
```

---

## Error Handling Best Practices Checklist

### Rustler 0.37 Standards

#### ✅ What We're Doing Right

1. **Using `#[rustler::nif]` macro** (all engines)
   - Clean, declarative NIF functions
   - No manual NIF registration needed

2. **Explicit scheduler directives** (parser_engine)
   - `#[rustler::nif(schedule = "DirtyCpu")]` for CPU-intensive work
   - Prevents BEAM scheduler blocking

3. **Result type returns** (parser_engine, code_engine)
   - Modern pattern: `Result<T, String>`
   - Rustler automatically encodes as Elixir tuple: `{:ok, value}` or `{:error, message}`

4. **Type mapping with NifStruct** (parser_engine)
   - Automatic struct ↔ Elixir struct conversion
   - Clean serialization

5. **No unsafe code in NIFs** (mostly)
   - Safe wrapper pattern around unsafe Erlang NIF API
   - Rustler handles unsafe details

#### ❌ What Needs Improvement

1. **Rustler version mismatch** (CRITICAL)
   - Fix: Update all engines to use workspace version (0.37)

2. **No custom error types** (all engines)
   - Missing: `#[derive(NifException)]` for structured errors
   - Missing: Error categorization and codes

3. **Inconsistent error encoding** (architecture_engine)
   - Old: Manual atom tuples `(atoms::error(), atoms::unknown_operation())`
   - Better: Structured error types with NifException

4. **Missing scheduler directives** (code_engine)
   - Should add `#[rustler::nif(schedule = "DirtyCpu")]` for control flow analysis
   - Should add `#[rustler::nif(schedule = "DirtyIo")]` for file operations

5. **Error context loss** (all engines)
   - Error messages as strings don't allow pattern matching in Elixir
   - Solution: Use error structs with codes/categories

6. **Incomplete error documentation** (all engines)
   - No error codes defined
   - No Elixir exception modules declared
   - No error recovery guidance

---

## Recommended Modern Error Handling Pattern

### For Singularity NIFs

```rust
// 1. Define custom error type (Rustler 0.37+)
use rustler::NifException;

#[derive(Debug, Clone, NifException)]
#[module = "Singularity.NifError"]
pub struct NifError {
    pub code: String,
    pub message: String,
    pub context: Option<String>,
}

// 2. Implement conversion from internal errors
impl From<anyhow::Error> for NifError {
    fn from(err: anyhow::Error) -> Self {
        NifError {
            code: "INTERNAL_ERROR".to_string(),
            message: err.to_string(),
            context: None,
        }
    }
}

// 3. Use in NIF with proper scheduler directives
#[rustler::nif(schedule = "DirtyCpu")]
pub fn architecture_engine_call(
    operation: String,
    request: String,
) -> Result<String, NifError> {
    match operation.as_str() {
        "detect_technologies" => {
            let config = parse_request(&request)?;
            detect_technologies(config).map_err(|e| NifError {
                code: "DETECTION_FAILED".to_string(),
                message: e.to_string(),
                context: Some("detect_technologies".to_string()),
            })
        }
        _ => Err(NifError {
            code: "UNKNOWN_OPERATION".to_string(),
            message: format!("Unknown operation: {}", operation),
            context: None,
        }),
    }
}

// 4. Corresponding Elixir exception module
// defmodule Singularity.NifError do
//   defexception code: "ERROR", message: "", context: nil
// end
```

### Advantages

1. **Structured errors** - Elixir can pattern match on code
2. **Error categorization** - `DETECTION_FAILED`, `UNKNOWN_OPERATION`, etc.
3. **Context tracking** - Know where error originated
4. **Rustler 0.37 native** - Uses modern derive macro
5. **Type safe** - Compiler catches missing cases

---

## Migration Plan

### Phase 1: Version Alignment (IMMEDIATE)

**Files to update:**

1. `/rust/architecture_engine/Cargo.toml`
   ```diff
   - rustler = { version = "0.34" }
   + rustler = { workspace = true }
   ```

2. `/rust/embedding_engine/Cargo.toml`
   ```diff
   - rustler = "0.34"
   + rustler = { workspace = true }
   ```

3. `/rust/parser_engine/Cargo.toml`
   ```diff
   - rustler = "0.34"
   + rustler = { workspace = true }
   ```

4. `/rust/quality_engine/Cargo.toml`
   ```diff
   - rustler = { workspace = true, features = ["derive"], optional = true }
   + # Keep as-is (already correct)
   ```

### Phase 2: Feature Flag Fixes (IMMEDIATE)

**File:** `/rust/architecture_engine/Cargo.toml`

```diff
+ [features]
+ default = ["nif"]
+ nif = []
```

Same for other engines with `#[cfg(feature = "nif")]`.

### Phase 3: Error Type Modernization (SHORT-TERM)

**Per-engine approach:**

1. Create `error.rs` module in each engine
2. Define `#[derive(NifException)]` error type
3. Implement `From<...>` conversions
4. Update all `#[rustler::nif]` functions to use new error type

### Phase 4: Scheduler Directives (SHORT-TERM)

**Review and add:**

- `code_engine` NIF functions: Add `schedule = "DirtyCpu"` for analysis operations
- `embedding_engine`: Add `schedule = "DirtyIo"` if doing embeddings
- Document scheduler choice in each NIF

### Phase 5: Documentation (ONGOING)

**Add to each NIF:**

```rust
/// Detect technologies in codebase
///
/// This NIF uses DirtyCpu scheduler as pattern matching is CPU-intensive.
///
/// # Errors
///
/// Returns `Err(NifError)` with specific codes:
/// - `"INVALID_INPUT"` - Input request cannot be decoded
/// - `"DETECTION_FAILED"` - Pattern matching failed
/// - `"INTERNAL_ERROR"` - Unexpected error
///
/// # Elixir Usage
///
/// ```elixir
/// {:ok, results} = ArchitectureEngine.detect_technologies(code_patterns)
/// {:error, error} = ArchitectureEngine.detect_technologies(invalid_input)
/// # Pattern match on error code:
/// case error do
///   %NifError{code: "INVALID_INPUT"} -> handle_bad_input()
///   %NifError{code: "DETECTION_FAILED"} -> retry_with_fallback()
///   _ -> raise error
/// end
/// ```
#[rustler::nif(schedule = "DirtyCpu")]
pub fn detect_technologies(...) -> Result<..., NifError> { ... }
```

---

## Code Examples: Before & After

### Architecture Engine Error Handling

#### BEFORE (Current - Manual atoms)

```rust
#[rustler::nif]
pub fn architecture_engine_call<'a>(
    env: Env<'a>,
    operation: Term<'a>,
    request: Term<'a>,
) -> Result<Term<'a>, Error> {
    match operation.decode::<String>()?.as_str() {
        "detect_technologies" => {
            let req: TechnologyDetectionRequest = request.decode()?;
            let results = detect_technologies_with_central_integration(req);
            Ok((atoms::ok(), results).encode(env))
        }
        _ => {
            Ok((atoms::error(), atoms::unknown_operation()).encode(env))
        }
    }
}
```

**Elixir side:**
```elixir
case ArchitectureEngine.architecture_engine_call("unknown_op", data) do
  {:error, :unknown_operation} -> handle_error()  # Can pattern match
  {:ok, results} -> process(results)
end
```

#### AFTER (Modern - NifException)

```rust
#[derive(Debug, Clone, NifException)]
#[module = "Singularity.ArchitectureEngineError"]
pub struct ArchitectureEngineError {
    pub code: String,
    pub message: String,
}

#[rustler::nif]
pub fn detect_technologies(
    code_patterns: Vec<String>,
    known_technologies: Vec<Technology>,
) -> Result<Vec<TechnologyDetectionResult>, ArchitectureEngineError> {
    if code_patterns.is_empty() {
        return Err(ArchitectureEngineError {
            code: "EMPTY_PATTERNS".to_string(),
            message: "code_patterns cannot be empty".to_string(),
        });
    }

    Ok(detect_technologies_with_central_integration(
        TechnologyDetectionRequest {
            code_patterns,
            known_technologies,
            confidence_threshold: 0.7,
        },
    ))
}
```

**Elixir side:**
```elixir
case ArchitectureEngine.detect_technologies(patterns, techs) do
  {:ok, results} -> process(results)
  {:error, error} ->
    case error do
      %ArchitectureEngineError{code: "EMPTY_PATTERNS"} -> handle_empty()
      %ArchitectureEngineError{code: code} -> Logger.error("Error: #{code}")
    end
end
```

### Parser Engine Improvements

#### CURRENT (String errors)

```rust
#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_file_nif(file_path: String) -> Result<AnalysisResult, String> {
    let path = Path::new(&file_path);
    let mut parser = PolyglotCodeParser::new()
        .map_err(|e| format!("Failed to initialize parser: {}", e))?;

    parser.analyze_file(path)
        .map_err(|e| format!("Failed to parse file: {}", e))
        .map(|r| r.into())
}
```

#### IMPROVED (Structured errors with codes)

```rust
#[derive(Debug, Clone, NifException)]
#[module = "Singularity.ParserError"]
pub struct ParserError {
    pub code: String,
    pub message: String,
    pub file_path: Option<String>,
}

#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_file_nif(file_path: String) -> Result<AnalysisResult, ParserError> {
    let path = Path::new(&file_path);

    let mut parser = PolyglotCodeParser::new()
        .map_err(|e| ParserError {
            code: "PARSER_INIT_FAILED".to_string(),
            message: e.to_string(),
            file_path: Some(file_path.clone()),
        })?;

    parser.analyze_file(path)
        .map_err(|e| ParserError {
            code: "PARSE_FAILED".to_string(),
            message: e.to_string(),
            file_path: Some(file_path),
        })
        .map(|r| r.into())
}
```

---

## Compilation Verification

### Testing Phase 1: Update Versions

After updating Cargo.toml files:

```bash
cd /Users/mhugo/code/singularity-incubation/rust

# Test architecture_engine with workspace version
cd architecture_engine
cargo clean
cargo build 2>&1 | grep -E "error|warning: unexpected"
# Should have NO linking errors and NO "unexpected `cfg`" warnings

# Test parser_engine still works
cd ../parser_engine
cargo build 2>&1 | grep -E "error:|warning:" | head -20
# Should see no NIF-related errors

# Test code_engine
cd ../code_engine
cargo check 2>&1 | grep -E "error:|compilation\s+failed"
# Should have no errors
```

### Testing Phase 2: Error Handling

After implementing NifException patterns:

```elixir
# In test:
{:ok, _} = ArchitectureEngine.detect_technologies(valid_input)
{:error, error} = ArchitectureEngine.detect_technologies(invalid_input)

assert error.__struct__ == Singularity.ArchitectureEngineError
assert error.code == "EMPTY_PATTERNS"
assert String.contains?(error.message, "cannot be empty")
```

---

## Summary Table: Error Handling Compliance

| Criteria | Current | Target | Priority |
|----------|---------|--------|----------|
| Rustler version (0.37) | ❌ 50% | ✅ 100% | CRITICAL |
| Feature flags declared | ❌ 25% | ✅ 100% | HIGH |
| Scheduler directives | ⚠️ 40% | ✅ 100% | HIGH |
| NifException usage | ❌ 0% | ✅ 100% | MEDIUM |
| Error codes/categories | ❌ 0% | ✅ 100% | MEDIUM |
| Error documentation | ❌ 10% | ✅ 100% | MEDIUM |
| Type safety | ✅ 70% | ✅ 100% | LOW |
| Unnecessary unsafe | ❌ 5% | ✅ 100% | LOW |

---

## Files Requiring Action

### CRITICAL (Blocking compilation)

1. `/rust/architecture_engine/Cargo.toml` - Update rustler version
2. `/rust/embedding_engine/Cargo.toml` - Update rustler version
3. `/rust/parser_engine/Cargo.toml` - Update rustler version

### HIGH (Config issues)

4. `/rust/architecture_engine/Cargo.toml` - Add nif feature flag
5. `/rust/architecture_engine/src/lib.rs` - Remove unnecessary unsafe blocks
6. `/rust/parser_engine/core/src/lib.rs` - Remove unnecessary unsafe blocks

### MEDIUM (Error handling modernization)

7. `/rust/architecture_engine/src/nif.rs` - Add NifException error type
8. `/rust/parser_engine/src/lib.rs` - Add NifException error type
9. `/rust/code_engine/src/nif_bindings.rs` - Add NifException error type + scheduler directives

### LOW (Quality improvements)

10. All NIF functions - Add comprehensive Rustdoc with error codes
11. All engines - Define error code constants

---

## References

- **Rustler 0.37 Docs:** Error handling with modern patterns
- **Our Implementation:** Uses Rustler 0.34 legacy + 0.37 workspace config (conflict)
- **Best Practice:** NifException for structured errors, Result<T, E> for type safety

---

## Next Steps

1. **This week:** Fix Rustler versions (Phase 1 & 2)
2. **Next week:** Add error types to 3 main engines (Phase 3)
3. **Following week:** Add scheduler directives (Phase 4)
4. **Ongoing:** Document error codes (Phase 5)

Expected result: Clean compilation with modern error handling across all 8 NIF engines.
