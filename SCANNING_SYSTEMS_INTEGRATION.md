# Singularity Scanning Systems & Integration Opportunities

## Executive Summary

Singularity has **multiple, specialized scanning systems** that analyze code for quality, security, and technical debt. A **SecurityScanner** is declared in config but **NOT YET IMPLEMENTED** - this is a key integration point for the linting engine.

---

## 1. TODO/FIXME SCANNING SYSTEM

### Modules
- **`Singularity.Execution.TodoExtractor`** (Primary)
  - Extracts TODO/FIXME comments from code files
  - Stores todos in database with UUID tracking
  - Filters actionable vs non-actionable comments
  
- **`Singularity.Code.Analyzers.TodoDetector`** (Analyzer)
  - Scans codebase for TODO/FIXME patterns
  - Extracts priority and type information
  - Returns structured todo list

- **`Singularity.Execution.TodoPatterns`** (Registry)
  - Centralized configuration for TODO/FIXME patterns
  - Language-specific comment prefixes
  - Priority mapping (FIXME=1 to PLACEHOLDER=15)

### Actionable Markers (Extracted)
```
TODO, FIXME, STUB, HACK, DEBUG, DEAD, UNUSED, DEPRECATED,
REMOVE, WORKAROUND, QUICKFIX, TEMP, TEMPORARY, PLACEHOLDER, NOTE
```

### Non-Actionable Markers (Filtered Out)
```
INFO, DOC, COMMENT, TEST, EXAMPLE, SAMPLE
```

### Database Schema
- **`todos` table**
  - id, title, description, status, priority, complexity
  - file_uuid (tracks original comment location)
  - source: 'code_comment'
  - context: {file_path, line_number, comment_type, extracted_at}
  - Dependencies: assigned_agent_id, parent_todo_id, depends_on_ids

### Flow
```
Code File → TodoExtractor.extract_from_file()
  → AstQualityAnalyzer.find_todo_and_fixme_comments()
  → Filter actionable vs non-actionable
  → TodoStore.create() → Database
```

### Key Feature: UUID Tracking
- Extracts UUID from comment: `# TODO: Fix bug [uuid: 123e4567...]`
- Auto-generates UUID for new todos
- Updates existing todos when content changes
- Prevents duplicate todos from same comment

---

## 2. OTHER SCANNING SYSTEMS

### A. Quality Scanner (Code Quality)
**Module:** `Singularity.CodeAnalysis.Scanners.QualityScanner`
- **Wrapper around:** `Singularity.CodeQuality.AstQualityAnalyzer`
- **Purpose:** Detect code quality issues and violations
- **Interface:** Implements ScanOrchestrator pattern
- **Scans for:**
  - Code smells
  - Anti-patterns
  - Unused code
  - Long functions
  - Complexity violations

**Result Structure:**
```elixir
%{
  issues: [%{category, message, file, line, severity}],
  summary: %{total, by_severity, by_category},
  refactoring_suggestions: [...]
}
```

### B. Security Scanner (Security Vulnerabilities)
**Module:** `Singularity.CodeQuality.AstSecurityScanner`
- **Status:** IMPLEMENTED (not yet wrapped in ScanOrchestrator)
- **Purpose:** Detect security vulnerabilities using AST pattern matching
- **Uses:** ast-grep for precise pattern matching (95%+ accuracy)
- **Languages:** 19+ languages via ast-grep
- **Scans for:**
  - SQL injection patterns
  - Command injection
  - XSS vulnerabilities
  - Insecure cryptography
  - Authentication/authorization flaws

**Result Structure:**
```elixir
%{
  critical: [...],
  high: [...],
  medium: [...],
  low: [...],
  summary: %{total, critical, high, medium, low}
}
```

### C. Full Repo Scanner
**Module:** `Singularity.Code.FullRepoScanner`
- **Purpose:** Multi-language codebase analysis and auto-repair
- **Scans:**
  - Module documentation
  - Component relationships
  - Broken dependencies
  - Missing integrations
  - Isolated modules

### D. AST-Based Quality Analyzer
**Module:** `Singularity.CodeQuality.AstQualityAnalyzer`
- **Functions:**
  - `analyze_codebase_quality/2` - Comprehensive quality report
  - `find_todo_and_fixme_comments/1` - TODO extraction
  - `find_long_functions_needing_refactoring/1` - Function complexity
  - `scan_for_code_smells/1` - Anti-pattern detection

---

## 3. SCANNER CONFIGURATION & ORCHESTRATION

### Config Location
**File:** `/nexus/singularity/config/config.exs`

```elixir
config :singularity, :scanner_types,
  quality: %{
    module: Singularity.CodeAnalysis.Scanners.QualityScanner,
    enabled: true,
    description: "Detect code quality issues and violations"
  },
  security: %{
    module: Singularity.CodeAnalysis.Scanners.SecurityScanner,
    enabled: true,
    description: "Detect code security vulnerabilities"
  }
```

### ScanOrchestrator Pattern
- **Discovery:** Reads `config :singularity, :scanner_types`
- **Interface:** Each scanner implements:
  - `name/0` - Scanner identifier
  - `info/0` - Metadata (name, description, enabled status)
  - `enabled?/0` - Check if active
  - `scan(path, opts)` - Run scan
  - Returns: `{:ok, %{issues, summary}}` or `{:error, reason}`

### Current Scanner Status
| Scanner | Module | Status | Type |
|---------|--------|--------|------|
| Quality | QualityScanner | ✅ IMPLEMENTED | Config-Driven |
| Security | SecurityScanner | ❌ MISSING | Declared only |
| Todos | TodoExtractor | ✅ IMPLEMENTED | Standalone |
| FullRepo | FullRepoScanner | ✅ IMPLEMENTED | Standalone |

---

## 4. DATABASE SCHEMA

### Quality Tracking Tables (Migration: 20250101000018)

#### `quality_runs` Table
```sql
- id (UUID)
- tool (string) - sobelow, mix_audit, dialyzer, custom
- status (string) - ok, warning, error
- warning_count (integer)
- metadata (map) - tool-specific data
- started_at, finished_at (timestamps)
```

**Indexes:**
- tool
- status
- tool + status
- inserted_at
- started_at
- metadata (JSONB)

#### `quality_findings` Table
```sql
- id (UUID)
- run_id (FK → quality_runs)
- category (string)
- message (string)
- file (string)
- line (integer)
- severity (string)
- extra (map) - additional context
```

**Indexes:**
- run_id
- category
- severity
- file
- run_id + severity
- category + severity
- extra (JSONB)
- run_id + category + severity (composite)

### Todo Tracking Tables

#### `todos` Table
```sql
- id (binary_id, UUID)
- title, description
- status (pending, assigned, in_progress, completed, failed, blocked, cancelled)
- priority (1-5: critical → backlog)
- complexity (simple, medium, complex)
- assigned_agent_id (agent executing this todo)
- parent_todo_id (for task hierarchy)
- depends_on_ids (array of blocking todos)
- tags (array)
- context (JSONB) - file_path, line_number, comment_type, extracted_at
- result (JSONB) - execution result
- error_message
- file_uuid (tracks original comment location)
- source (manual, code_comment, ...)
- embedding (pgvector 2560-dim) - semantic search
- estimated_duration_seconds
- actual_duration_seconds
- retry_count, max_retries
- timestamps
```

---

## 5. LINTING ENGINE INTEGRATION OPPORTUNITIES

### Option A: Implement SecurityScanner (RECOMMENDED)
**Goal:** Complete the SecurityScanner stub in config

**Steps:**
1. Create `Singularity.CodeAnalysis.Scanners.SecurityScanner` module
2. Wrap `Singularity.CodeQuality.AstSecurityScanner` (like QualityScanner does)
3. Implement scanner interface:
   - `name/0` → `:security`
   - `info/0` → metadata
   - `enabled?/0` → check config
   - `scan(path, opts)` → delegate to AstSecurityScanner
4. Return standardized result: `{:ok, %{issues, summary}}`

**File to Create:**
```
/nexus/singularity/lib/singularity/code_analysis/scanners/security_scanner.ex
```

**Benefits:**
- Integrates with existing orchestration
- Reuses AstSecurityScanner's 95%+ accuracy
- Follows established pattern
- Zero extra cost

### Option B: Add Linting Scanner
**Goal:** Create unified linting + quality scanning

**New Module:**
```
Singularity.CodeAnalysis.Scanners.LintingScanner
```

**Should Wrap:**
- Language-specific linters (via packages/linting_engine)
- Quality issues
- Security issues
- Style violations

**Config Addition:**
```elixir
linting: %{
  module: Singularity.CodeAnalysis.Scanners.LintingScanner,
  enabled: true,
  description: "Multi-language linting and style analysis"
}
```

### Option C: Enhance Quality Scanner
**Goal:** Consolidate all analysis under quality scanner

**Extend QualityScanner to include:**
- Linting results
- Security findings
- TODO/FIXME comments
- Technical debt metrics

**Result:**
```elixir
%{
  issues: [...],
  linting_issues: [...],
  security_issues: [...],
  todos: [...],
  summary: %{...}
}
```

---

## 6. UNIFIED SCANNING INTERFACE

### ScanOrchestrator Pattern Template

```elixir
defmodule Singularity.CodeAnalysis.Scanners.YourScanner do
  @moduledoc """
  Your scanner description
  """

  @spec name() :: atom()
  def name, do: :your_scanner_name

  @spec info() :: map()
  def info do
    config = Application.get_env(:singularity, :scanner_types, %{})
    scanner_cfg = Map.get(config, name(), %{})
    
    %{
      name: name(),
      description: Map.get(scanner_cfg, :description, "Default description"),
      enabled: Map.get(scanner_cfg, :enabled, true)
    }
  end

  @spec enabled?() :: boolean()
  def enabled? do
    info()[:enabled]
  end

  @spec scan(Path.t(), keyword()) :: {:ok, scan_result()} | {:error, term()}
  def scan(path, opts \\ []) do
    # Your scanning logic
    {:ok, %{
      issues: [...],
      summary: %{total: 0, by_severity: %{}, by_category: %{}}
    }}
  end
end
```

### Calling Scanners

```elixir
# Single scanner
{:ok, results} = QualityScanner.scan("lib/", max_files: 100)

# Multiple scanners (via orchestrator, when fully implemented)
config = Application.get_env(:singularity, :scanner_types, %{})
{:ok, all_results} = 
  config
  |> Enum.filter(fn {_, cfg} -> cfg.enabled end)
  |> Enum.map(&run_scanner/1)
```

---

## 7. INTEGRATION FLOW DIAGRAM

```
Code Changes
    ↓
Auto Ingestion (CodeFileWatcher)
    ↓
TodoExtractor (extracts FIXME/TODO)
    ↓
├─ Database: todos table
├─ Output: TodoDetector results
    ↓
ScanOrchestrator Invocation
    ├─ QualityScanner (AstQualityAnalyzer)
    ├─ SecurityScanner (AstSecurityScanner) [NEEDS IMPLEMENTATION]
    └─ [Future scanners]
    ↓
├─ Database: quality_runs + quality_findings tables
├─ Observer Dashboard (observes results)
└─ Agents (use results for improvements)
```

---

## 8. KEY FILES & LOCATIONS

### Scanner Modules
- Quality: `/nexus/singularity/lib/singularity/code_analysis/scanners/quality_scanner.ex`
- Security: `/nexus/singularity/lib/singularity/code_quality/ast_security_scanner.ex`
- Todos: `/nexus/singularity/lib/singularity/execution/todo_extractor.ex`

### Configuration
- Scanner Types: `/nexus/singularity/config/config.exs` (line ~300)
- Todo Patterns: `/nexus/singularity/lib/singularity/execution/todo_patterns.ex`

### Database Schemas
- Quality Runs: `/nexus/singularity/lib/singularity/schemas/quality/run.ex`
- Quality Findings: `/nexus/singularity/lib/singularity/schemas/quality/finding.ex`
- Todos: `/nexus/singularity/lib/singularity/schemas/execution/todo.ex`

### Migrations
- Quality Tables: `priv/repo/migrations/20250101000018_create_quality_tracking_tables.exs`
- Todo Tables: (embedded in core migrations)

---

## 9. RECOMMENDED NEXT STEPS

### Immediate (High Impact)
1. **Create SecurityScanner wrapper** (Option A)
   - Fixes configuration inconsistency
   - Takes 30 minutes
   - Unblocks security scanning via orchestrator

2. **Implement LintingScanner** (Option B)
   - Bridges linting_engine to orchestrator
   - Unified API for all scanning
   - 1-2 hours

### Short-term (Quality Improvements)
3. Add linting results to quality_findings table
4. Observer dashboard panels for linting issues
5. Agent workflows that act on linting results

### Medium-term (Full Integration)
6. Technical debt scoring (combine all scanners)
7. Automated fix generation for linting issues
8. Cost-optimized scanning (skip expensive checks when unnecessary)

---

## 10. SEARCH KEYWORDS FOR FUTURE REFERENCE

**Scanning Systems:**
- ScanOrchestrator, ScannerType, scanner_types config
- QualityScanner, SecurityScanner, LintingScanner
- AstQualityAnalyzer, AstSecurityScanner, AstGrepCodeSearch

**TODO Tracking:**
- TodoExtractor, TodoDetector, TodoPatterns
- TodoStore, todo_supervisor, todo_swarm_coordinator
- find_todo_and_fixme_comments, TodoPatterns.actionable_patterns

**Database:**
- quality_runs, quality_findings tables
- todos table, file_uuid (comment tracking)
- Indexes: tool, status, category, severity, file

**Integration Points:**
- CodeFileWatcher (triggers extraction)
- Observer (displays results)
- Agents (act on findings)
- SelfImprovingAgent (auto-fixes issues)

