# Self-Awareness and Documentation-First Development Prompt

## Core Principle: Document Before Evolve

**The system MUST fully understand and document its own architecture before making ANY changes, additions, or bug fixes.**

## Pre-Change Analysis Protocol

### 1. **Self-Documentation Requirements**
Before making ANY change, the system MUST:

```
1. Map the existing codebase architecture
2. Identify all related modules and dependencies
3. Document current functionality and patterns
4. Identify potential conflicts or duplications
5. Create a comprehensive understanding of the change impact
```

### 2. **Code Duplication Prevention**
When fixing bugs or adding features:

```
1. Search for existing similar functionality
2. Identify if the "bug" is actually a design pattern
3. Check for orphaned code that might be related
4. Verify if the issue is in the right layer/abstraction
5. Ensure changes don't create new duplications
```

### 3. **Architecture Understanding Checklist**
Before any modification:

- [ ] **What does this module do?** (Primary purpose)
- [ ] **What depends on this module?** (Downstream impact)
- [ ] **What does this module depend on?** (Upstream dependencies)
- [ ] **Are there similar modules?** (Duplication check)
- [ ] **What patterns does this follow?** (Consistency check)
- [ ] **What are the failure modes?** (Error handling)
- [ ] **How is this tested?** (Quality assurance)

### 4. **Change Impact Analysis**
For every change:

```
1. Identify ALL affected modules
2. Map the change propagation path
3. Check for breaking changes
4. Verify backward compatibility
5. Ensure no orphaned code is created
6. Document the change rationale
```

## Self-Evolution Constraints

### **Phase 1: Self-Documentation (MANDATORY)**
- Complete architecture mapping
- Document all module relationships
- Identify existing patterns and conventions
- Map error handling strategies
- Document testing approaches

### **Phase 2: Gap Analysis (MANDATORY)**
- Identify what's missing vs. what's broken
- Distinguish between bugs and missing features
- Check if "problems" are actually design decisions
- Verify if issues are in the right abstraction layer

### **Phase 3: Change Planning (MANDATORY)**
- Create detailed change plan
- Identify all affected components
- Plan for backward compatibility
- Design for no orphaned code
- Plan for comprehensive testing

### **Phase 4: Implementation (ONLY AFTER PHASES 1-3)**
- Implement with full awareness
- Maintain architectural consistency
- Ensure no duplications
- Preserve existing patterns
- Document all changes

## Bug Fix Protocol

### **Step 1: Understand the "Bug"**
```
1. Is this actually a bug or a design decision?
2. What is the expected vs. actual behavior?
3. Why was it implemented this way originally?
4. Are there other modules with similar patterns?
5. What would break if we "fix" it?
```

### **Step 2: Map the System**
```
1. Find ALL modules that might be affected
2. Identify the abstraction layer where the fix belongs
3. Check for existing similar functionality
4. Map the data flow and dependencies
5. Identify potential side effects
```

### **Step 3: Plan the Fix**
```
1. Design the fix at the right abstraction level
2. Ensure it doesn't create orphaned code
3. Plan for backward compatibility
4. Design comprehensive tests
5. Document the change rationale
```

### **Step 4: Implement with Awareness**
```
1. Make changes with full system understanding
2. Maintain architectural consistency
3. Preserve existing patterns
4. Ensure no duplications
5. Document all changes
```

## Code Quality Gates

### **Before Any Change:**
- [ ] System architecture is fully documented
- [ ] All related modules are identified
- [ ] Change impact is mapped
- [ ] No duplications will be created
- [ ] No orphaned code will result
- [ ] Backward compatibility is maintained
- [ ] Testing strategy is defined

### **During Implementation:**
- [ ] Changes follow existing patterns
- [ ] No new duplications are created
- [ ] All affected modules are updated
- [ ] Error handling is consistent
- [ ] Documentation is updated
- [ ] Tests are comprehensive

### **After Implementation:**
- [ ] All changes are documented
- [ ] No orphaned code exists
- [ ] System architecture is still coherent
- [ ] All tests pass
- [ ] Change rationale is clear
- [ ] Future maintainers can understand the change

## Self-Reflection Questions

Before making ANY change, ask:

1. **"Do I fully understand the current system architecture?"**
2. **"Have I identified all related modules and dependencies?"**
3. **"Am I fixing a bug or changing a design decision?"**
4. **"Will this change create orphaned or duplicated code?"**
5. **"Is this the right abstraction layer for the fix?"**
6. **"Have I documented the change rationale?"**
7. **"Can future maintainers understand this change?"**

## Emergency Override

**ONLY in true emergencies** (system down, data loss, security breach):
- Document the emergency
- Implement minimal fix
- Schedule full analysis and proper fix
- Document the technical debt created
- Plan for proper refactoring

## Success Metrics

The system is ready to evolve when:
- [ ] Complete architecture documentation exists
- [ ] All module relationships are mapped
- [ ] Existing patterns are documented
- [ ] Error handling strategies are clear
- [ ] Testing approaches are defined
- [ ] No orphaned code exists
- [ ] No duplications exist
- [ ] All changes are traceable and documented

## Remember

**"A system that doesn't understand itself cannot improve itself without creating chaos."**

**"Documentation is not overhead—it's the foundation of intelligent evolution."**

**"Every change should make the system more coherent, not more complex."**