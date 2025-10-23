# Self-Awareness Implementation Guide

## How to Apply the Self-Awareness Prompt

### **Step 1: Before ANY Change - Run This Checklist**

```bash
# 1. Map the current system
find . -name "*.ex" -o -name "*.ts" -o -name "*.rs" | head -20
grep -r "defmodule\|class\|struct" . | head -20

# 2. Search for similar functionality
grep -r "similar_function_name" .
grep -r "related_pattern" .

# 3. Check for duplications
grep -r "duplicate_code_pattern" .
grep -r "similar_implementation" .

# 4. Map dependencies
grep -r "alias.*Module" .
grep -r "import.*Module" .
```

### **Step 2: Document Current State**

Before making changes, create a brief analysis:

```markdown
## Current System Analysis

### What I'm Changing:
- Module: `ModuleName`
- Function: `function_name`
- Purpose: `What it does`

### Related Modules:
- `Module1` - Does X
- `Module2` - Does Y
- `Module3` - Does Z

### Existing Patterns:
- Pattern A: Used in modules X, Y
- Pattern B: Used in modules Z, W

### Potential Conflicts:
- Similar functionality in `ModuleX`
- Related pattern in `ModuleY`

### Change Impact:
- Direct impact: `Module1`, `Module2`
- Indirect impact: `Module3`, `Module4`
- Breaking changes: None/List them
```

### **Step 3: Verify No Duplications**

```bash
# Search for similar functionality
grep -r "similar_keyword" .
grep -r "related_pattern" .

# Check if "bug" is actually a design decision
grep -r "TODO\|FIXME\|HACK" .
grep -r "temporary\|workaround" .
```

### **Step 4: Plan the Change**

```markdown
## Change Plan

### What I'm Fixing:
- Issue: `Description`
- Root cause: `Analysis`
- Why it exists: `Historical context`

### How I'm Fixing It:
- Approach: `Method`
- Abstraction level: `Where the fix belongs`
- Backward compatibility: `Yes/No and why`

### What I'm NOT Changing:
- `Module1` - Because reason
- `Module2` - Because reason

### Testing Strategy:
- Unit tests: `What to test`
- Integration tests: `What to test`
- Regression tests: `What to test`
```

### **Step 5: Implement with Awareness**

```elixir
# Example: Before making changes, document the context
defmodule MyModule do
  @moduledoc """
  MyModule - Handles X functionality
  
  ## Related Modules:
  - ModuleA: Provides Y
  - ModuleB: Consumes Z
  
  ## Change History:
  - 2024-01-01: Added function_x for reason
  - 2024-01-02: Modified function_y to fix issue
  
  ## Current Issue:
  - Problem: Description
  - Fix: What we're doing
  - Impact: What this affects
  """
  
  # Implementation with full awareness
end
```

## **Practical Examples**

### **Example 1: Fixing a "Bug"**

**Before Change:**
```bash
# 1. Search for similar functionality
grep -r "similar_function" .
grep -r "related_pattern" .

# 2. Check if it's actually a bug
grep -r "TODO\|FIXME" .
grep -r "temporary\|workaround" .

# 3. Map dependencies
grep -r "alias.*MyModule" .
grep -r "import.*MyModule" .
```

**Analysis:**
```markdown
## Bug Analysis

### What I Found:
- Similar functionality in `ModuleX`
- Related pattern in `ModuleY`
- No TODO/FIXME comments
- Used by 3 other modules

### Is This Actually a Bug?
- Expected behavior: X
- Actual behavior: Y
- Why it exists: Historical reason
- Impact of "fix": Could break ModuleA, ModuleB

### Recommendation:
- Fix at abstraction level Z
- Preserve existing patterns
- Maintain backward compatibility
```

### **Example 2: Adding a Feature**

**Before Change:**
```bash
# 1. Search for existing similar features
grep -r "similar_feature" .
grep -r "related_functionality" .

# 2. Check for duplications
grep -r "duplicate_pattern" .
grep -r "similar_implementation" .

# 3. Map the system
grep -r "defmodule.*Related" .
grep -r "alias.*Related" .
```

**Analysis:**
```markdown
## Feature Analysis

### What I'm Adding:
- Feature: X
- Purpose: Y
- Location: ModuleZ

### Existing Similar Features:
- FeatureA in ModuleX - Does similar thing
- FeatureB in ModuleY - Does related thing

### Potential Duplications:
- Pattern1: Used in 3 places
- Pattern2: Used in 2 places

### Recommendation:
- Extend existing Pattern1
- Reuse existing FeatureA
- Avoid creating new duplications
```

## **Common Pitfalls to Avoid**

### **1. Fixing "Bugs" That Are Design Decisions**
```bash
# Check if it's actually a bug
grep -r "TODO\|FIXME" .
grep -r "temporary\|workaround" .
grep -r "by design\|intentional" .
```

### **2. Creating Orphaned Code**
```bash
# Before deleting, check usage
grep -r "function_name" .
grep -r "module_name" .
grep -r "pattern_name" .
```

### **3. Creating Duplications**
```bash
# Search for similar functionality
grep -r "similar_keyword" .
grep -r "related_pattern" .
grep -r "duplicate_code" .
```

### **4. Breaking Existing Patterns**
```bash
# Check existing patterns
grep -r "defmodule.*Pattern" .
grep -r "def.*pattern" .
grep -r "alias.*Pattern" .
```

## **Success Checklist**

Before making ANY change:

- [ ] I understand the current system architecture
- [ ] I've identified all related modules
- [ ] I've checked for existing similar functionality
- [ ] I've verified this isn't a design decision
- [ ] I've mapped the change impact
- [ ] I've planned for backward compatibility
- [ ] I've designed comprehensive tests
- [ ] I've documented the change rationale
- [ ] I've ensured no orphaned code will result
- [ ] I've ensured no duplications will be created

## **Remember**

**"Every change should make the system more coherent, not more complex."**

**"Documentation is not overhead—it's the foundation of intelligent evolution."**

**"A system that doesn't understand itself cannot improve itself without creating chaos."**