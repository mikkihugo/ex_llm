# Duplicate Code Analysis

## Overview

Analysis of duplicate code patterns, naming conflicts, and opportunities for consolidation.

## 🔴 Critical: Duplicate/Ambiguous Names

### 1. Multiple "Coordinator" Modules (5 files!)

**Problem**: Five different coordinators with unclear distinctions

| File | Purpose (Need to clarify) |
|------|---------------------------|
| `agents/execution_coordinator.ex` | Coordinates agent task execution |
| `planning/coordinator.ex` | Coordinates planning tasks |
| `git/coordinator.ex` | Coordinates git operations |
| `git/tree_coordinator.ex` | Coordinates git tree operations |
| `integration/platforms/sparc_coordinator.ex` | Coordinates SPARC methodology |

**Issue**: Generic "Coordinator" name doesn't explain WHAT is being coordinated.

**Suggested Renames**:
```
agents/execution_coordinator.ex → agents/agent_task_coordinator.ex ✓ (already good!)
planning/coordinator.ex → planning/work_plan_coordinator.ex
git/coordinator.ex → git/git_operation_coordinator.ex
git/tree_coordinator.ex → git/git_tree_sync_coordinator.ex
integration/platforms/sparc_coordinator.ex → integration/platforms/sparc_workflow_coordinator.ex
```

### 2. Multiple "Agent" Modules (5 files!)

**Problem**: Five different "agent" concepts

| File | Purpose |
|------|---------|
| `agents/agent.ex` | Self-improving agent loop |
| `agents/hybrid_agent.ex` | Hybrid rule/LLM agent |
| `conversation/agent.ex` | Conversation/chat agent |
| `agents/agent_supervisor.ex` | Agent supervisor |
| `integration/llm_providers/cursor_agent.ex` | Cursor IDE integration |

**Suggested Renames**:
```
agents/agent.ex → agents/self_improving_agent.ex
agents/hybrid_agent.ex → agents/hybrid_rule_llm_agent.ex (or keep as is)
conversation/agent.ex → conversation/chat_conversation_agent.ex
agents/agent_supervisor.ex → agents/agent_lifecycle_supervisor.ex
integration/llm_providers/cursor_agent.ex → integration/llm_providers/cursor_llm_provider.ex
```

### 3. Multiple "Store" Modules (4 files)

**Problem**: Different stores with unclear scopes

| File | What it stores |
|------|----------------|
| `code/storage/code_store.ex` | Code chunks with embeddings |
| `git/store.ex` | Git state/metadata |
| `detection/framework_pattern_store.ex` | Framework detection patterns |
| `detection/technology_template_store.ex` | Technology templates |

**Analysis**:
- ✅ `framework_pattern_store.ex` - GOOD, self-explanatory
- ✅ `technology_template_store.ex` - GOOD, self-explanatory
- ✅ `code_store.ex` - OK (in `/storage` folder provides context)
- ❌ `git/store.ex` - VAGUE

**Suggested Rename**:
```
git/store.ex → git/git_state_store.ex
```

## 🟡 Moderate: Generic/Vague Names

### 4. Redundant Folder + Filename

| File | Issue |
|------|-------|
| `analysis/analysis.ex` | Folder "analysis", file "analysis" |
| `control/control.ex` | Folder "control", file "control" |

**Suggested Renames**:
```
analysis/analysis.ex → analysis/codebase_analysis.ex
control/control.ex → control/distributed_control_system.ex
```

### 5. Generic Tool Names

| File | Issue |
|------|-------|
| `tools/basic.ex` | Basic what? |
| `tools/default.ex` | Default what? |
| `tools/tool.ex` | Just "tool" |

**Analysis**:
```elixir
# tools/basic.ex contains:
- Basic tools (read, write, exec, etc.)

# tools/default.ex contains:
- Default tool registration
- Shell tools (sh_run_command)
- File tools (fs_read_file)

# tools/tool.ex contains:
- Tool struct definition
```

**Suggested Renames**:
```
tools/basic.ex → tools/mcp_basic_tools.ex (MCP protocol basic tools)
tools/default.ex → tools/default_tool_registration.ex
tools/tool.ex → tools/tool_definition.ex
```

### 6. Vague Autonomy Names

| File | Issue |
|------|-------|
| `autonomy/rule.ex` | Just "Rule" struct |
| `autonomy/correlation.ex` | Correlation of what? |
| `control/listener.ex` | Listens to what? |

**Suggested Renames**:
```
autonomy/rule.ex → autonomy/rule_definition.ex
autonomy/correlation.ex → autonomy/metric_correlation_analyzer.ex
control/listener.ex → control/distributed_control_listener.ex
```

## 🟢 Low Priority: Minor Improvements

### 7. Quality Module Names

| File | Improvement |
|------|-------------|
| `quality/finding.ex` | Could be `quality_issue.ex` or `quality_violation.ex` |
| `quality/run.ex` | Could be `quality_check_execution.ex` |

**Suggested Renames**:
```
quality/finding.ex → quality/quality_issue.ex
quality/run.ex → quality/quality_check_execution.ex
```

### 8. LLM Module

| File | Issue |
|------|-------|
| `llm/call.ex` | Generic "call" |

**Suggested Rename**:
```
llm/call.ex → llm/llm_api_request.ex
```

### 9. Package Cache

| File | Issue |
|------|-------|
| `packages/memory_cache.ex` | Memory cache for what? |

**Suggested Rename**:
```
packages/memory_cache.ex → packages/package_metadata_memory_cache.ex
```

### 10. Planning Acronym

| File | Issue |
|------|-------|
| `planning/htdag.ex` | Acronym - not self-explanatory |

**Analysis**: HTDAG = Hierarchical Temporal Directed Acyclic Graph

**Suggested Rename**:
```
planning/htdag.ex → planning/hierarchical_task_dag.ex
```

## 📊 Duplicate Function Analysis

### Common Functions (Potential for Protocol/Behavior)

**execute/1, execute/2** - 10 implementations
- Could these share a common `Executable` protocol?

**get/1, get/2** - 15 implementations
- Different contexts, probably OK

**search/1, search/2, search/3** - 3 implementations:
1. `semantic_code_search.ex`
2. `package_and_codebase_search.ex`
3. `package_registry_knowledge.ex`

**Analysis**: These are different search domains - OK to have separate implementations.

## 🎯 Recommended Actions

### Phase 1: Critical (Naming Conflicts)
1. Rename coordinators to be specific
2. Rename agent modules to clarify purpose
3. Rename `git/store.ex` → `git/git_state_store.ex`

### Phase 2: Moderate (Clarity)
4. Rename redundant folder/file names
5. Rename generic tool names
6. Rename vague autonomy names

### Phase 3: Low Priority (Polish)
7. Rename quality module names
8. Rename LLM call module
9. Rename package cache
10. Expand HTDAG acronym

## 💡 Naming Pattern Guidelines

### ✅ Good Self-Explanatory Names
```
technology_detector.ex          # Detects technologies
framework_pattern_store.ex      # Stores framework patterns
semantic_code_search.ex         # Searches code semantically
package_registry_collector.ex   # Collects from package registries
```

### ❌ Avoid These Patterns
```
agent.ex                        # Agent for what?
coordinator.ex                  # Coordinates what?
store.ex                        # Stores what?
helper.ex                       # Helps with what?
utils.ex                        # What utilities?
```

### 📋 Formula for Self-Explanatory Names

**Pattern**: `<What><Action>` or `<What><Type>`

Examples:
- `<What>Detector` - Detects something
- `<What>Analyzer` - Analyzes something
- `<What>Generator` - Generates something
- `<What>Coordinator` - Coordinates something specific
- `<What>Store` - Stores something specific
- `<What>Cache` - Caches something specific

## 🔍 No Actual Code Duplication Found!

**Good News**: While we have naming duplicates, the analysis shows:
- ✅ No duplicate code implementations
- ✅ Each "coordinator" has distinct responsibilities
- ✅ Each "agent" serves different purposes
- ✅ Each "store" manages different data

**The issue is purely naming** - the names don't clarify the differences!

## Summary

- **19 files** need renaming for clarity
- **0 files** have actual duplicate code
- **5 coordinators** need specific names
- **5 agents** need specific names
- **4 stores** - 3 are good, 1 needs rename

**Priority**: Focus on renaming coordinators and agents first, as these cause the most confusion.
