# AGENTS.md

## Code Refactoring with `awk` - Large File Breakdown Strategy

This document describes the systematic approach for refactoring large Rust files (1000+ lines) into smaller, maintainable modules while preserving all functionality.

## Problem

Large files become unmaintainable:
- `naming_conventions.rs` - 3154 lines
- `analyzer.rs` - 1900+ lines  
- `quality_engine/src/lib.rs` - 1000+ lines

**Goal**: Break into logical modules without losing any functionality.

## Solution: `awk`-Based Function Extraction

### 1. Identify Function Patterns

Use `awk` with regex patterns to extract related functions:

```bash
# Extract all suggest_* functions
awk '/fn suggest_/,/^    }/' large_file.rs > suggest_functions.rs

# Extract all generate_* functions  
awk '/fn generate_/,/^    }/' large_file.rs > generate_functions.rs

# Extract all validate_* functions
awk '/fn validate_/,/^    }/' large_file.rs > validate_functions.rs

# Extract all to_* functions (conversions)
awk '/fn to_/,/^    }/' large_file.rs > to_functions.rs

# Extract all extract_* functions
awk '/fn extract_/,/^    }/' large_file.rs > extract_functions.rs
```

### 2. Validate Extraction

Check function counts to ensure nothing is lost:

```bash
# Count functions in original
grep -c 'fn ' large_file.rs

# Count functions in extractions
grep -c 'fn ' *_functions.rs

# Verify totals match
echo "Original: $(grep -c 'fn ' large_file.rs)"
echo "Extracted: $(grep -c 'fn ' *_functions.rs)"
```

### 3. Organize into Logical Modules

Group related functions into coherent modules:

```bash
# Naming suggestions (all suggest + generate + extract)
cat suggest_functions.rs generate_functions.rs extract_functions.rs > naming_suggestions.rs

# Utilities (validate + convert)
cat validate_functions.rs to_functions.rs > naming_utilities.rs

# Architecture patterns
cat architecture_functions.rs pattern_functions.rs > architecture_patterns.rs
```

### 4. Create Module Structure

Each new module needs:

```rust
//! Module description
//! 
//! What this module does and why it exists.

use std::collections::HashMap;
use anyhow::Result;
use serde::{Deserialize, Serialize};

// Import dependencies
use crate::other_module::{SomeType, OtherType};

/// Main struct for this module
pub struct ModuleName {
    // fields
}

impl ModuleName {
    /// Create new instance
    pub fn new() -> Self {
        // implementation
    }
    
    // All extracted functions go here
}

impl Default for ModuleName {
    fn default() -> Self {
        Self::new()
    }
}
```

### 5. Update Main Module

Replace the large file with a clean orchestrator:

```rust
//! Main Module - Orchestrator
//!
//! Coordinates all functionality using modular components.

// Import modular components
use crate::naming_suggestions::NamingSuggestions;
use crate::naming_utilities::NamingUtilities;
use crate::architecture_patterns::ArchitecturePatterns;

/// Main handler
pub struct MainModule {
    pub(crate) suggestions: NamingSuggestions,
    pub(crate) utilities: NamingUtilities,
    pub(crate) patterns: ArchitecturePatterns,
}

impl MainModule {
    /// Create new instance
    pub fn new() -> Self {
        Self {
            suggestions: NamingSuggestions::new(),
            utilities: NamingUtilities::new(),
            patterns: ArchitecturePatterns::new(),
        }
    }
    
    /// Delegate to appropriate module
    pub fn suggest_function_names(&self, description: &str) -> Vec<String> {
        self.suggestions.suggest_function_names(description)
    }
    
    pub fn validate_name(&self, name: &str) -> bool {
        self.utilities.validate_name(name)
    }
}
```

## Advanced Patterns

### Extract by Function Type

```bash
# All public functions
awk '/pub fn /,/^    }/' file.rs > public_functions.rs

# All private functions  
awk '/    fn /,/^    }/' file.rs > private_functions.rs

# All trait implementations
awk '/impl.*for/,/^}/' file.rs > trait_implementations.rs
```

### Extract by Module Section

```bash
# All struct definitions
awk '/^pub struct/,/^}/' file.rs > structs.rs

# All enum definitions
awk '/^pub enum/,/^}/' file.rs > enums.rs

# All type aliases
awk '/^pub type/,/;/' file.rs > type_aliases.rs
```

### Extract with Context

```bash
# Functions with 5 lines of context before/after
awk '/fn function_name/,/^    }/' file.rs | head -n -5 | tail -n +6 > function_with_context.rs
```

## Validation Checklist

Before considering refactoring complete:

- [ ] Function count matches original
- [ ] All dependencies are properly imported
- [ ] Module structure is logical and coherent
- [ ] Main orchestrator delegates correctly
- [ ] No compilation errors
- [ ] All tests still pass
- [ ] Documentation is updated

## Example: Complete Workflow

```bash
# 1. Backup original
cp naming_conventions.rs naming_conventions_old.rs

# 2. Extract by pattern
awk '/fn suggest_/,/^    }/' naming_conventions_old.rs > suggest_functions.rs
awk '/fn generate_/,/^    }/' naming_conventions_old.rs > generate_functions.rs
awk '/fn validate_/,/^    }/' naming_conventions_old.rs > validate_functions.rs
awk '/fn to_/,/^    }/' naming_conventions_old.rs > to_functions.rs

# 3. Validate counts
echo "Original: $(grep -c 'fn ' naming_conventions_old.rs)"
echo "Extracted: $(grep -c 'fn ' *_functions.rs)"

# 4. Organize into modules
cat suggest_functions.rs generate_functions.rs > naming_suggestions.rs
cat validate_functions.rs to_functions.rs > naming_utilities.rs

# 5. Create new main file
# (manually create orchestrator)

# 6. Clean up
rm *_functions.rs
```

## Benefits

- **Preserves Functionality**: No code is lost during refactoring
- **Systematic**: Uses patterns to ensure comprehensive extraction
- **Validatable**: Function counts can verify completeness
- **Maintainable**: Smaller, focused modules are easier to understand
- **Testable**: Individual modules can be tested in isolation

## Anti-Patterns to Avoid

❌ **Manual Copy-Paste**: Error-prone, easy to miss functions
❌ **Extract Individual Functions**: Inefficient, misses related functions
❌ **Skip Validation**: Risk of losing functionality
❌ **Ignore Dependencies**: Functions won't compile without proper imports
❌ **Poor Module Organization**: Functions grouped without logical coherence

## Tools Used

- `awk` - Pattern-based extraction
- `grep -c` - Function counting for validation
- `cat` - Merging related functions
- `head`/`tail` - Context inspection
- `wc -l` - Line counting for size validation

This approach ensures large files are systematically broken down while maintaining 100% functionality preservation.