# Rustler 0.37 Migration: Ready-to-Use Code Fixes

This document contains exact code that can be copy-pasted to fix error handling issues across all NIF engines.

---

## Fix 1: Update Cargo.toml - Architecture Engine

**File:** `/rust/architecture_engine/Cargo.toml`

Replace lines 19-30:

```toml
# BEFORE:
[dependencies]
# Core dependencies
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
ahash = "0.8"
parking_lot = "0.12"
chrono = { version = "0.4", features = ["serde"] }
anyhow = "1.0"
thiserror = "1.0"

# NIF support for Elixir integration
rustler = { version = "0.34" }
```

```toml
# AFTER:
[dependencies]
# Core dependencies
serde = { workspace = true }
serde_json = { workspace = true }
ahash = { workspace = true }
parking_lot = { workspace = true }
chrono = { workspace = true }
anyhow = { workspace = true }
thiserror = { workspace = true }

# NIF support for Elixir integration (use workspace version: 0.37)
rustler = { workspace = true }
```

Then add feature flags at the end of Cargo.toml:

```toml
[features]
default = ["nif"]
nif = []
```

---

## Fix 2: Update Cargo.toml - Embedding Engine

**File:** `/rust/embedding_engine/Cargo.toml`

Change this line:
```toml
# BEFORE:
rustler = "0.34"

# AFTER:
rustler = { workspace = true }
```

Add feature flags if not present:
```toml
[features]
nif = ["rustler"]
```

---

## Fix 3: Update Cargo.toml - Parser Engine

**File:** `/rust/parser_engine/Cargo.toml`

Change this line:
```toml
# BEFORE:
rustler = "0.34"

# AFTER:
rustler = { workspace = true }
```

---

## Fix 4: Remove Unnecessary Unsafe Blocks

**File:** `/rust/parser_engine/core/src/lib.rs` (lines 300-323)

Replace this:
```rust
self.language_cache.insert("elixir".to_string(), unsafe { tree_sitter_elixir::LANGUAGE.clone().into() });
self.language_cache.insert("erlang".to_string(), unsafe { tree_sitter_erlang::LANGUAGE.clone().into() });
self.language_cache.insert("gleam".to_string(), unsafe { tree_sitter_gleam::LANGUAGE.clone().into() });
...
```

With this:
```rust
self.language_cache.insert("elixir".to_string(), tree_sitter_elixir::LANGUAGE.clone().into());
self.language_cache.insert("erlang".to_string(), tree_sitter_erlang::LANGUAGE.clone().into());
self.language_cache.insert("gleam".to_string(), tree_sitter_gleam::LANGUAGE.clone().into());
...
```

Complete block (all unsafe removed):
```rust
// Initialize all language parsers
self.language_cache.insert("elixir".to_string(), tree_sitter_elixir::LANGUAGE.clone().into());
self.language_cache.insert("erlang".to_string(), tree_sitter_erlang::LANGUAGE.clone().into());
self.language_cache.insert("gleam".to_string(), tree_sitter_gleam::LANGUAGE.clone().into());

// Rust ecosystem
self.language_cache.insert("rust".to_string(), tree_sitter_rust::LANGUAGE.clone().into());
self.language_cache.insert("c".to_string(), tree_sitter_c::LANGUAGE.clone().into());
self.language_cache.insert("cpp".to_string(), tree_sitter_cpp::LANGUAGE.clone().into());

// Web development
self.language_cache.insert("javascript".to_string(), tree_sitter_javascript::LANGUAGE.clone().into());
self.language_cache.insert("typescript".to_string(), tree_sitter_typescript::LANGUAGE_TYPESCRIPT.clone().into());
self.language_cache.insert("json".to_string(), tree_sitter_json::LANGUAGE.clone().into());

// Other languages
self.language_cache.insert("python".to_string(), tree_sitter_python::LANGUAGE.clone().into());
self.language_cache.insert("lua".to_string(), tree_sitter_lua::LANGUAGE.clone().into());
self.language_cache.insert("bash".to_string(), tree_sitter_bash::LANGUAGE.clone().into());

// More languages
self.language_cache.insert("go".to_string(), tree_sitter_go::LANGUAGE.clone().into());
self.language_cache.insert("java".to_string(), tree_sitter_java::LANGUAGE.clone().into());
self.language_cache.insert("yaml".to_string(), tree_sitter_yaml::LANGUAGE.clone().into());
self.language_cache.insert("csharp".to_string(), tree_sitter_c_sharp::LANGUAGE.clone().into());
```

---

## Fix 5: Add Modern Error Type to Architecture Engine

**File:** `/rust/architecture_engine/src/error.rs` (NEW FILE)

Create new file with this content:

```rust
//! Error types for Architecture Engine NIF
//!
//! Provides structured error handling that maps to Elixir exception modules.
//! Uses Rustler 0.37 `#[derive(NifException)]` for automatic encoding.

use rustler::NifException;
use std::fmt;

/// Architecture Engine NIF errors
///
/// Maps to Elixir module: `Singularity.Rust.ArchitectureEngineError`
///
/// Supported error codes:
/// - "INVALID_INPUT" - Input data cannot be decoded or is invalid
/// - "DETECTION_FAILED" - Detection/analysis failed (with context)
/// - "EMPTY_PATTERNS" - Required patterns list is empty
/// - "UNSUPPORTED_TECH" - Technology not in known list
/// - "INTERNAL_ERROR" - Unexpected internal error
#[derive(Debug, Clone, NifException)]
#[module = "Singularity.Rust.ArchitectureEngineError"]
pub struct ArchitectureEngineError {
    /// Machine-readable error code for pattern matching in Elixir
    pub code: String,

    /// Human-readable error message
    pub message: String,

    /// Optional context (operation name, file path, etc.)
    pub context: Option<String>,
}

impl ArchitectureEngineError {
    /// Create a new error with code and message
    pub fn new(code: &str, message: &str) -> Self {
        Self {
            code: code.to_string(),
            message: message.to_string(),
            context: None,
        }
    }

    /// Add context to error (e.g., operation name)
    pub fn with_context(mut self, context: &str) -> Self {
        self.context = Some(context.to_string());
        self
    }

    /// Error code constant: Invalid input
    pub const INVALID_INPUT: &'static str = "INVALID_INPUT";

    /// Error code constant: Detection failed
    pub const DETECTION_FAILED: &'static str = "DETECTION_FAILED";

    /// Error code constant: Empty patterns
    pub const EMPTY_PATTERNS: &'static str = "EMPTY_PATTERNS";

    /// Error code constant: Unsupported technology
    pub const UNSUPPORTED_TECH: &'static str = "UNSUPPORTED_TECH";

    /// Error code constant: Internal error
    pub const INTERNAL_ERROR: &'static str = "INTERNAL_ERROR";
}

impl fmt::Display for ArchitectureEngineError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{}] {}", self.code, self.message)?;
        if let Some(ref ctx) = self.context {
            write!(f, " ({})", ctx)?;
        }
        Ok(())
    }
}

impl From<anyhow::Error> for ArchitectureEngineError {
    fn from(err: anyhow::Error) -> Self {
        Self {
            code: Self::INTERNAL_ERROR.to_string(),
            message: err.to_string(),
            context: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_error_creation() {
        let err = ArchitectureEngineError::new("TEST_ERROR", "Test message");
        assert_eq!(err.code, "TEST_ERROR");
        assert_eq!(err.message, "Test message");
        assert_eq!(err.context, None);
    }

    #[test]
    fn test_error_with_context() {
        let err = ArchitectureEngineError::new("TEST_ERROR", "Test message")
            .with_context("detect_technologies");
        assert_eq!(err.context, Some("detect_technologies".to_string()));
    }

    #[test]
    fn test_error_display() {
        let err = ArchitectureEngineError::new("TEST_ERROR", "Test message")
            .with_context("operation");
        let display = format!("{}", err);
        assert_eq!(display, "[TEST_ERROR] Test message (operation)");
    }
}
```

Then add to `/rust/architecture_engine/src/lib.rs`:

```rust
// Add near the top, after `pub mod` declarations:
pub mod error;
pub use error::ArchitectureEngineError;
```

---

## Fix 6: Update Architecture Engine NIF to Use Error Type

**File:** `/rust/architecture_engine/src/nif.rs`

Replace the entire imports section (lines 118-135):

```rust
// BEFORE:
use rustler::{Encoder, Env, Error, Term};
use crate::technology_detection::{TechnologyDetectionRequest, TechnologyDetectionResult};
use crate::architecture::{ArchitecturalSuggestionRequest, ArchitecturalSuggestion};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        detect_frameworks,
        detect_technologies,
        get_architectural_suggestions,
        unknown_operation
    }
}
```

```rust
// AFTER:
use crate::error::ArchitectureEngineError;
use crate::technology_detection::{TechnologyDetectionRequest, TechnologyDetectionResult};
use crate::architecture::{ArchitecturalSuggestionRequest, ArchitecturalSuggestion};
```

Replace the main NIF function (lines 141-193):

```rust
// BEFORE:
#[rustler::nif]
pub fn architecture_engine_call<'a>(env: Env<'a>, operation: Term<'a>, request: Term<'a>) -> Result<Term<'a>, Error> {

    match operation.decode::<String>()?.as_str() {
        "detect_technologies" => {
            let req: TechnologyDetectionRequest = request.decode()?;
            let results = detect_technologies_with_central_integration(req);
            Ok((atoms::ok(), results).encode(env))
        }

        "get_architectural_suggestions" => {
            let req: ArchitecturalSuggestionRequest = request.decode()?;
            let results = get_architectural_suggestions_with_central_integration(req);
            Ok((atoms::ok(), results).encode(env))
        }

        "get_package_stats" => {
            let package_name: String = request.decode()?;
            let stats = get_package_stats_from_central(package_name);
            Ok((atoms::ok(), stats).encode(env))
        }

        "get_framework_stats" => {
            let framework_name: String = request.decode()?;
            let stats = get_framework_stats_from_central(framework_name);
            Ok((atoms::ok(), stats).encode(env))
        }

        _ => {
            Ok((atoms::error(), atoms::unknown_operation()).encode(env))
        }
    }
}
```

```rust
// AFTER:
/// Main NIF entry point for architecture engine operations
///
/// Handles requests for technology/framework detection and statistics.
/// Uses DirtyCpu scheduler as pattern matching is computationally intensive.
///
/// # Errors
///
/// Returns `Err(ArchitectureEngineError)` with specific codes:
/// - "INVALID_INPUT" - Request cannot be decoded
/// - "EMPTY_PATTERNS" - code_patterns is empty
/// - "DETECTION_FAILED" - Pattern matching failed
/// - "INTERNAL_ERROR" - Unexpected error
///
/// # Elixir Usage
///
/// ```elixir
/// case ArchitectureEngine.detect_technologies(patterns, technologies) do
///   {:ok, results} -> process(results)
///   {:error, error} ->
///     case error do
///       %Error{code: "EMPTY_PATTERNS"} -> Logger.warn("No patterns")
///       %Error{code: code} -> Logger.error("Error #{code}: #{error.message}")
///     end
/// end
/// ```
#[rustler::nif(schedule = "DirtyCpu")]
pub fn detect_technologies(
    code_patterns: Vec<String>,
    known_technologies: Vec<serde_json::Value>,
) -> Result<Vec<TechnologyDetectionResult>, ArchitectureEngineError> {
    if code_patterns.is_empty() {
        return Err(ArchitectureEngineError::new(
            ArchitectureEngineError::EMPTY_PATTERNS,
            "code_patterns cannot be empty",
        ));
    }

    // Deserialize JSON technologies to proper struct
    let mut tech_list = Vec::new();
    for tech_json in known_technologies {
        match serde_json::from_value(tech_json) {
            Ok(tech) => tech_list.push(tech),
            Err(e) => {
                return Err(ArchitectureEngineError::new(
                    ArchitectureEngineError::INVALID_INPUT,
                    &format!("Failed to parse technology definition: {}", e),
                ))
            }
        }
    }

    let req = TechnologyDetectionRequest {
        code_patterns,
        known_technologies: tech_list,
        confidence_threshold: 0.7,
    };

    let results = detect_technologies_with_central_integration(req);
    Ok(results)
}

/// Get architectural suggestions
#[rustler::nif(schedule = "DirtyCpu")]
pub fn get_architectural_suggestions(
    suggestion_types: Vec<String>,
) -> Result<Vec<ArchitecturalSuggestion>, ArchitectureEngineError> {
    if suggestion_types.is_empty() {
        return Err(ArchitectureEngineError::new(
            ArchitectureEngineError::INVALID_INPUT,
            "suggestion_types cannot be empty",
        ));
    }

    let req = ArchitecturalSuggestionRequest {
        suggestion_types,
        codebase_info: None,
        confidence_threshold: 0.6,
    };

    let results = get_architectural_suggestions_with_central_integration(req);
    Ok(results)
}
```

---

## Fix 7: Modern Error Type for Parser Engine

**File:** `/rust/parser_engine/src/error.rs` (NEW FILE)

```rust
//! Error types for Parser Engine NIF
//!
//! Provides structured error handling using Rustler 0.37 NifException.
//! Maps to Elixir: `Singularity.Rust.ParserError`

use rustler::NifException;
use std::fmt;

/// Parser Engine errors
#[derive(Debug, Clone, NifException)]
#[module = "Singularity.Rust.ParserError"]
pub struct ParserError {
    /// Machine-readable error code: "INIT_FAILED", "PARSE_FAILED", "INVALID_LANGUAGE"
    pub code: String,

    /// Human-readable error message
    pub message: String,

    /// File path (if applicable)
    pub file_path: Option<String>,

    /// Line number where error occurred
    pub line_number: Option<usize>,
}

impl ParserError {
    pub fn new(code: &str, message: &str) -> Self {
        Self {
            code: code.to_string(),
            message: message.to_string(),
            file_path: None,
            line_number: None,
        }
    }

    pub fn with_file(mut self, path: &str) -> Self {
        self.file_path = Some(path.to_string());
        self
    }

    pub fn with_line(mut self, line: usize) -> Self {
        self.line_number = Some(line);
        self
    }

    // Error codes
    pub const INIT_FAILED: &'static str = "PARSER_INIT_FAILED";
    pub const PARSE_FAILED: &'static str = "PARSE_FAILED";
    pub const INVALID_LANGUAGE: &'static str = "INVALID_LANGUAGE";
    pub const INVALID_INPUT: &'static str = "INVALID_INPUT";
    pub const INTERNAL_ERROR: &'static str = "INTERNAL_ERROR";
}

impl fmt::Display for ParserError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{}] {}", self.code, self.message)?;
        if let Some(ref path) = self.file_path {
            write!(f, " in {}", path)?;
            if let Some(line) = self.line_number {
                write!(f, ":{}", line)?;
            }
        }
        Ok(())
    }
}

impl From<anyhow::Error> for ParserError {
    fn from(err: anyhow::Error) -> Self {
        Self {
            code: Self::INTERNAL_ERROR.to_string(),
            message: err.to_string(),
            file_path: None,
            line_number: None,
        }
    }
}
```

Add to `/rust/parser_engine/src/lib.rs`:

```rust
pub mod error;
pub use error::ParserError;
```

Update parser NIF function in `/rust/parser_engine/src/lib.rs`:

```rust
// BEFORE:
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

// AFTER:
/// Parse and analyze a file
///
/// # Errors
///
/// - "PARSER_INIT_FAILED" - Parser initialization failed
/// - "PARSE_FAILED" - File parsing failed
/// - "INVALID_INPUT" - Invalid file path
#[rustler::nif(schedule = "DirtyCpu")]
pub fn parse_file_nif(file_path: String) -> Result<AnalysisResult, ParserError> {
    let path = Path::new(&file_path);

    let mut parser = PolyglotCodeParser::new()
        .map_err(|e| ParserError::new(
            ParserError::INIT_FAILED,
            &e.to_string(),
        ).with_file(&file_path))?;

    let result = parser
        .analyze_file(path)
        .map_err(|e| ParserError::new(
            ParserError::PARSE_FAILED,
            &e.to_string(),
        ).with_file(&file_path))?;

    Ok(result.into())
}
```

---

## Fix 8: Add Scheduler Directives to Code Engine

**File:** `/rust/code_engine/src/nif_bindings.rs`

Update these NIF function signatures (around lines 53-300):

```rust
// BEFORE:
#[rustler::nif]
pub fn analyze_control_flow(file_path: String) -> Result<ControlFlowResult, String> {

#[rustler::nif]
pub fn analyze_language(code: String, language_hint: String) -> Result<LanguageAnalysisResult, String> {

#[rustler::nif]
pub fn check_language_rules(code: String, language_hint: String) -> Result<Vec<RuleViolationResult>, String> {

// AFTER - Add scheduler directive:
/// Analyze control flow of code
///
/// This is a pure computation NIF - NO I/O!
/// Uses DirtyCpu scheduler as control flow graph analysis is CPU-intensive.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn analyze_control_flow(file_path: String) -> Result<ControlFlowResult, String> {

/// Analyze language features and complexity
///
/// Uses DirtyCpu scheduler for language detection and analysis.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn analyze_language(code: String, language_hint: String) -> Result<LanguageAnalysisResult, String> {

/// Check code against language-specific rules
///
/// Uses DirtyCpu scheduler for rule evaluation.
#[rustler::nif(schedule = "DirtyCpu")]
pub fn check_language_rules(code: String, language_hint: String) -> Result<Vec<RuleViolationResult>, String> {
```

---

## Fix 9: Add Elixir Exception Module

Create new file: `/singularity/lib/singularity/rust/architecture_engine_error.ex`

```elixir
defmodule Singularity.Rust.ArchitectureEngineError do
  @moduledoc """
  Exception raised by Architecture Engine NIF with structured error codes.

  ## Error Codes

  - `"INVALID_INPUT"` - Input request cannot be decoded
  - `"DETECTION_FAILED"` - Framework/technology detection failed
  - `"EMPTY_PATTERNS"` - code_patterns list is empty
  - `"UNSUPPORTED_TECH"` - Technology not in known technologies list
  - `"INTERNAL_ERROR"` - Unexpected internal Rust error

  ## Pattern Matching Example

      case ArchitectureEngine.detect_technologies(code, techs) do
        {:ok, results} ->
          process(results)

        {:error, error} ->
          case error do
            %Singularity.Rust.ArchitectureEngineError{code: "EMPTY_PATTERNS"} ->
              Logger.warn("Empty code patterns provided")

            %Singularity.Rust.ArchitectureEngineError{code: code, message: msg} ->
              Logger.error("Architecture engine error #{code}: #{msg}")
          end
      end
  """

  defexception code: "ERROR", message: "", context: nil

  @type t :: %__MODULE__{
          code: String.t(),
          message: String.t(),
          context: String.t() | nil
        }

  def message(%__MODULE__{code: code, message: message, context: nil}) do
    "[#{code}] #{message}"
  end

  def message(%__MODULE__{code: code, message: message, context: context}) do
    "[#{code}] #{message} (#{context})"
  end
end
```

Create similar for ParserError: `/singularity/lib/singularity/rust/parser_error.ex`

```elixir
defmodule Singularity.Rust.ParserError do
  @moduledoc """
  Exception raised by Parser Engine NIF with structured error codes.

  ## Error Codes

  - `"PARSER_INIT_FAILED"` - Parser initialization failed
  - `"PARSE_FAILED"` - File parsing failed
  - `"INVALID_LANGUAGE"` - Unsupported language
  - `"INVALID_INPUT"` - Invalid input data
  - `"INTERNAL_ERROR"` - Unexpected internal error
  """

  defexception code: "ERROR", message: "", file_path: nil, line_number: nil

  @type t :: %__MODULE__{
          code: String.t(),
          message: String.t(),
          file_path: String.t() | nil,
          line_number: non_neg_integer() | nil
        }

  def message(%__MODULE__{code: code, message: message, file_path: nil}) do
    "[#{code}] #{message}"
  end

  def message(%__MODULE__{code: code, message: message, file_path: file, line_number: nil}) do
    "[#{code}] #{message} in #{file}"
  end

  def message(%__MODULE__{code: code, message: message, file_path: file, line_number: line}) do
    "[#{code}] #{message} in #{file}:#{line}"
  end
end
```

---

## Verification Commands

After applying all fixes:

```bash
cd /Users/mhugo/code/singularity-incubation/rust

# Test compilation
cargo build --all 2>&1 | grep -E "^error|warning: unexpected"

# Should output: (no errors and no "unexpected cfg" warnings)

# Run clippy
cargo clippy --all 2>&1 | grep -E "^error"

# Should output: (no clippy errors)

# Check formatting
cargo fmt --all -- --check

# Should output: (nothing = all formatted correctly)
```

---

## Testing in Elixir

After fixes compile successfully:

```elixir
# In test file:
test "architecture engine error handling" do
  # Test with empty patterns
  assert {:error, error} = ArchitectureEngine.detect_technologies([], [])
  assert error.code == "EMPTY_PATTERNS"
  assert String.contains?(error.message, "cannot be empty")

  # Test with valid input
  assert {:ok, results} = ArchitectureEngine.detect_technologies(
    ["import React"],
    [%{technology_name: "React"}]
  )
end

test "parser error handling" do
  # Test with invalid file
  assert {:error, error} = ParserEngine.parse_file("/nonexistent/file.rs")
  assert error.code == "PARSE_FAILED"
  assert error.file_path == "/nonexistent/file.rs"
end
```

---

## Summary of Changes

| File | Change | Priority |
|------|--------|----------|
| architecture_engine/Cargo.toml | Update rustler version + add features | CRITICAL |
| embedding_engine/Cargo.toml | Update rustler version | CRITICAL |
| parser_engine/Cargo.toml | Update rustler version | CRITICAL |
| parser_engine/core/src/lib.rs | Remove unsafe blocks | HIGH |
| architecture_engine/src/error.rs | NEW - Error type | HIGH |
| architecture_engine/src/lib.rs | Export error module | HIGH |
| architecture_engine/src/nif.rs | Use NifException errors | HIGH |
| parser_engine/src/error.rs | NEW - Error type | HIGH |
| parser_engine/src/lib.rs | Export error module + update NIFs | HIGH |
| code_engine/src/nif_bindings.rs | Add scheduler directives | MEDIUM |
| singularity/lib/singularity/rust/architecture_engine_error.ex | NEW - Elixir exception | MEDIUM |
| singularity/lib/singularity/rust/parser_error.ex | NEW - Elixir exception | MEDIUM |

Total lines to change: ~200 (90% are new error handling code)
