# GitHub Issue Template: Re-enable Commented-Out Modules

Use this template to track each module that was disabled in PR #2.

---

## Template

```markdown
## Overview

Module `<MODULE_NAME>` was commented out in PR #2 to fix compilation errors and achieve release readiness. This issue tracks the work needed to re-enable it.

**Location**: `<FILE_PATH>`
**Commented in PR**: #2
**Priority**: <Low|Medium|High>

---

## Compilation Errors

When uncommented, this module produces the following errors:

```
<PASTE EXACT ERROR OUTPUT>
```

---

## Dependencies

This module depends on:

- [ ] <Dependency 1>
- [ ] <Dependency 2>
- [ ] <Dependency 3>

**Missing crates/modules**:
- <List missing external dependencies>

**API mismatches**:
- <List struct/trait mismatches>

---

## Root Cause Analysis

**Why it was disabled**:
<Brief explanation of the core issue>

**Type of issue**:
- [ ] Missing external dependency
- [ ] API changed in dependent crate
- [ ] Lifetime/borrow checker issues
- [ ] Type mismatches
- [ ] Architectural refactor needed

---

## Fix Strategy

### Option 1: Quick Fix (Estimated: X hours)
<Description of minimal changes to make it compile>

### Option 2: Proper Fix (Estimated: X days)
<Description of architectural improvements needed>

**Recommended approach**: <Option 1 | Option 2>

---

## Acceptance Criteria

- [ ] Module compiles without errors
- [ ] Existing tests pass
- [ ] New tests added for fixed functionality
- [ ] No new warnings introduced
- [ ] Documentation updated

---

## Related Issues

- Blocks: <list issues that depend on this>
- Blocked by: <list issues this depends on>
- Related: <list related architectural work>

---

## Notes

<Any additional context, gotchas, or architectural considerations>
```

---

## Specific Issues to Create

Based on PR #2, create these issues:

### Issue 1: Re-enable `storage_template` module

```markdown
## Overview

Module `storage_template` was commented out in PR #2 to fix compilation errors and achieve release readiness. This issue tracks the work needed to re-enable it.

**Location**: `rust/tool_doc_index/src/storage_template.rs`
**Commented in PR**: #2
**Priority**: Medium

---

## Compilation Errors

When uncommented, this module produces type mismatches with the current FACT storage API.

**Symptoms**:
- `FactData` struct initialization failed due to missing fields
- PR #2 added 13 fields with placeholder defaults to make it compile
- These defaults may not be semantically correct

---

## Dependencies

This module depends on:

- [x] `FactData` struct definition (exists but may have wrong defaults)
- [ ] FACT storage service API documentation
- [ ] Embedding service integration
- [ ] Vector database connection

**Missing documentation**:
- Semantic meaning of `FactData` default values
- Expected field values for different fact types

---

## Root Cause Analysis

**Why it was disabled**:
The `FactData` struct evolved but `storage_template` wasn't updated to match the new API.

**Type of issue**:
- [x] API changed in dependent module
- [x] Type mismatches
- [ ] Architectural refactor needed

---

## Fix Strategy

### Option 1: Validate Defaults (Estimated: 2-4 hours)
1. Review FACT system semantics
2. Validate that placeholder defaults are correct
3. Add tests confirming expected behavior
4. Update documentation

### Option 2: Refactor Template Storage (Estimated: 2 days)
1. Redesign how templates interact with FACT storage
2. Create proper abstraction layer
3. Implement builder pattern for `FactData`
4. Add comprehensive tests

**Recommended approach**: Option 1 (validate first, refactor if needed)

---

## Acceptance Criteria

- [ ] Module compiles without errors
- [ ] All `FactData` defaults validated against FACT semantics
- [ ] Tests verify template storage works correctly
- [ ] Documentation explains field meanings
- [ ] No semantic bugs from incorrect defaults

---

## Related Issues

- Related: FACT system documentation (#TBD)
- Related: Vector embeddings integration (#TBD)

---

## Notes

From PR #2, these defaults were added:
```rust
embedding: vec![],
confidence: 0.0,
source: "unknown".to_string(),
// ... 10 more fields
```

Need to verify if `0.0` confidence means "unknown" or "certain false".
```

---

### Issue 2: Re-enable `layered_detector` module

```markdown
## Overview

Module `layered_detector` was commented out in PR #2 to fix compilation errors and achieve release readiness. This issue tracks the work needed to re-enable it.

**Location**: `rust/tool_doc_index/src/detection/layered_detector.rs`
**Commented in PR**: #2
**Priority**: Low

---

## Compilation Errors

```
error: multiple applicable items in scope
  --> src/detection/layered_detector.rs:XXX
   |
   | score.min(other_score)
   |       ^^^ multiple `min` found
```

**Root cause**: Ambiguous float type - Rust can't determine if it's `f32::min` or `f64::min`.

---

## Dependencies

This module depends on:

- [x] Detection framework (exists)
- [x] Float type standardization

---

## Root Cause Analysis

**Why it was disabled**:
Float type ambiguity. PR #2 fixed this in other files by using `f32::min()` but module was disabled before applying fix here.

**Type of issue**:
- [x] Type mismatches (easily fixable)

---

## Fix Strategy

### Option 1: Apply Same Fix (Estimated: 15 minutes)
1. Replace `.min()` with `f32::min()` (3 locations)
2. Uncomment module
3. Verify compilation
4. Run existing tests

**Recommended approach**: Option 1 (trivial fix)

---

## Acceptance Criteria

- [ ] Module compiles without errors
- [ ] Changed `.min()` → `f32::min()` in all locations
- [ ] Existing tests pass
- [ ] No warnings introduced

---

## Related Issues

- Same fix was applied in PR #2 to other files

---

## Notes

This is a trivial fix that can be done in under 30 minutes. It was likely disabled due to time constraints during PR #2.
```

---

### Issue 3: Re-enable template submodules

```markdown
## Overview

Template submodules (`selector`, `loader`, `context_builder`) were commented out in PR #2 to fix compilation errors.

**Location**: `rust/tool_doc_index/src/templates/template.rs`, `mod.rs`
**Commented in PR**: #2
**Priority**: Medium

---

## Compilation Errors

Mutable borrow checker issues:
```
error[E0502]: cannot borrow as mutable because it is also borrowed as immutable
```

---

## Dependencies

This module depends on:

- [ ] Refactored template loading architecture
- [ ] Separation of read/write concerns
- [ ] Possibly Rc<RefCell<>> or Arc<RwLock<>> patterns

---

## Root Cause Analysis

**Why it was disabled**:
Template loader tries to hold immutable reference while also mutating state.

**Type of issue**:
- [x] Lifetime/borrow checker issues
- [x] Architectural refactor needed

---

## Fix Strategy

### Option 1: Quick Fix with RefCell (Estimated: 4 hours)
1. Wrap mutable state in `RefCell<>`
2. Update borrowing patterns
3. Add runtime borrow checking

### Option 2: Architectural Refactor (Estimated: 3 days)
1. Separate template loading from caching
2. Use builder pattern for template construction
3. Implement proper ownership model
4. Eliminate shared mutable state

**Recommended approach**: Option 1 first, then Option 2 when time allows

---

## Acceptance Criteria

- [ ] All submodules compile
- [ ] Borrow checker issues resolved
- [ ] Tests verify concurrent access works
- [ ] No runtime borrow panics
- [ ] Performance not degraded

---

## Related Issues

- Related: Template architecture refactor (#TBD)
- Blocked by: Template loading design review

---

## Notes

Consider whether these modules are even needed or if functionality can be merged into main template module.
```

---

### Issue 4: Re-enable `prompts` module

```markdown
## Overview

Module `prompts` was commented out in PR #2 because it depends on `prompt_engine` crate which wasn't available.

**Location**: `rust/tool_doc_index/src/prompts/mod.rs`
**Commented in PR**: #2
**Priority**: High

---

## Compilation Errors

```
error: could not compile `tool_doc_index` due to missing `prompt_engine` crate
```

---

## Dependencies

This module depends on:

- [x] `prompt_engine` crate (now fixed in PR #2!)
- [ ] Proper integration between tool_doc_index and prompt_engine
- [ ] Clarify which crate owns prompt functionality

---

## Root Cause Analysis

**Why it was disabled**:
PR #2 fixed `prompt_engine` compilation but didn't re-enable this module. **This might work now!**

**Type of issue**:
- [x] Missing dependency (NOW FIXED)
- [ ] Architectural clarity needed

---

## Fix Strategy

### Option 1: Try Uncommenting (Estimated: 30 minutes)
1. Uncomment the module
2. Add `prompt_engine` to Cargo.toml dependencies
3. See if it compiles
4. Fix any minor API mismatches

### Option 2: Remove Module (Estimated: 1 hour)
If functionality is duplicated in `prompt_engine`, consider removing this module entirely.

**Recommended approach**: Option 1 first, then decide

---

## Acceptance Criteria

- [ ] Module compiles OR decision made to remove it
- [ ] No functionality duplication with `prompt_engine`
- [ ] Clear ownership of prompt-related code
- [ ] Tests pass

---

## Related Issues

- Fixed in PR #2: prompt_engine now compiles
- Related: Prompt architecture clarity (#TBD)

---

## Notes

**IMPORTANT**: Since `prompt_engine` is now fixed, this module might "just work" with minimal changes. Try uncommenting it first!
```

---

## Tracking Dashboard

Create a GitHub project board with these columns:

| Blocked | Ready | In Progress | Testing | Done |
|---------|-------|-------------|---------|------|
| (waiting on deps) | (can start now) | (actively working) | (needs verification) | (completed) |

**Initial placement**:
- **Ready**: `layered_detector` (trivial fix)
- **Ready**: `prompts` (dependency now available)
- **Blocked**: Template submodules (needs architecture decision)
- **Blocked**: `storage_template` (needs semantic validation)

---

## Success Metrics

- [ ] All 4 issues created and linked to PR #2
- [ ] Each issue has clear acceptance criteria
- [ ] Effort estimates provided
- [ ] Dependencies mapped
- [ ] Priority assigned
- [ ] Added to project board
