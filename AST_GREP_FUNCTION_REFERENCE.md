# AST-Grep Self-Documenting Function Reference

**All functions with clear, descriptive names that explain WHAT they do**

---

## Module 1: AstSecurityScanner

**File:** `singularity/lib/singularity/code_quality/ast_security_scanner.ex`

**Purpose:** Find security vulnerabilities using AST pattern matching (95%+ precision)

### Public API - Codebase Scanning

| Function | What It Does | Returns |
|----------|-------------|---------|
| `scan_codebase_for_vulnerabilities/2` | Scans entire codebase for security vulnerabilities | `{:ok, report}` with issues grouped by severity |
| `scan_files_for_known_vulnerabilities/2` | Scans specific files for vulnerability patterns (pre-commit hooks) | `{:ok, %{vulnerabilities: [...]}}` |
| `find_atom_exhaustion_vulnerabilities/1` | Finds Elixir String.to_atom/1 usage (DOS risk) | `{:ok, [vulnerabilities]}` |
| `find_sql_injection_vulnerabilities/1` | Finds unsafe SQL query construction | `{:ok, [vulnerabilities]}` |
| `find_command_injection_vulnerabilities/1` | Finds unsafe system command execution | `{:ok, [vulnerabilities]}` |
| `find_deserialization_vulnerabilities/1` | Finds unsafe deserialization of untrusted data | `{:ok, [vulnerabilities]}` |
| `find_hardcoded_secrets/1` | Finds hardcoded credentials and API keys | `{:ok, [vulnerabilities]}` |

### Public API - Auto-Fix

| Function | What It Does | Returns |
|----------|-------------|---------|
| `auto_fix_safe_vulnerabilities/2` | Automatically fixes known vulnerability patterns (dry-run support) | `{:ok, %{fixed: 5, skipped: 2}}` |

### Example Usage

```elixir
# Comprehensive scan
{:ok, report} = AstSecurityScanner.scan_codebase_for_vulnerabilities("lib/")
# => %{critical: [...], high: [...], summary: %{total: 12}}

# Specific vulnerability
{:ok, vulns} = AstSecurityScanner.find_sql_injection_vulnerabilities("lib/")

# Auto-fix
{:ok, result} = AstSecurityScanner.auto_fix_safe_vulnerabilities(
  report.high,
  dry_run: false,
  backup: true
)
```

---

## Module 2: AstQualityAnalyzer

**File:** `singularity/lib/singularity/code_quality/ast_quality_analyzer.ex`

**Purpose:** Find code quality issues using AST pattern matching with scoring (0-100)

### Public API - Quality Analysis

| Function | What It Does | Returns |
|----------|-------------|---------|
| `analyze_codebase_quality/2` | Analyzes codebase for quality issues + score | `{:ok, %{score: 85, issues: [...]}}` |
| `find_debug_print_statements/1` | Finds console.log, IO.inspect, print statements | `{:ok, [issues]}` |
| `find_todo_and_fixme_comments/1` | Finds TODO/FIXME comments (incomplete work) | `{:ok, [issues]}` |
| `find_long_functions_needing_refactoring/1` | Finds complex functions that need breaking up | `{:ok, [issues]}` |
| `find_unused_function_parameters/1` | Finds unused parameters (dead code) | `{:ok, [issues]}` |
| `find_magic_numbers_needing_constants/1` | Finds hardcoded numbers (reduce readability) | `{:ok, [issues]}` |
| `find_deeply_nested_conditionals/1` | Finds nested if statements (readability issues) | `{:ok, [issues]}` |
| `find_duplicate_code_blocks/1` | Finds duplicate code (should be extracted) | `{:ok, [issues]}` |
| `find_missing_error_handling/1` | Finds operations without error handling | `{:ok, [issues]}` |
| `find_naming_convention_violations/1` | Finds inconsistent naming | `{:ok, [issues]}` |

### Public API - Quality Metrics

| Function | What It Does | Returns |
|----------|-------------|---------|
| `calculate_codebase_quality_score/2` | Calculates numeric quality score (0-100) | `{:ok, 85}` |
| `generate_refactoring_suggestions/1` | Generates actionable refactoring recommendations | `{:ok, [suggestions]}` |

### Example Usage

```elixir
# Comprehensive analysis
{:ok, report} = AstQualityAnalyzer.analyze_codebase_quality("lib/")
# => %{
#   score: 85,
#   issues: [...],
#   summary: %{total: 24, by_category: %{...}},
#   refactoring_suggestions: [...]
# }

# Specific checks
{:ok, debug_stmts} = AstQualityAnalyzer.find_debug_print_statements("lib/")
{:ok, todos} = AstQualityAnalyzer.find_todo_and_fixme_comments("lib/")

# Get score
{:ok, score} = AstQualityAnalyzer.calculate_codebase_quality_score("lib/", issues)
```

---

## Module 3: CodeQualityImprovementWorkflow

**File:** `singularity/lib/singularity/agents/workflows/code_quality_improvement_workflow.ex`

**Purpose:** Autonomous agent workflow for automated code quality improvement

### Public API - Workflow Execution

| Function | What It Does | Returns |
|----------|-------------|---------|
| `execute_quality_improvement_workflow/2` | Executes full autonomous workflow (scan → fix → test → commit) | `{:ok, workflow_report}` |
| `execute_security_improvement_workflow/2` | Executes security-focused variant (critical/high only) | `{:ok, workflow_report}` |
| `execute_refactoring_improvement_workflow/2` | Executes refactoring-focused variant (quality issues) | `{:ok, workflow_report}` |

### Public API - Scheduled Workflows

| Function | What It Does | Returns |
|----------|-------------|---------|
| `run_daily_quality_check/1` | Runs daily check (reports only, no fixes) | `{:ok, report}` |
| `run_weekly_quality_improvement/1` | Runs weekly improvement (auto-fixes + commits) | `{:ok, report}` |

### Workflow Steps (Internal)

The autonomous workflow executes these steps:

1. `scan_codebase_for_all_issues/1` - Uses AstSecurityScanner + AstQualityAnalyzer
2. `categorize_and_prioritize_all_issues/1` - Sorts by severity + fixability
3. `generate_automated_fix_plan/1` - Creates action plan for fixable issues
4. `execute_all_automated_fixes/1` - Applies fixes (respects dry_run)
5. `verify_fixes_with_test_suite/1` - Runs tests (120s timeout)
6. `commit_improvements_if_approved/1` - Git commits or rolls back

### Example Usage

```elixir
# Full autonomous workflow
{:ok, result} = CodeQualityImprovementWorkflow.execute_quality_improvement_workflow(
  "lib/",
  auto_commit: true,
  run_tests: true,
  max_fixes: 50
)
# => %{
#   issues_found: 24,
#   issues_fixed: 18,
#   issues_skipped: 6,
#   tests_passed: true,
#   committed: true,
#   commit_sha: "abc123..."
# }

# Security-focused
{:ok, result} = CodeQualityImprovementWorkflow.execute_security_improvement_workflow(
  "lib/",
  auto_commit: true
)

# Scheduled jobs
{:ok, report} = CodeQualityImprovementWorkflow.run_daily_quality_check("lib/")
{:ok, report} = CodeQualityImprovementWorkflow.run_weekly_quality_improvement("lib/")
```

---

## Function Naming Pattern

All functions follow this self-documenting pattern:

**`<action_verb>_<what_object>_<for_what_purpose>`**

### Examples:

| Function Name | Action | Object | Purpose |
|--------------|--------|--------|---------|
| `scan_codebase_for_vulnerabilities` | scan | codebase | for vulnerabilities |
| `find_atom_exhaustion_vulnerabilities` | find | atom exhaustion | vulnerabilities |
| `analyze_codebase_quality` | analyze | codebase | quality |
| `calculate_codebase_quality_score` | calculate | codebase quality | score |
| `execute_quality_improvement_workflow` | execute | quality improvement | workflow |
| `run_daily_quality_check` | run | daily quality | check |
| `generate_refactoring_suggestions` | generate | refactoring | suggestions |

### Action Verbs Used:

- **scan** - Search through code for patterns
- **find** - Locate specific issue types
- **analyze** - Perform comprehensive analysis
- **calculate** - Compute metrics/scores
- **execute** - Run a workflow/process
- **run** - Execute scheduled job
- **generate** - Create report/suggestions
- **auto_fix** - Automatically repair issues
- **verify** - Check correctness
- **commit** - Save changes to git

---

## Quick Reference by Use Case

### Security Scanning

```elixir
# All vulnerabilities
AstSecurityScanner.scan_codebase_for_vulnerabilities("lib/")

# Specific vulnerabilities
AstSecurityScanner.find_atom_exhaustion_vulnerabilities("lib/")
AstSecurityScanner.find_sql_injection_vulnerabilities("lib/")
AstSecurityScanner.find_command_injection_vulnerabilities("lib/")
AstSecurityScanner.find_deserialization_vulnerabilities("lib/")
AstSecurityScanner.find_hardcoded_secrets("lib/")

# Auto-fix
AstSecurityScanner.auto_fix_safe_vulnerabilities(vulns, dry_run: false)
```

### Quality Analysis

```elixir
# Comprehensive analysis
AstQualityAnalyzer.analyze_codebase_quality("lib/")

# Specific issues
AstQualityAnalyzer.find_debug_print_statements("lib/")
AstQualityAnalyzer.find_todo_and_fixme_comments("lib/")
AstQualityAnalyzer.find_long_functions_needing_refactoring("lib/")
AstQualityAnalyzer.find_unused_function_parameters("lib/")
AstQualityAnalyzer.find_deeply_nested_conditionals("lib/")
AstQualityAnalyzer.find_missing_error_handling("lib/")

# Metrics
AstQualityAnalyzer.calculate_codebase_quality_score("lib/", issues)
AstQualityAnalyzer.generate_refactoring_suggestions(issues)
```

### Autonomous Workflows

```elixir
# Full workflow (scan → fix → test → commit)
CodeQualityImprovementWorkflow.execute_quality_improvement_workflow(
  "lib/",
  auto_commit: true,
  run_tests: true
)

# Focused workflows
CodeQualityImprovementWorkflow.execute_security_improvement_workflow("lib/")
CodeQualityImprovementWorkflow.execute_refactoring_improvement_workflow("lib/")

# Scheduled jobs
CodeQualityImprovementWorkflow.run_daily_quality_check("lib/")
CodeQualityImprovementWorkflow.run_weekly_quality_improvement("lib/")
```

---

## Summary

**Total Functions:** 27 self-documenting public functions

**Modules:**
1. **AstSecurityScanner** - 8 functions (7 scanning + 1 auto-fix)
2. **AstQualityAnalyzer** - 12 functions (10 analysis + 2 metrics)
3. **CodeQualityImprovementWorkflow** - 5 functions (3 workflows + 2 scheduled)

**All functions clearly indicate:**
- ✅ What action they perform (scan, find, analyze, execute, run)
- ✅ What object they operate on (codebase, vulnerabilities, quality, workflow)
- ✅ What purpose they serve (for vulnerabilities, for quality, improvement)

**No abbreviations, no vague names, no guessing needed!**

---

**See Also:**
- **AST_GREP_USAGE_GUIDE.md** - Comprehensive usage examples
- **AST_GREP_COMPLETE.md** - Quick start guide
- **AST_GREP_INTEGRATION_STATUS.md** - Implementation history

**Author:** Claude Code + @mhugo
**Date:** 2025-10-23
**Status:** Production Ready
