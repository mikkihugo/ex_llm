# Prompt-Engine Remaining Errors (32 total)

## Progress

- ✅ Fixed: Float ambiguity errors (f64::min)
- ✅ Fixed: ProcessedMicroserviceCode fields
- ✅ Fixed: LLMClient async_trait annotation
- ⏳ Remaining: 32 errors (down from original 164+)

## Error Breakdown

### 1. RepositoryAnalysis Type Changes (19 errors)
**Issue:** `codebase` crate's `RepositoryAnalysis` type structure changed

```
15× error: no field `packages` on type `types::RepositoryAnalysis`
 2× error: no field `directory_structure` on type `types::RepositoryAnalysis`
 1× error: no field `tech_stacks` on type `types::RepositoryAnalysis`
 1× error: no field `domains` on type `types::RepositoryAnalysis`
```

**Files affected:**
- `src/prompt_bits/assembler.rs` - Multiple references to old RepositoryAnalysis structure

**Fix required:** Update to match new RepositoryAnalysis structure from codebase crate
```rust
// Check crates/codebase/src/repository/mod.rs for actual structure
pub struct RepositoryAnalysis {
    // Find actual fields
}
```

### 2. COPRO API Changes (3 errors)
**Issue:** DSPy COPRO optimizer API was refactored

```
2× error: no function or associated item named `new` found for struct `COPRO`
1× error: no method named `optimize` found for struct `COPRO`
```

**Files affected:**
- `src/lib.rs:95` - `COPRO::new()` call
- `src/lib.rs:267` - `.optimize()` method call

**Fix required:** Check new COPRO API in dspy module
```rust
// Check src/dspy/optimizer/copro/mod.rs for actual API
```

### 3. Message API Changes (2 errors)
**Issue:** dspy_data::Message structure changed

```
1× error: no method named `content` found for struct `dspy_data::Message`
1× error: non-exhaustive patterns: `&dspy_data::Message { .. }` not covered
```

**Files affected:**
- DSPy message handling code

**Fix required:** Update to match new Message structure
```rust
// Check src/dspy_data.rs or dspy module for Message definition
```

### 4. Type Enum Changes (3 errors)
**Issue:** codebase types enum structure changed

```
1× error: no variant `Moon` in enum `types::BuildSystem`
1× error: no method `hash` on enum `types::WorkspaceType`
1× error: no method `hash` on enum `types::BuildSystem`
1× error: variant `MessageBroker::NATS` does not have fields `clusters`, `jetstream`
```

**Files affected:**
- Code using BuildSystem, WorkspaceType, MessageBroker enums

**Fix required:** Update enum usage to match codebase types
```rust
// Check crates/codebase/src/types.rs for actual enum definitions
```

### 5. Borrow Checker Issues (1 error)
```
1× error: cannot borrow `*self` as mutable because it is also borrowed as immutable
```

**Fix required:** Refactor borrowing logic

### 6. Float Ambiguity (1 error)
```
1× error: can't call method `min` on ambiguous numeric type `{float}`
```

**Fix required:** Change to `f64::min(score, 1.0)`

## Recommended Fix Order

### Phase 1: Type Updates (High Impact, 25+ errors)
1. **Update RepositoryAnalysis usage** (19 errors)
   - Check actual structure in `crates/codebase/src/repository/mod.rs`
   - Update all references in `assembler.rs`

2. **Update Type Enums** (4 errors)
   - BuildSystem: Remove Moon variant or add it
   - Add Hash derive or use different comparison
   - Update MessageBroker::NATS structure

### Phase 2: API Updates (Medium Impact, 5 errors)
3. **Fix COPRO API** (3 errors)
   - Find new constructor API
   - Find new optimize method API
   - Update usage in lib.rs

4. **Fix Message API** (2 errors)
   - Check new Message structure
   - Update pattern matching

### Phase 3: Minor Fixes (Low Impact, 2 errors)
5. **Fix remaining float** (1 error)
6. **Fix borrow checker** (1 error)

## Next Steps

1. Check actual type definitions in codebase crate:
   ```bash
   grep -r "pub struct RepositoryAnalysis" crates/codebase/
   grep -r "pub enum BuildSystem" crates/codebase/
   grep -r "pub enum WorkspaceType" crates/codebase/
   ```

2. Check COPRO API:
   ```bash
   grep -r "impl COPRO" crates/prompt-engine/src/dspy/
   ```

3. Check Message structure:
   ```bash
   grep -r "pub struct Message" crates/prompt-engine/src/
   ```

4. Systematically fix each category

## Impact

**Current Status:**
- sparc-engine LLM architecture: ✅ Complete (0 errors)
- prompt-engine: ⏳ 32 errors remaining (functional but not compiling)

**Blocking:** No - sparc-engine main functionality works, prompt-engine is enhancement

**Priority:** Medium - Can be fixed incrementally as types stabilize