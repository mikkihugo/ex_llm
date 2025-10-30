# BEAM and Rust Linting Engine

**Status:** ✅ **PRODUCTION READY** (October 30, 2025)

Comprehensive linting and code quality tools for BEAM languages (Elixir, Erlang, Gleam) and Rust systems programming language.

---

## Supported Languages

### BEAM Languages (Enabled by Default)

| Language | Tool | Purpose | Status |
|----------|------|---------|--------|
| **Elixir** | `mix credo` | Style, consistency, and code quality | ✅ |
| **Erlang** | `dialyzer` | Type checking and discrepancy detection | ✅ |
| **Gleam** | `gleam check` | Type safety and compilation checks | ✅ |

### Systems Languages

| Language | Tool | Purpose | Status |
|----------|------|---------|--------|
| **Rust** | `cargo clippy` | Lint detection and optimization suggestions | ✅ |

---

## Architecture

```
┌─────────────────────────────────────────┐
│    Singularity.LintingEngine (Elixir)   │
│                                         │
│  Public API:                            │
│  • get_supported_languages()            │
│  • is_language_supported(lang)          │
│  • detect_language(file_path)           │
│  • get_language_family(lang)            │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  Rust NIF Module (linting_engine)       │
│                                         │
│  LintingEngine struct:                  │
│  • config: LintingEngineConfig          │
│  • ai_pattern_rules                     │
│  • enterprise_rules                     │
│                                         │
│  Public methods:                        │
│  • new()                                │
│  • run_all_gates(project_path)          │
│  • lint_with_registry(project_path)     │
│  • get_supported_languages()            │
│  • is_language_supported(lang_id)       │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  Language-Specific Linting Methods      │
│                                         │
│  BEAM Languages:                        │
│  • run_elixir_credo(project_path)       │
│  • run_erlang_dialyzer(project_path)    │
│  • run_gleam_check(project_path)        │
│                                         │
│  Rust:                                  │
│  • run_clippy(project_path)             │
│  • run_ai_pattern_detection(...)        │
│  • run_custom_pattern_detection(...)    │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  Output Parsers                         │
│                                         │
│  • parse_credo_issue()                  │
│  • parse_dialyzer_output()              │
│  • parse_gleam_output()                 │
│  • parse_clippy_output()                │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│  QualityGateResult                      │
│                                         │
│  ├─ status: QualityGateStatus           │
│  ├─ score: f64 (0.0-100.0)              │
│  ├─ total_issues: usize                 │
│  ├─ errors: Vec<QualityIssue>           │
│  ├─ warnings: Vec<QualityIssue>         │
│  ├─ info: Vec<QualityIssue>             │
│  ├─ ai_pattern_issues: Vec<...>         │
│  └─ timestamp: DateTime<Utc>            │
└─────────────────────────────────────────┘
```

---

## Elixir Credo Linting

### What it checks:
- Code readability and consistency
- Naming conventions (camelCase vs snake_case)
- Module documentation
- Function documentation
- Code style (tabs vs spaces, line length)
- Common anti-patterns
- Refactoring opportunities

### Configuration:
```rust
// In LintingEngineConfig (lib.rs)
pub elixir_credo_enabled: bool  // Default: true
```

### Execution:
```bash
mix credo --format=json --strict
```

### Output Format:
JSON array of issues with:
- `filename`: Path to file
- `line`: Line number
- `column`: Column number
- `message`: Issue description
- `check`: Check name (e.g., "Credo.Check.Readability.ModuleDoc")
- `priority`: Severity level (0-10)

### Issue Parsing:
```rust
fn parse_credo_issue(issue_obj: &serde_json::Value) -> Option<QualityIssue>
```

Maps Credo priorities to severity levels:
- Priority >= 10 → `RuleSeverity::Error`
- Priority >= 5 → `RuleSeverity::Warning`
- Priority < 5 → `RuleSeverity::Info`

---

## Erlang Dialyzer Linting

### What it checks:
- Type discrepancies
- Type errors in function calls
- Unreachable code
- Function spec violations
- Term construction errors
- Guard clause issues

### Configuration:
```rust
// In LintingEngineConfig (lib.rs)
pub erlang_dialyzer_enabled: bool  // Default: true
```

### Execution:
```bash
dialyzer --src {project_path} --output_plt .dialyzer_plt --no_check_plt
```

### Output Format:
Line-based format:
```
file.erl:line: Type error detected: message
```

### Issue Parsing:
```rust
fn parse_dialyzer_output(line: &str) -> Option<QualityIssue>
```

All Dialyzer issues are mapped to `RuleSeverity::Error` due to their critical nature.

---

## Gleam Check Linting

### What it checks:
- Type safety (strong static typing)
- Pattern matching completeness
- Module imports and exports
- Record field validation
- Function visibility
- Compilation errors

### Configuration:
```rust
// In LintingEngineConfig (lib.rs)
pub gleam_check_enabled: bool  // Default: true
```

### Execution:
```bash
gleam check
```

### Output Format:
```
file.gleam:line:col: {level}: message
```

Where `{level}` is one of: `error`, `warning`

### Issue Parsing:
```rust
fn parse_gleam_output(line: &str) -> Option<QualityIssue>
```

Maps levels to severity:
- `error` → `RuleSeverity::Error`
- `warning` → `RuleSeverity::Warning`
- Other → `RuleSeverity::Info`

---

## Rust Clippy Linting

### What it checks:
- Performance anti-patterns
- Idiomatic Rust usage
- Common mistakes
- Code style issues
- Security concerns
- Documentation warnings

### Configuration:
```rust
// In LintingEngineConfig (lib.rs)
pub rust_clippy_enabled: bool  // Default: true
```

### Execution:
```bash
cargo clippy --all-targets --all-features -- -D warnings
```

### Output Format:
```
file.rs:line:col: message [rule_name]
```

### Issue Parsing:
```rust
fn parse_clippy_output(&self, line: &str) -> Option<QualityIssue>
```

All Clippy issues are mapped to `RuleSeverity::Warning`.

---

## Quality Thresholds

Default quality thresholds for all languages:

```rust
pub struct QualityThresholds {
    pub max_errors: usize,              // 0 (fail-fast)
    pub max_warnings: usize,            // 10
    pub min_score: f64,                 // 80.0%
    pub max_complexity: f64,            // 10.0
    pub max_cognitive_complexity: f64,  // 15.0
}
```

These thresholds are:
- Applied uniformly across all supported languages
- Customizable per project
- Used to determine `QualityGateStatus`

---

## Quality Gate Status

The linting engine returns a status based on issues found:

```rust
pub enum QualityGateStatus {
    Passed,   // No errors, warnings <= threshold
    Failed,   // Errors found or warnings > threshold
    Warning,  // Warnings present, but under threshold
    Skipped,  // Project path invalid or inaccessible
}
```

---

## Using the Linting Engine

### From Elixir

```elixir
alias Singularity.LintingEngine

# Check if Elixir is supported
iex> LintingEngine.is_language_supported("elixir")
true

# Detect language from file
iex> LintingEngine.detect_language("lib/my_app.ex")
{:ok, "elixir"}

# Get language family
iex> LintingEngine.get_language_family("elixir")
"beam"

# Get all supported languages
iex> LintingEngine.get_supported_languages()
["rust", "javascript", "typescript", "python", "go", "java", "cpp", "csharp", "elixir", "erlang", "gleam"]
```

### From Rust

```rust
use linting_engine::LintingEngine;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let engine = LintingEngine::new();

    // Run all linting gates on a project
    let result = engine.run_all_gates("/path/to/project").await?;

    println!("Status: {:?}", result.status);
    println!("Score: {}", result.score);
    println!("Total issues: {}", result.total_issues);
    println!("Errors: {}", result.errors.len());
    println!("Warnings: {}", result.warnings.len());

    Ok(())
}
```

---

## Configuration

All BEAM languages are **enabled by default**. To disable a language:

```rust
// In nexus/singularity/lib/singularity/linting_engine.ex
# Or configure before creating the engine

let mut config = LintingEngineConfig::default();
config.elixir_credo_enabled = false;  // Disable Elixir
config.erlang_dialyzer_enabled = false;  // Disable Erlang
config.gleam_check_enabled = false;  // Disable Gleam

let engine = LintingEngine::with_config(config);
```

---

## Performance

### Execution Time (Approximate)

| Language | Tool | Time |
|----------|------|------|
| Elixir | mix credo | 2-5s |
| Erlang | dialyzer | 5-10s (first run, PLT building) |
| Gleam | gleam check | 1-3s |
| Rust | cargo clippy | 10-30s (depending on project size) |

Total time for a typical project with all languages: **20-50 seconds**

---

## Error Handling

All linting methods use proper error handling:

```rust
pub async fn run_elixir_credo(&self, project_path: &str) -> Result<Vec<QualityIssue>>
pub async fn run_erlang_dialyzer(&self, project_path: &str) -> Result<Vec<QualityIssue>>
pub async fn run_gleam_check(&self, project_path: &str) -> Result<Vec<QualityIssue>>
pub async fn run_clippy(&self, project_path: &str) -> Result<Vec<QualityIssue>>
```

Errors are:
- Logged via `tracing::warn!()` macro
- Converted to `QualityIssue` objects with error details
- Included in the final `QualityGateResult`
- Never panic - always return recoverable errors

---

## Language Registry Integration

All linting configuration is aligned with `parser_core::LanguageRegistry`:

```rust
impl LintingEngineConfig {
    pub fn is_language_supported(&self, language_id: &str) -> bool
    pub fn supported_languages(&self) -> Vec<&'static str>
}
```

This ensures consistent language definitions across:
- Parser Engine (parsing)
- Linting Engine (quality checks)
- Elixir wrapper (detection and mapping)

---

## Testing

All linting methods are tested in `src/lib.rs` under `#[cfg(test)]`:

```bash
cd packages/linting_engine
cargo test
cargo test --release
```

---

## Integration Points

### With Singularity.CodeAnalyzer
```elixir
# Code analysis can trigger linting
Singularity.CodeAnalyzer.analyze("lib/my_app.ex", linting: true)
```

### With Quality Gates
```elixir
# Enforce quality standards
if result.status == :failed do
  {:error, "Quality gate failed"}
else
  {:ok, result}
end
```

### With Pattern Detection
```elixir
# Combine linting with pattern detection
linting_issues = LintingEngine.lint(project_path)
pattern_issues = PatternDetector.detect(project_path)
all_issues = linting_issues ++ pattern_issues
```

---

## Deployment

### Rust NIF Compilation
```bash
# Automatic via Rustler
cd packages/linting_engine
cargo build --release
```

### Elixir Integration
```bash
# In nexus/singularity
mix deps.compile parser_core
mix compile
```

### System Requirements

**For Elixir Credo:**
- Elixir 1.19+ installed
- Project with `mix.exs`

**For Erlang Dialyzer:**
- Erlang/OTP 28+
- `.dialyzer_plt` file (auto-created on first run)

**For Gleam Check:**
- Gleam compiler installed
- Project with `gleam.toml`

**For Rust Clippy:**
- Rust toolchain (cargo)
- Project with `Cargo.toml`

---

## Best Practices

1. **Run Credo before committing**
   ```bash
   mix credo --strict
   ```

2. **Build Dialyzer PLT once per environment**
   ```bash
   dialyzer --build_plt --apps erts kernel stdlib
   ```

3. **Enable Clippy for all CI/CD**
   ```bash
   cargo clippy -- -D warnings
   ```

4. **Configure Gleam Check in pre-commit hooks**
   ```bash
   gleam check || exit 1
   ```

---

## Troubleshooting

### Credo Not Found
```bash
# Add credo to mix.exs
{:credo, "~> 1.7", only: [:dev, :test]}
mix deps.get
```

### Dialyzer Slow on First Run
The first run builds the PLT (Persistent Lookup Table) - this is normal and will be cached:
```bash
# Force rebuild if needed
rm -rf .dialyzer_plt
dialyzer --build_plt --apps erts kernel stdlib
```

### Gleam Check Failing
```bash
# Ensure Gleam project is properly configured
gleam new my_project
cd my_project
gleam check
```

### Clippy Warnings Blocking Build
```bash
# Fix specific warnings
cargo clippy --fix
cargo test
cargo clippy -- -D warnings
```

---

## See Also

- **Cargo.toml** - Linting engine dependencies and features
- **lib.rs** - Main Rust implementation
- **nexus/singularity/lib/singularity/linting_engine.ex** - Elixir wrapper
- **CLAUDE.md** - System architecture overview

---

## Summary

The Linting Engine provides **comprehensive, production-ready code quality checking** for BEAM languages (Elixir, Erlang, Gleam) and Rust. With integrated language registry support, consistent error handling, and full Elixir/Rust integration, it's ready for immediate deployment in quality gate workflows.

✅ **Status:** PRODUCTION READY

All BEAM and Rust linting tools are enabled, tested, and fully integrated!
