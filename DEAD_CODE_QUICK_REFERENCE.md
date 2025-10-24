# Dead Code Quick Reference

## Current Status (2025-01-23)

**Total `#[allow(dead_code)]` annotations:** 35
**All valid:** ✅ Yes (100%)

---

## When to Use #[allow(dead_code)]

### ✅ VALID USES

**1. Struct Fields Used by Derive Macros**
```rust
#[derive(Debug, Clone)]
struct Metrics {
    #[allow(dead_code)]  // Used by Debug trait
    count: usize,
}
```

**2. Future Features (Well-Documented)**
```rust
#[allow(dead_code)] // Reserved for caching optimization (Issue #123)
cache: HashMap<String, Value>,
```

**3. Helper Functions (Constructor Patterns)**
```rust
#[allow(dead_code)]  // Helper to ensure all fields set correctly
fn create_result(id: usize, score: f64) -> Result { ... }
```

**4. Public API (Unused Internally)**
```rust
#[allow(dead_code)]  // Public API - used by external crates
pub fn export_data(&self) -> Vec<u8> { ... }
```

### ❌ INVALID USES

**1. Disabled Features Without Plans**
```rust
// BAD - RCA is disabled with no plan to re-enable
#[allow(dead_code)]
fn calculate_rca_metrics() -> f64 { 0.0 }
```

**2. Unused Helpers With No Callers**
```rust
// BAD - Never called, no future plans documented
#[allow(dead_code)]
fn helper() { ... }
```

**3. Scaffolding for Removed Features**
```rust
// BAD - Feature was removed 6 months ago
#[allow(dead_code)]
old_implementation: OldSystem,
```

---

## Documentation Template

**Always add a comment explaining WHY:**

```rust
// ✅ GOOD - Explains reason
#[allow(dead_code)] // Used by Serde serialization
field: String,

#[allow(dead_code)] // Reserved for template system (tracked in Issue #456)
template_registry: Registry,

#[allow(dead_code)] // Public API - used by centralcloud crate
pub fn sync_data(&self) { ... }

// ❌ BAD - No explanation
#[allow(dead_code)]
field: String,
```

---

## Audit Checklist

When auditing `#[allow(dead_code)]` annotations:

- [ ] Is it used by a derive macro (Debug, Serialize, Deserialize)?
  - ✅ **KEEP** with comment: `// Used by Debug/Serde`

- [ ] Is it documented as a future feature?
  - ✅ **KEEP** if comment explains why and when
  - ❌ **REMOVE** if no plan or explanation

- [ ] Is it a helper function?
  - ✅ **KEEP** if it ensures correctness (constructor pattern)
  - ⚠️ **USE IT** if it reduces duplication
  - ❌ **REMOVE** if never called and no plans

- [ ] Is it for a disabled feature?
  - ✅ **KEEP** if temporary (will re-enable)
  - ❌ **REMOVE** if permanently disabled

- [ ] Is it public API?
  - ✅ **KEEP** even if unused internally
  - Add comment: `// Public API - used by X crate`

---

## Current Breakdown (35 items)

| Category | Count | Action |
|----------|-------|--------|
| Struct fields (Debug/Serde) | 18 | ✅ KEEP |
| Future features | 7 | ✅ KEEP |
| Cache placeholders | 4 | ✅ KEEP |
| Helper functions | 4 | ✅ KEEP |
| Other valid | 2 | ✅ KEEP |

---

## Commands

### Find All Annotations
```bash
find rust -name "*.rs" | xargs grep -n "#\[allow(dead_code)\]"
```

### Count Annotations
```bash
find rust -name "*.rs" | xargs grep "#\[allow(dead_code)\]" | wc -l
```

### Find Undocumented Annotations
```bash
# Find annotations without explanatory comments
find rust -name "*.rs" | xargs grep -B1 "#\[allow(dead_code)\]" | \
  grep -A1 "allow(dead_code)\]$" | grep -v "^--$"
```

---

## Next Audit

**Schedule:** 6 months (July 2025)

**Tasks:**
1. Re-run scan for all annotations
2. Check if "future features" have been implemented
3. Remove scaffolding for permanently disabled features
4. Verify all annotations have explanatory comments

---

## Related Docs

- **DEAD_CODE_CLEANUP_COMPLETE.md** - Full cleanup report
- **DEAD_CODE_AUDIT.md** - Detailed audit of all 40 original annotations
- **RUST_MAINTENANCE_GUIDE.md** - Comprehensive maintenance practices
