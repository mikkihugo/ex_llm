# Proposed Claude Agents for Singularity Development

These are specialized Claude AI agents designed to help develop the Singularity project itself,
automating tedious tasks and maintaining code quality at scale.

---

## 🤖 Recommended Agents

### 1. **Technical Debt Analyzer Agent** ⭐⭐⭐ (CRITICAL - Do First)
**Priority:** HIGH | **Complexity:** MEDIUM | **Value:** VERY HIGH

**Purpose:** Systematically address the 976 TODO/FIXME items in the codebase

**What it does:**
- Scans entire codebase for TODO/FIXME comments
- Categorizes items by type:
  - Missing features
  - Deprecated patterns (e.g., Rustler 0.37+)
  - Optimization opportunities
  - Refactoring needed
  - Database schema improvements
  - Integration work
- Builds dependency graph (what blocks what)
- Generates prioritized action lists (CRITICAL → LOW)
- Creates implementation roadmaps
- Tracks completion and marks resolved items
- Suggests parallel vs sequential tasks

**Output example:**
```
CRITICAL (28 items) - Start with these:
  [5] Rust NIF deprecation patterns (blocks modernization)
  [8] BEAM analysis engine implementation (needed by 3 systems)
  [4] GPU availability detection (affects ML operations)
  [11] Agent comprehensive tests

HIGH (142 items) - Medium priority:
  [32] Database schema improvements
  [28] NATS integration gaps
  ...

MEDIUM (287 items) - Nice to have

LOW (519 items) - Future optimization
```

**Why needed:** 976 items is overwhelming. Manual triage would take weeks.

**Interactions:**
- Reads: All .ex, .exs, .rs, .ts files
- Writes: Categorized TODO database, progress tracking
- Publishes: NATS `agent.technical_debt.*` messages

---

### 2. **Documentation Completeness Agent** ⭐⭐⭐ (HIGH - Do Second)
**Priority:** HIGH | **Complexity:** MEDIUM | **Value:** HIGH

**Purpose:** Ensure all critical modules have AI-optimized documentation

**What it does:**
- Scans all Elixir modules for @moduledoc presence
- Checks if @moduledoc includes required AI metadata:
  - Module Identity (JSON)
  - Architecture Diagram (Mermaid)
  - Call Graph (YAML)
  - Anti-Patterns
  - Search Keywords
- Analyzes code to auto-generate missing metadata
- Creates PR with documentation improvements
- Maintains consistency with templates from AI_METADATA_ADDITIONS.md
- Prioritizes critical modules (high coupling, high impact)

**Output example:**
```
Modules with incomplete metadata: 95.6% (98 of 102 critical modules)

Priority 1 - Top 20 critical modules:
  ✅ Singularity.LLM.Service (complete)
  ✅ Singularity.NatsClient (complete)
  ✅ Singularity.Agent (complete)
  ✅ Singularity.Tools.Tool (complete)
  ❌ Singularity.Repo (missing all sections)
  ❌ Singularity.Control (missing diagram, call graph)
  ...

Generate missing metadata? [Y/n]
```

**Why needed:** Only 4 of 20 critical modules have full AI metadata. This scales documentation at billion-line codebase.

**Template usage:** Automatically uses templates from AI_METADATA_ADDITIONS.md

---

### 3. **Unused Variable & Dead Code Fixer Agent** ⭐⭐⭐ (CRITICAL - Do First)
**Priority:** HIGH | **Complexity:** HIGH | **Value:** VERY HIGH

**Purpose:** Find unused variables and either fix them or validate they're truly unused

**What it does:**
- Uses compiler warnings to find unused variables (prefixed with `_`)
- For each unused variable:
  1. **Deep Search:** Searches across entire codebase for actual usage
     - Grep/regex search in all files
     - Check naming variations (snake_case, camelCase, kebab-case)
     - Search in comments, tests, documentation
     - Check git history for recent usage
  2. **Semantic Analysis:** If still not found:
     - Check if it's a valid pattern (e.g., `_ignored` intentionally unused)
     - Check if it's part of a spec/contract that requires it
     - Look for similar patterns in codebase (e.g., pagination, error handling)
  3. **Action Decision:**
     - **IF** found usage elsewhere → Remove the underscore, code is used
     - **IF** recent git history shows it WAS used → Investigate why it stopped being used
     - **IF** looks intentional (e.g., error handler, callback param) → Document why it's ignored
     - **ELSE** → **Generate real code** that uses the variable instead of discarding it
  4. **Code Generation:** When generating real code usage:
     - Analyze what the variable represents
     - Find related code that could use it
     - Generate sensible usages (logging, validation, processing, etc.)
     - Create PR with explanations for all changes

**Example workflow:**
```
Found unused variable: _conn in request_handler.ex:42
  Pattern: _conn = Plug.Conn.assign(conn, :request_id, id)

Searching for usage of conn or request_id...
  Found 12 references to request_id in logs, tracing
  Found 3 references in tests

Action: This IS used indirectly for side effects
  → Generate: logging statement that uses the request_id
  → Generate: telemetry event emission
  → Generate: request timing/metrics

Result:
```

**Another example:**
```
Found unused variable: _embeddings in search.ex:156
  Pattern: {:ok, _embeddings} = EmbeddingEngine.embed(text)

Searching for usage of embeddings...
  Not found elsewhere in code

Checking git history...
  Last used 3 months ago in vector_search function

Analysis: This might be leftover from refactoring where we switched to async processing

Action: Generate real usage
  → Find related code: KnowledgeStore, SemanticSearch modules
  → Generate: Use embeddings for similarity calculation
  → Generate: Cache embeddings for future queries

Result: PR with new code that leverages the embeddings
```

**Key Behavior:** **NEVER remove or disable** unless:
- Absolutely confirmed it's a true false positive
- Explicitly marked as intentional with clear comment
- Verified with user that removal is correct

Otherwise: **Always prefer generating real code** that uses the variable

**Output format:**
```
Unused Variables Analysis Complete

FIXED (code now uses them):
  ✅ request_conn in auth_handler.ex → Added request logging
  ✅ error_details in error_handler.ex → Added error telemetry
  ✅ pagination in query.ex → Added cursor validation

VALIDATED (confirmed intentional):
  ✓ _opts in middleware.ex (line 42) - documented as intentional parameter contract
  ✓ _unused in test helper (line 89) - intentional test fixture

INVESTIGATED (git history checked):
  ⚠ response_metadata (removed 2 months ago) - Generated new usage for response headers

NO CHANGES (truly unused - awaiting confirmation):
  ? experimental_flag in config.ex (line 23) - Recommend removal after user review
```

**Why needed:** Compiler warnings accumulate. Variables marked as unused often represent incomplete refactoring or missed opportunities for better code.

---

### 4. **Test Coverage & Quality Agent** ⭐⭐ (HIGH - Do Third)
**Priority:** HIGH | **Complexity:** MEDIUM | **Value:** HIGH

**Purpose:** Identify untested code and generate comprehensive test scaffolds

**What it does:**
- Analyzes each module for ExUnit test coverage
- Identifies critical untested paths:
  - NIF bindings (Rust integration)
  - Supervision trees and OTP patterns
  - Critical business logic
  - Error handling paths
  - Database operations
- Generates test scaffolds in ExUnit format
- Prioritizes based on module criticality
- Suggests mock/stub patterns for NATS, Repo, Rust NIFs
- Creates test data factories for complex schemas

**Output example:**
```
Test Coverage Analysis

Critical Untested Modules:
1. Singularity.Agent (0% coverage)
   Suggested tests:
   - spawn/2 - agent lifecycle
   - execute_task/3 - task execution
   - feedback/2 - feedback processing
   - evolution/1 - code generation

2. Singularity.Control (0% coverage)
   Suggested tests:
   - event distribution
   - ordering guarantees
   - NATS integration

Generate test scaffolds? [Y/n]
```

---

### 5. **Rust ↔ Elixir Bridge Agent** ⭐⭐ (MEDIUM - Do Fourth)
**Priority:** MEDIUM | **Complexity:** HIGH | **Value:** MEDIUM

**Purpose:** Manage and modernize Rust NIF bindings automatically

**What it does:**
- Monitors Rust source files for changes
- Generates Elixir wrapper modules for Rust NIFs
- Updates error handling when Rust errors change
- Generates type specs (@spec) from Rust function signatures
- Tracks NIF version mismatches between Singularity and CentralCloud
- Applies RUST_NIF_MODERNIZATION.md patterns automatically
- Generates changelog entries when Rust code updates
- Keeps both apps' NIF bindings in sync

**Why needed:** Currently manual bridging. Rust changes require manual Elixir updates.

---

### 6. **Architecture Consistency Agent** ⭐ (MEDIUM)
**Priority:** MEDIUM | **Complexity:** MEDIUM | **Value:** MEDIUM

**Purpose:** Enforce architectural patterns and prevent drift

**What it does:**
- Validates new modules follow naming conventions from CLAUDE.md
- Checks supervision tree structure (layering, restart strategies)
- Detects duplicate functionality across modules
- Suggests consolidation or refactoring
- Validates NATS subject naming conventions
- Ensures anti-patterns from AI metadata are followed
- Checks for proper error handling patterns

**Example detection:**
```
Module violation detected:
- New file: singularity/lib/my_service.ex
- Issue: No supervisor found (all services should be supervised)
- Pattern: Follow Singularity.LLM.Supervisor structure
- Action: Create singularity/lib/my_service/supervisor.ex

Module duplication detected:
- Singularity.CodeSearch and Singularity.SemanticSearch
- 85% code similarity
- Suggestion: Consolidate or clarify distinction
```

---

### 7. **Cross-App Consistency Agent** ⭐ (MEDIUM)
**Priority:** MEDIUM | **Complexity:** MEDIUM | **Value:** MEDIUM

**Purpose:** Keep Singularity and CentralCloud in sync

**What it does:**
- Detects API differences between apps
- Identifies code that should be shared (DRY violations)
- Generates migration guides when APIs change
- Tracks which Rust NIFs are used by which apps
- Alerts when one app adds a feature the other should have

**Example:**
```
API Divergence Detected:
Singularity.EmbeddingEngine.embed/2 added signature change
CentralCloud.EmbeddingEngine still uses old signature
Sync? [Y/n] - Will generate migration
```

---

### 8. **Performance & Profiling Agent** ⭐ (LOWER - Do Later)
**Priority:** MEDIUM | **Complexity:** HIGH | **Value:** MEDIUM

**Purpose:** Identify and propose performance improvements

**What it does:**
- Analyzes critical paths (Agent, NatsClient, LLM.Service)
- Identifies N+1 queries in database code
- Detects blocking operations in async code
- Suggests caching opportunities
- Generates benchmarks for hot paths
- Recommends Rust NIF rewrites for slow functions

---

## 📋 Implementation Priority

### **Phase 1 (Start Immediately - Highest ROI)**
1. ✅ **Technical Debt Analyzer** - Tame 976 TODOs
2. ✅ **Unused Variable Fixer** - Fix compiler warnings, generate real code
3. ✅ **Documentation Completeness** - Complete AI metadata for 20 critical modules

### **Phase 2 (Next - Build Momentum)**
4. **Test Coverage Agent** - Add agent system tests
5. **Rust Bridge Agent** - Reduce NIF maintenance burden

### **Phase 3 (Polish - Optional)**
6. **Architecture Consistency** - Prevent architectural drift
7. **Cross-App Consistency** - Keep apps in sync
8. **Performance Agent** - Optimize hot paths

---

## 🔧 Implementation Notes

Each agent would be:
- **Elixir GenServer** (or Claude Code MCP tool)
- **NATS-based** (publish results via `agent.{type}.*` subjects)
- **Non-destructive** by default (generates PRs, doesn't auto-commit)
- **Verbose** (explains every decision, easy to audit)
- **Idempotent** (safe to run repeatedly)

---

## 🎯 Expected Impact

| Agent | Effort Saved | Bugs Prevented | Code Quality |
|-------|--------------|----------------|--------------|
| Technical Debt Analyzer | 40 hours | 10-20 | ⬆️⬆️⬆️ |
| Unused Variable Fixer | 20 hours | 5-10 | ⬆️⬆️ |
| Documentation Completeness | 30 hours | 0 | ⬆️⬆️⬆️ |
| Test Coverage | 50 hours | 50-100 | ⬆️⬆️⬆️ |
| Rust Bridge | 15 hours | 5-10 | ⬆️ |
| **Total** | **~155 hours** | **~70-150** | **⬆️⬆️⬆️** |

**Total saving:** ~4 weeks of developer time, significantly improved code quality and maintainability.
