# Fix: Remove Template Architecture Violation in PR #2

**Issue**: PR #2 created duplicate `.prompt` files that violate the single-source-of-truth principle
**Root Cause**: Stub implementation of `SparcTemplateGenerator::get_template()` in wrong file
**Solution**: Remove stub, use real `SparcTemplateGenerator` from `sparc_templates.rs`

---

## Problem Analysis

### What Happened

PR #2 added a stub implementation to `template_performance_tracker.rs`:

```rust
impl SparcTemplateGenerator {
    /// Get template by ID (stub for integration)
    pub fn get_template(&self, template_id: &str) -> Option<String> {
        match template_id {
            "sparc_specification" => Some(include_str!("../templates/sparc/specification.prompt").to_string()),
            "sparc_pseudocode" => Some(include_str!("../templates/sparc/pseudocode.prompt").to_string()),
            "sparc_architecture" => Some(include_str!("../templates/sparc/architecture.prompt").to_string()),
            "sparc_refinement" => Some(include_str!("../templates/sparc/refinement.prompt").to_string()),
            "sparc_completion" => Some(include_str!("../templates/sparc/completion.prompt").to_string()),
            _ => None,
        }
    }
}
```

This requires creating 5 `.prompt` files that:
1. Duplicate existing JSON templates in `tool_doc_index`
2. Violate single-source-of-truth architecture
3. Are just placeholders with no real content

### Why It's Wrong

1. **`SparcTemplateGenerator` is already defined** in `sparc_templates.rs` with proper implementation
2. **Templates already exist** in `tool_doc_index/templates/workflows/sparc/*.json`
3. **The code has a guard** against this: `ensure_single_source_of_truth()`

### The Real Architecture

```
sparc_templates.rs (REAL)
├── SparcTemplateGenerator::new()
├── register_sparc_templates()
└── Creates PromptTemplate objects in memory
    └── name, template, language, domain, quality_score

template_performance_tracker.rs (SHOULD USE REAL)
├── TemplatePerformanceTracker
└── load_template() calls sparc_generator.get_sparc_template()
```

---

## The Fix

### Step 1: Remove Stub Implementation

**File**: `rust/prompt_engine/src/template_performance_tracker.rs`

**Remove lines 266-278**:
```rust
impl SparcTemplateGenerator {
    /// Get template by ID (stub for integration)
    pub fn get_template(&self, template_id: &str) -> Option<String> {
        match template_id {
            "sparc_specification" => Some(include_str!("../templates/sparc/specification.prompt").to_string()),
            "sparc_pseudocode" => Some(include_str!("../templates/sparc/pseudocode.prompt").to_string()),
            "sparc_architecture" => Some(include_str!("../templates/sparc/architecture.prompt").to_string()),
            "sparc_refinement" => Some(include_str!("../templates/sparc/refinement.prompt").to_string()),
            "sparc_completion" => Some(include_str!("../templates/sparc/completion.prompt").to_string()),
            _ => None,
        }
    }
}
```

### Step 2: Update `load_template()` Method

**File**: `rust/prompt_engine/src/template_performance_tracker.rs`

**Current** (lines 249-256):
```rust
fn load_template(&self, template_id: &str) -> Result<PromptTemplate> {
    // Load from SPARC generator or template registry
    Ok(PromptTemplate {
        name: template_id.to_string(),
        template: self.sparc_generator.get_template(template_id)
            .unwrap_or_else(|| format!("Template {} not found", template_id)),
    })
}
```

**Fixed**:
```rust
fn load_template(&self, template_id: &str) -> Result<PromptTemplate> {
    // Load from SPARC generator (which uses tool_doc_index as source of truth)
    self.sparc_generator
        .get_sparc_template(template_id)
        .cloned()
        .ok_or_else(|| anyhow::anyhow!("Template {} not found", template_id))
}
```

### Step 3: Remove `.prompt` Files

**Delete these files**:
- `rust/prompt_engine/templates/sparc/specification.prompt`
- `rust/prompt_engine/templates/sparc/pseudocode.prompt`
- `rust/prompt_engine/templates/sparc/architecture.prompt`
- `rust/prompt_engine/templates/sparc/refinement.prompt`
- `rust/prompt_engine/templates/sparc/completion.prompt`

**Delete the directory if empty**:
- `rust/prompt_engine/templates/sparc/`
- `rust/prompt_engine/templates/` (if no other files)

### Step 4: Verify the Fix

**Run tests**:
```bash
cargo test -p prompt-engine
```

**Run the guard**:
```rust
#[test]
fn test_no_template_duplication() {
    use prompt_engine::template_loader::ensure_single_source_of_truth;
    assert!(ensure_single_source_of_truth().is_ok());
}
```

---

## Understanding the Real Implementation

### How `SparcTemplateGenerator` Works (in `sparc_templates.rs`)

1. **Creates in-memory templates**:
```rust
impl SparcTemplateGenerator {
    pub fn new() -> Self {
        let mut registry = RegistryTemplate::new();
        Self::register_sparc_templates(&mut registry);
        Self { registry }
    }
}
```

2. **Registers templates with metadata**:
```rust
registry.register(PromptTemplate {
    name: "sparc_specification".to_string(),
    template: r#"[Full template content]"#.to_string(),
    language: "generic".to_string(),
    domain: "sparc".to_string(),
    quality_score: 0.8,
});
```

3. **Provides access via methods**:
```rust
pub fn get_sparc_template(&self, prompt_name: &str) -> Option<&PromptTemplate>
pub fn get_all_sparc_templates(&self) -> Vec<&PromptTemplate>
pub fn get_templates_by_domain(&self, domain: &str) -> Vec<&PromptTemplate>
```

### Why This Is Better

1. **Single source of truth** - Templates only in `sparc_templates.rs`
2. **Type-safe** - Returns `PromptTemplate` objects with metadata
3. **No file I/O** - Compiled into binary
4. **Extensible** - Easy to add new templates by updating registration

---

## Why Was The Stub Created?

The PR author likely saw compilation errors from `template_performance_tracker.rs` calling `get_template()` which doesn't exist on `SparcTemplateGenerator`. Instead of:

1. ✅ Using the existing `get_sparc_template()` method
2. ✅ Checking the real `SparcTemplateGenerator` implementation

They:

1. ❌ Added a stub `impl SparcTemplateGenerator` block
2. ❌ Created dummy `.prompt` files to make it compile

**This is a classic case of "make it compile" without understanding the architecture.**

---

## Template Naming Mapping

| `template_performance_tracker.rs` | `sparc_templates.rs` | `tool_doc_index` |
|-----------------------------------|----------------------|------------------|
| `sparc_specification` | `sparc_specification` | `workflows/sparc/1-specification.json` |
| `sparc_pseudocode` | `sparc_pseudocode` | `workflows/sparc/2-pseudocode.json` |
| `sparc_architecture` | `sparc_architecture` | `workflows/sparc/3-architecture.json` |
| `sparc_refinement` | `sparc_refinement` | `workflows/sparc/7-refinement.json` |
| `sparc_completion` | `sparc_completion` | `workflows/sparc/8-implementation.json` |

**Note**: The JSON files in `tool_doc_index` are the **source of truth** for external systems. The Rust code in `sparc_templates.rs` embeds these for performance.

---

## Architectural Principles

### Single Source of Truth

**From `template_loader.rs`**:
```rust
//! Loads templates from tool_doc_index - the single source of truth!
//! No duplication, just references.
```

**Implementation**:
- External systems → Use JSON in `tool_doc_index/templates/`
- Rust code → Embed templates in `sparc_templates.rs` for performance
- **Never** create separate `.prompt` files

### Template Evolution

1. **Add new template**:
   - Add to `tool_doc_index/templates/` as JSON (external API)
   - Register in `sparc_templates.rs` (Rust API)
   - Never create standalone `.prompt` files

2. **Update template**:
   - Update JSON in `tool_doc_index`
   - Update registration in `sparc_templates.rs`
   - Keep them in sync

### Guard Rails

The codebase has guards against architectural violations:

```rust
pub fn ensure_single_source_of_truth() -> Result<()> {
    let templates_in_prompt_engine = prompt_engine_dir.join("templates");
    if templates_in_prompt_engine.exists() {
        return Err(anyhow::anyhow!(
            "Templates should be in tool_doc_index, not prompt_engine"
        ));
    }
    Ok(())
}
```

**This should be in CI/CD** to catch violations automatically.

---

## Commands to Apply Fix

```bash
# 1. Remove stub implementation (manual edit required)
#    Edit: rust/prompt_engine/src/template_performance_tracker.rs
#    Remove: Lines 266-278

# 2. Update load_template method (manual edit required)
#    Edit: rust/prompt_engine/src/template_performance_tracker.rs
#    Update: Lines 249-256

# 3. Remove .prompt files
rm -rf rust/prompt_engine/templates/sparc/
rmdir rust/prompt_engine/templates/ 2>/dev/null || true

# 4. Verify compilation
cargo build -p prompt-engine --lib

# 5. Run tests
cargo test -p prompt-engine

# 6. Verify guard
cargo test -p prompt-engine ensure_single_source_of_truth
```

---

## Expected Outcome

### Before Fix
```
rust/prompt_engine/
├── src/
│   ├── template_performance_tracker.rs (has stub impl)
│   └── sparc_templates.rs (real impl)
└── templates/
    └── sparc/
        ├── specification.prompt ❌
        ├── pseudocode.prompt ❌
        ├── architecture.prompt ❌
        ├── refinement.prompt ❌
        └── completion.prompt ❌
```

### After Fix
```
rust/prompt_engine/
└── src/
    ├── template_performance_tracker.rs (uses real impl)
    └── sparc_templates.rs (real impl) ✅
```

**No template files in `prompt_engine` - all templates via `sparc_templates.rs` registration.**

---

## Testing the Fix

### Unit Tests

```rust
#[test]
fn test_template_performance_tracker_loads_sparc() {
    let tracker = TemplatePerformanceTracker::new();

    // Should load from SparcTemplateGenerator, not files
    let template = tracker.load_template("sparc_specification");
    assert!(template.is_ok());

    let tmpl = template.unwrap();
    assert_eq!(tmpl.name, "sparc_specification");
    assert!(!tmpl.template.is_empty());
}

#[test]
fn test_no_template_files_in_prompt_engine() {
    use std::path::PathBuf;
    let prompt_engine_templates = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("templates");

    assert!(!prompt_engine_templates.exists(),
        "Templates directory should not exist in prompt_engine");
}
```

### Integration Test

```bash
# Verify all SPARC templates work
cargo run --bin test-sparc-templates

# Expected output:
# ✓ sparc_specification loaded
# ✓ sparc_pseudocode loaded
# ✓ sparc_architecture loaded
# ✓ sparc_refinement loaded
# ✓ sparc_completion loaded
```

---

## Summary

**The fix is simple**:
1. Remove the stub `impl SparcTemplateGenerator` block
2. Use the real `get_sparc_template()` method
3. Delete the unnecessary `.prompt` files

**Why this matters**:
- Preserves architectural integrity
- Prevents future confusion
- Follows single-source-of-truth principle
- Makes codebase easier to maintain

**Time to fix**: 10 minutes
**Risk**: Low (just removes duplication)
**Benefit**: High (prevents technical debt)
