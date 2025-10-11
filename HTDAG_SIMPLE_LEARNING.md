# HTDAG Simple Learning & Auto-Fix Guide

## TL;DR - Quick Start

```elixir
# 1. Learn the codebase (easy way)
{:ok, learning} = HTDAGLearner.learn_codebase()

# 2. Auto-fix everything
{:ok, fixes} = HTDAGLearner.auto_fix_all()

# Done! System is now self-improving and connected.
```

## What This Does

### 1. Simple Learning (No Complex Analysis)

The system learns by:
- **Scanning source files** for modules
- **Reading @moduledoc** to understand what each module does
- **Extracting aliases** to see dependencies
- **Building a knowledge graph** automatically

No need for complex analysis - just reads the docs you already wrote!

### 2. Auto-Fix Everything

Once it learns, it automatically:
- **Identifies broken connections** between modules
- **Finds missing integrations** 
- **Fixes errors** using RAG (finds similar working code)
- **Applies quality standards** using templates
- **Keeps iterating** until everything works

### 3. Hands Over to SafeWorkPlanner

After auto-fix:
- **SafeWorkPlanner** takes over feature management
- **SPARC** handles methodology
- **SelfImprovingAgent** continues fixing errors, performance, etc.

## How It Works

### Phase 1: Learn (The Easy Way)

```elixir
{:ok, learning} = HTDAGLearner.learn_codebase()

# Learning contains:
# - All modules found
# - What each does (from @moduledoc)
# - Dependencies (from aliases)
# - What's broken (missing connections)
```

**Example Output:**
```
Found 127 modules
Issues found:
  - 5 broken dependencies
  - 12 modules without docs
  - 3 isolated modules
```

### Phase 2: Map Everything

```elixir
{:ok, mapping} = HTDAGLearner.map_all_systems()

# Creates comprehensive mapping showing:
# - How SelfImprovingAgent works
# - How SafeWorkPlanner works  
# - How SPARC works
# - How RAG/Quality generators work
# - How they all connect to HTDAG
# - What needs fixing
```

Saves to `HTDAG_SYSTEM_MAPPING.json` for reference.

### Phase 3: Auto-Fix

```elixir
{:ok, fixes} = HTDAGLearner.auto_fix_all()

# Automatically:
# 1. Fixes broken dependencies
# 2. Connects isolated modules
# 3. Generates missing docs
# 4. Tests integrations
# 5. Repeats until done
```

**Example Fix:**
```
Iteration 1: Fixed broken dependency in HTDAGExecutor
Iteration 2: Connected HTDAGEvolution to SelfImprovingAgent  
Iteration 3: Added docs to 5 modules
Done! All high-priority issues fixed.
```

## Complete Example

### Scenario: Fix Singularity Server

```elixir
# Simple one-liner
{:ok, result} = HTDAGBootstrap.fix_singularity_server()

# What happened:
# 1. Scanned all source files
# 2. Found 15 broken things
# 3. Fixed all of them automatically
# 4. Connected everything together
# 5. System is now working!
```

### With Bootstrap

```elixir
# Learn + Map + Fix in one command
{:ok, state} = HTDAGBootstrap.bootstrap(auto_fix: true)

# Result:
state.learning        # What was learned
state.mapping         # How systems connect
state.fixes           # What was fixed
state.ready_for_features  # true - SafeWorkPlanner can take over
```

## What Gets Mapped

The system creates a complete map with explanations:

### SelfImprovingAgent
```elixir
%{
  purpose: "Self-improving agent that evolves through feedback",
  what_it_does: """
  - Observes metrics from task execution
  - Decides when to evolve based on performance
  - Generates new code improvements
  """,
  how_to_use_it: """
  SelfImprovingAgent.improve(agent_id, %{
    mutations: htdag_mutations
  })
  """,
  integration_with_htdag: "Feeds evolution results to HTDAG"
}
```

### SafeWorkPlanner
```elixir
%{
  purpose: "SAFe 6.0 hierarchical work planning",
  what_it_does: """
  - Strategic Themes → Epics → Capabilities → Features
  - HTDAG handles task-level breakdown
  """,
  how_to_use_it: """
  HTDAG.execute_with_nats(dag, safe_planning: true)
  """,
  integration_with_htdag: "HTDAG tasks map to Features"
}
```

### SPARC
```elixir
%{
  purpose: "SPARC methodology orchestration",
  what_it_does: """
  - Specification: Define requirements
  - Pseudocode: High-level algorithm
  - Architecture: System design
  - Refinement: Iterate and improve
  - Completion: Final implementation
  """,
  how_to_use_it: """
  HTDAG.execute_with_nats(dag, integrate_sparc: true)
  """,
  integration_with_htdag: "Applies SPARC phases to tasks"
}
```

### RAG + Quality
```elixir
%{
  purpose: "Generate high-quality code with proven patterns",
  what_it_does: """
  RAG: Finds similar code, uses as examples
  Quality: Enforces docs, specs, tests
  """,
  how_to_use_it: """
  HTDAG.execute_with_nats(dag,
    use_rag: true,
    use_quality_templates: true
  )
  """,
  integration_with_htdag: "Used by executor for code generation"
}
```

## Auto-Fix Process

### What Gets Fixed Automatically

1. **Broken Dependencies**
   - Finds modules that reference non-existent modules
   - Either creates missing module or fixes import
   - Uses RAG to find similar working code

2. **Missing Documentation**
   - Finds modules without @moduledoc
   - Generates docs using LLM based on code
   - Adds inline explanations

3. **Isolated Modules**
   - Finds modules with no dependencies
   - Suggests integrations based on purpose
   - Connects to appropriate systems

4. **Integration Issues**
   - Finds places where systems should connect but don't
   - Generates connection code
   - Tests integration works

### Example Auto-Fix Loop

```
Starting auto-fix...

Iteration 1:
  Issue: HTDAGEvolution not connected to SelfImprovingAgent
  Fix: Added SelfImprovingAgent.improve/2 call after evolution
  Result: Connection established ✓

Iteration 2:
  Issue: HTDAGExecutor missing RAG integration
  Fix: Added Store.search_knowledge/2 call in build_prompt
  Result: RAG examples now included ✓

Iteration 3:
  Issue: Missing docs in HTDAGBootstrap
  Fix: Generated @moduledoc with purpose and examples
  Result: Documentation complete ✓

No high-priority issues remaining.
Auto-fix complete in 3 iterations!
```

## After Auto-Fix

### 1. SafeWorkPlanner Takes Over Features

```elixir
# Create feature in SafeWorkPlanner
feature = %{
  name: "User Authentication",
  description: "JWT-based auth system",
  capability_id: "auth-capability"
}

# HTDAG automatically breaks down into tasks
dag = HTDAG.decompose(%{
  description: feature.description
})

# Execute with all integrations
HTDAG.execute_with_nats(dag,
  safe_planning: true,  # Maps to SafeWorkPlanner
  integrate_sparc: true,  # Uses SPARC phases
  use_rag: true,  # Learns from existing code
  use_quality_templates: true  # Enforces standards
)
```

### 2. SelfImprovingAgent Handles Everything Else

```elixir
# System continuously improves itself
# No manual intervention needed!

# SelfImprovingAgent automatically:
# - Fixes errors as they occur
# - Improves performance when slow
# - Refactors code when complexity increases
# - Updates dependencies when needed
# - Learns from successful patterns
```

## Integration Flow

```
1. HTDAGLearner scans code
   ↓
2. Builds knowledge graph
   ↓
3. Identifies issues
   ↓
4. Auto-fixes everything
   ↓
5. SafeWorkPlanner → Features
   ↓
6. SPARC → Methodology
   ↓
7. HTDAG → Task execution
   ↓
8. RAG + Quality → Code generation
   ↓
9. SelfImprovingAgent → Continuous improvement
```

## When to Use What

### Use HTDAGLearner when:
- You want to understand the codebase quickly
- You need to map all systems
- You want to auto-fix broken things

### Use HTDAGBootstrap when:
- You're setting up the system initially
- You want everything connected automatically
- You want to hand over to SafeWorkPlanner

### Use HTDAG.execute_with_nats when:
- You have specific tasks to execute
- You want all integrations (RAG, Quality, SPARC)
- You want self-evolution enabled

### Let SelfImprovingAgent run continuously for:
- Error fixing
- Performance optimization
- Code quality improvements
- Dependency updates

## Benefits

### Simple Learning
✅ No complex analysis - just reads docs  
✅ Fast - scans files in seconds  
✅ Clear - builds knowledge graph  

### Auto-Fix Everything
✅ No manual intervention needed  
✅ Iterates until everything works  
✅ Uses RAG for proven patterns  
✅ Applies quality standards  

### Hand Over to Existing Systems
✅ SafeWorkPlanner manages features  
✅ SPARC provides methodology  
✅ SelfImprovingAgent handles ongoing improvements  

### Complete Integration
✅ All systems connected automatically  
✅ Inline documentation explains everything  
✅ Self-improving loop always running  

## Summary

The system now:

1. **Learns easily** - Scans source, reads docs, builds graph
2. **Auto-fixes everything** - Broken deps, missing docs, isolated modules
3. **Maps all systems** - Shows how they work, how they connect
4. **Hands over** - SafeWorkPlanner for features, SPARC for methodology
5. **Self-improves continuously** - Errors, performance, quality

All with minimal manual intervention!

```elixir
# That's it - three simple commands:
{:ok, learning} = HTDAGLearner.learn_codebase()
{:ok, mapping} = HTDAGLearner.map_all_systems()
{:ok, fixes} = HTDAGLearner.auto_fix_all()

# Or just one:
{:ok, state} = HTDAGBootstrap.fix_singularity_server()

# System is now self-improving and fully integrated!
```
