# SPARC Workflow (5 Phases)

Standard SPARC methodology with 5 core phases:

## Core Phases (1-5)

1. **Specification** (`1-specification.json`)
   - Analyze requirements
   - Define scope and constraints
   - Generate detailed specification

2. **Pseudocode** (`2-pseudocode.json`)
   - High-level algorithm design
   - Logic flow without syntax
   - Language-agnostic implementation plan

3. **Architecture** (`3-architecture.json`)
   - System design and component interactions
   - Technology stack selection
   - Infrastructure planning
   - **Sub-phases:**
     - `3a-security.json` - Security analysis
     - `3b-performance.json` - Performance optimization

4. **Refinement** (`4-refinement.json`)
   - Analyze feedback
   - Optimize architecture
   - Validate against requirements

5. **Code** (`5-implementation.json`)
   - Generate production code
   - Implement tests
   - Documentation

## Usage

Load phases sequentially:
```elixir
phases = SPARC.Workflow.load_all()
# => [specification, pseudocode, architecture, refinement, implementation]
```

Or load specific phase:
```elixir
arch = SPARC.Workflow.load_phase(3)
# => architecture phase with security + performance sub-phases
```
