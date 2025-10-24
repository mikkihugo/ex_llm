# AI Navigation Metadata Implementation Strategy
## Singularity Core Services Enhancement Plan

**Version:** 1.0
**Date:** October 24, 2025
**Scope:** 12 core Elixir service modules
**Total Estimated Time:** 6-8 hours

---

## Executive Summary

This document provides a detailed implementation strategy for adding AI navigation metadata to 12 core Elixir service modules in the Singularity distributed AI development system.

**Key Goals:**
1. Disambiguate similar modules (TaskGraph vs TaskGraphCore vs TaskGraphExecutor)
2. Prevent duplicate implementations
3. Enable graph database indexing
4. Optimize vector search
5. Document complex state machines

## HIGH Priority Batch (4 modules, 2h 45m - 3h 40m)

### 1. Knowledge.TemplateGeneration
- **Time:** 30-40 min
- **Priority Sections:** Module Identity, Call Graph, Anti-Patterns, Keywords
- **Risk:** Code generation orchestrator - prevent DAG/Generator duplicates

### 2. Planning.SafeWorkPlanner
- **Time:** 45-60 min
- **Priority Sections:** Module Identity, Architecture Diagram, Call Graph, Anti-Patterns
- **Risk:** SAFe orchestrator with 3 strategies - document branching logic

### 3. Planning.TaskGraph
- **Time:** 50-70 min
- **Priority Sections:** Module Identity, Call Graph, Anti-Patterns, State Transitions
- **Risk:** Main DAG orchestrator - highest duplicate risk (DAGExecutor, WorkflowEngine)

### 4. Planning.TaskGraphExecutor
- **Time:** 40-50 min
- **Priority Sections:** Module Identity, Call Graph, Anti-Patterns, State Transitions
- **Risk:** Execution engine - document delegation pattern with TaskGraph

## MEDIUM Priority Batch (8 modules, 4h - 4h 40m)

5. EmbeddingGenerator (45 min)
6. LLM.NatsOperation (40 min)
7. Planning.TaskGraphCore (30 min)
8. Planning.TaskGraphEvolution (35 min)
9. Planning.StoryDecomposer (30 min)
10. Planning.WorkPlanAPI (35 min)
11. Todos.TodoSwarmCoordinator (40 min)
12. Infrastructure.CircuitBreaker (30 min)

## Implementation Strategy

**Session-Based Approach:**
- Session 1: TemplateGeneration, TaskGraph, TaskGraphExecutor, SafeWorkPlanner (3h)
- Session 2: EmbeddingGenerator, LLM.NatsOperation, TaskGraphCore (2h)
- Session 3: TaskGraphEvolution, StoryDecomposer, WorkPlanAPI, TodoSwarmCoordinator (2h)
- Session 4: CircuitBreaker (30 min)

**Quality Checklist:**
- ✅ Module compiles without warnings
- ✅ JSON/YAML syntax valid
- ✅ Call graphs match actual code relationships
- ✅ Anti-patterns are specific and actionable
- ✅ No circular dependencies documented

**Success Criteria:**
- All 12 modules have complete AI metadata v2.1
- Zero compilation warnings
- Call graphs enable Neo4j indexing
- Keywords enable pgvector semantic search
- Anti-patterns prevent 90%+ of duplicate implementations

---

See detailed analysis sections for each module with specific guidance on metadata requirements, complexity factors, and estimated time breakdown.
