# Codebase Audit Prompt - Find & Fix Non-Compliant Files

## Prompt for LLM to Audit Codebase Compliance

```
You are a code quality auditor. Your task is to find files that don't follow our coding guidelines and fix them.

## Step 1: Understand Guidelines

Read these files to understand our standards:

1. **Code Organization**:
   - `CODEBASE_ORGANIZATION_COMPLETE.md` - Folder structure rules
   - `FILENAME_RENAMES_COMPLETED.md` - Naming conventions
   - `INTERFACE_ARCHITECTURE.md` - Interface pattern

2. **Code Quality**:
   - `priv/code_quality_templates/elixir_production.json` - Elixir standards
   - `DUPLICATE_CODE_ANALYSIS.md` - Anti-patterns
   - `CLAUDE.md` - Naming conventions

3. **Architecture**:
   - `DB_SERVICE_REMOVAL.md` - Database access pattern
   - `NATS_SUBJECTS.md` - NATS usage (not for DB)
   - `SEMANTIC_PATTERNS_IMPROVEMENTS.md` - Pattern library

## Step 2: Audit Checklist

For EACH Elixir file in `lib/singularity/`, check:

### A. Documentation Compliance (elixir_production.json)

```elixir
// Check these requirements:
✅ Has @moduledoc (min 100 chars)
✅ @moduledoc includes: overview, examples, usage
✅ Has @doc for ALL public functions (min 50 chars)
✅ @doc includes: description, parameters, return value, examples
✅ Has @spec for ALL functions (public AND private)
✅ @spec uses precise types (String.t(), integer(), map())
✅ Custom types defined with @type if needed

// Violations to flag:
❌ Missing @moduledoc
❌ Missing @doc on public functions
❌ Missing @spec on any function
❌ @moduledoc < 100 chars
❌ @doc < 50 chars
❌ No examples in @moduledoc
```

### B. Naming Compliance

```elixir
// Check filename follows pattern:
✅ <What><Action>.ex or <What><Type>.ex
✅ Self-explanatory (no generic names like "helper.ex", "utils.ex")
✅ No redundant folder+filename (not "code/code.ex")
✅ No generic coordinator/agent/store without specifics

// Violations to flag:
❌ Generic names: helper.ex, utils.ex, manager.ex
❌ Redundant: analysis/analysis.ex, control/control.ex
❌ Ambiguous: coordinator.ex, agent.ex, store.ex (need specifics)
```

### C. Code Quality (elixir_production.json)

```elixir
// Check code patterns:
✅ Uses {:ok, result} | {:error, reason} pattern
✅ No raise/throw in production code paths
✅ Functions under 30 lines
✅ Guard clauses for validation
✅ Pattern matching preferred over if/case
✅ Descriptive variable names (no x, y, z)

// Violations to flag:
❌ Contains TODO, FIXME, XXX, HACK
❌ Functions > 30 lines
❌ raise/throw in non-error paths
❌ Single-letter variables (except in pipes/comprehensions)
❌ No error handling
```

### D. Architecture Compliance

```elixir
// Check architecture pattern:
✅ Domain folder structure (code/, agents/, etc.)
✅ Functional subfolders (analyzers/, generators/, storage/)
✅ NOT using Phoenix contexts (unless it's a web app)
✅ Direct Ecto access (no NATS for database)
✅ Interfaces used correctly (MCP/NATS, not HTTP API)

// Violations to flag:
❌ Phoenix context pattern in library code
❌ NATS.publish("db.*") - should use Ecto directly
❌ HTTP API for tools (should use interface protocol)
❌ Wrong folder (code in wrong domain)
```

### E. Anti-Pattern Detection

```elixir
// Check for deprecated patterns:
❌ db_service usage (deprecated - use Ecto)
❌ NATS for database operations (use Ecto)
❌ HTTP REST API for tools (use MCP/NATS interfaces)
❌ Phoenix contexts in non-web library
❌ Old module names (Git.Coordinator vs GitOperationCoordinator)

// Check for code smells:
❌ God modules (> 500 lines)
❌ Deeply nested code (> 4 levels)
❌ Long parameter lists (> 4 params)
❌ Duplicate code (check DUPLICATE_CODE_ANALYSIS.md)
```

## Step 3: Scan Process

```bash
# For each file in lib/singularity/**/*.ex:

1. Read file
2. Run all checks A-E above
3. Record violations
4. Generate fix recommendations
```

## Step 4: Report Format

```markdown
# Codebase Audit Report

## Summary
- Total files scanned: X
- Files with violations: Y
- Total violations: Z
- Compliance score: (X-Y)/X * 100%

## Critical Violations (Fix First)

### File: lib/singularity/foo/bar.ex
**Violations:**
- ❌ Missing @moduledoc
- ❌ Missing @spec on function `process/2`
- ❌ Contains TODO on line 45
- ❌ Function `long_function/1` is 67 lines (max 30)

**Recommended Fixes:**
1. Add @moduledoc with overview and examples
2. Add @spec process(term(), keyword()) :: {:ok, result()} | {:error, atom()}
3. Remove TODO, implement or create issue
4. Refactor long_function into smaller functions

**Auto-fix commands:**
```bash
# Run quality generator
mix quality.fix lib/singularity/foo/bar.ex
```

## Moderate Violations

[...]

## Low Priority

[...]

## Compliance by Category

| Category | Files OK | Files with Issues | Compliance % |
|----------|----------|-------------------|--------------|
| Documentation | 45 | 12 | 79% |
| Naming | 55 | 2 | 96% |
| Code Quality | 40 | 17 | 70% |
| Architecture | 57 | 0 | 100% |
| Anti-patterns | 56 | 1 | 98% |

## Top 10 Most Violated Rules

1. Missing @doc (12 files)
2. Missing @spec (10 files)
3. Functions > 30 lines (8 files)
4. Contains TODO (7 files)
5. [...]

## Recommended Actions

1. **High Priority** (Fix this week):
   - Add missing @moduledoc to 12 files
   - Add missing @spec to 10 files

2. **Medium Priority** (Fix this month):
   - Refactor 8 long functions
   - Remove 7 TODOs

3. **Low Priority** (Fix eventually):
   - Improve variable names in 3 files

## Auto-Fix Available

These files can be auto-fixed:
- lib/singularity/foo/bar.ex - Run: mix quality.fix
- lib/singularity/baz/qux.ex - Run: mix quality.add_docs
```

## Step 5: Auto-Fix Script

```bash
#!/bin/bash
# auto_fix_violations.sh

echo "🔧 Auto-fixing codebase violations..."

# Fix missing @moduledoc
for file in $(grep -l "^defmodule" lib/singularity/**/*.ex | xargs grep -L "@moduledoc"); do
  echo "Adding @moduledoc to $file"
  mix quality.add_moduledoc "$file"
done

# Fix missing @spec
for file in lib/singularity/**/*.ex; do
  mix quality.add_specs "$file"
done

# Remove TODOs
for file in $(grep -l "TODO\|FIXME\|XXX" lib/singularity/**/*.ex); do
  echo "Found TODOs in $file - manual review needed"
done

# Run formatter
mix format

echo "✅ Auto-fix complete. Review changes before committing."
```

## Step 6: Continuous Compliance

Add to CI/CD:

```yaml
# .github/workflows/compliance.yml
name: Code Compliance Check

on: [pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run compliance audit
        run: |
          mix quality.audit --fail-on-violations

      - name: Check documentation
        run: |
          mix quality.check_docs --min-coverage 90

      - name: Check naming
        run: |
          mix quality.check_names --pattern "<What><Action>"

      - name: Check architecture
        run: |
          mix quality.check_architecture --no-contexts-in-lib
```
```

---

## Enhanced Version: AI-Powered Audit

### Improved Prompt with Context

```
# CODEBASE COMPLIANCE AUDIT - AI-Powered Analysis

## Your Role
You are an expert Elixir code auditor with deep knowledge of:
- Production Elixir standards (from elixir_production.json)
- Singularity architecture patterns
- Domain-driven design
- Interface abstraction patterns

## Input Context

You will be given:
1. File path: lib/singularity/path/to/file.ex
2. File contents
3. Related files (imports, dependencies)
4. Architecture context (web app vs library)

## Guidelines Reference

Before auditing, you have reviewed:
- `elixir_production.json` - Quality standards
- `CODEBASE_ORGANIZATION_COMPLETE.md` - Structure rules
- `SEMANTIC_PATTERNS_IMPROVEMENTS.md` - Pattern library
- `DUPLICATE_CODE_ANALYSIS.md` - Anti-patterns

## Audit Process

### Phase 1: Context Detection (2 min)

```elixir
# Automatically detect:
architecture_type = detect_architecture()
  # -> :phoenix_web | :library | :umbrella

domain = detect_domain(file_path)
  # -> :code | :agents | :detection | :search

expected_patterns = lookup_patterns(architecture_type, domain)
  # -> [pattern1, pattern2, ...]

anti_patterns = lookup_anti_patterns(architecture_type)
  # -> [anti1, anti2, ...]
```

### Phase 2: Multi-Level Analysis (5 min)

```elixir
# Level 1: Syntax & Documentation
check_documentation()
  |> check_specs()
  |> check_types()
  |> check_examples()

# Level 2: Code Quality
check_function_length()
  |> check_complexity()
  |> check_error_handling()
  |> check_naming()

# Level 3: Architecture
check_folder_structure()
  |> check_pattern_compliance()
  |> check_interface_usage()
  |> check_database_access()

# Level 4: Semantic Patterns
extract_pseudocode()
  |> match_against_known_patterns()
  |> detect_anti_patterns()
  |> calculate_quality_score()

# Level 5: Cross-File Analysis
check_dependencies()
  |> check_circular_deps()
  |> check_interface_contracts()
  |> check_consistency()
```

### Phase 3: Violation Scoring (1 min)

```elixir
# Calculate violation severity:
violations
|> Enum.map(fn v ->
  %{
    type: v.type,
    severity: calculate_severity(v),
    fix_effort: estimate_fix_time(v),
    auto_fixable: can_auto_fix?(v)
  }
end)
|> sort_by_priority()

# Severity levels:
# - CRITICAL: Breaks compilation, security issue
# - HIGH: Production quality requirement
# - MEDIUM: Best practice violation
# - LOW: Style/consistency issue
```

### Phase 4: Fix Generation (2 min)

```elixir
# For each violation, generate:
1. Explanation (why it's wrong)
2. Fix recommendation (what to do)
3. Code diff (specific changes)
4. Auto-fix command (if available)

# Example output:
%{
  violation: "Missing @moduledoc",
  severity: :high,
  line: 1,

  explanation: """
  Production Elixir requires @moduledoc on all modules (min 100 chars).
  Must include: overview, examples, usage.
  See: elixir_production.json line 8
  """,

  fix: """
  Add @moduledoc after defmodule statement:

  @moduledoc \"\"\"
  [Brief description of what this module does]

  ## Examples

      iex> ModuleName.function()
      {:ok, result}

  ## Usage

  [Common usage patterns]
  \"\"\"
  """,

  diff: "+  @moduledoc \"\"\"...",

  auto_fix: "mix quality.add_moduledoc lib/path/file.ex"
}
```

## Output Format: Detailed Report

```json
{
  "summary": {
    "file": "lib/singularity/code/analyzers/architecture_analyzer.ex",
    "scanned_at": "2025-10-05T18:00:00Z",
    "architecture_type": "library",
    "domain": "code",
    "total_violations": 5,
    "critical": 0,
    "high": 2,
    "medium": 2,
    "low": 1,
    "compliance_score": 0.73,
    "auto_fixable": 3
  },

  "violations": [
    {
      "id": "DOC001",
      "type": "missing_moduledoc",
      "severity": "high",
      "line": 1,
      "message": "Missing @moduledoc (required min 100 chars)",
      "explanation": "All production modules must have @moduledoc with overview, examples, usage",
      "guideline": "elixir_production.json:8-23",
      "fix": {
        "description": "Add @moduledoc after defmodule",
        "code": "@moduledoc \"\"\"...",
        "auto_fix": "mix quality.add_moduledoc lib/singularity/code/analyzers/architecture_analyzer.ex"
      },
      "fix_effort_minutes": 10,
      "priority": 1
    },

    {
      "id": "SPEC002",
      "type": "missing_spec",
      "severity": "high",
      "line": 42,
      "function": "analyze/2",
      "message": "Missing @spec for public function analyze/2",
      "explanation": "All functions require @spec type annotations",
      "guideline": "elixir_production.json:25-30",
      "fix": {
        "description": "Add @spec before function definition",
        "code": "@spec analyze(String.t(), keyword()) :: {:ok, map()} | {:error, atom()}",
        "auto_fix": "mix quality.add_spec lib/singularity/code/analyzers/architecture_analyzer.ex:42"
      },
      "fix_effort_minutes": 5,
      "priority": 2
    },

    {
      "id": "QUAL003",
      "type": "long_function",
      "severity": "medium",
      "line": 67,
      "function": "extract_dependencies/1",
      "message": "Function is 45 lines (max 30)",
      "explanation": "Functions should be under 30 lines for maintainability",
      "guideline": "elixir_production.json:56",
      "fix": {
        "description": "Refactor into smaller functions",
        "suggestions": [
          "Extract file parsing logic to parse_dependency_file/1",
          "Extract validation to validate_dependencies/1",
          "Keep main function as orchestrator"
        ],
        "auto_fix": null
      },
      "fix_effort_minutes": 30,
      "priority": 4
    }
  ],

  "patterns_detected": [
    {
      "pattern": "architecture_analysis",
      "confidence": 0.85,
      "pseudocode": "analyze(path) → parse files → extract modules → detect patterns → {:ok, analysis}",
      "matches_guideline": "semantic_patterns.architectural_analysis"
    }
  ],

  "anti_patterns_detected": [],

  "quality_metrics": {
    "documentation_coverage": 0.60,
    "spec_coverage": 0.75,
    "avg_function_length": 18,
    "cyclomatic_complexity": 4,
    "overall_quality": 0.73
  },

  "recommended_actions": [
    {
      "priority": "high",
      "action": "Add @moduledoc",
      "command": "mix quality.add_moduledoc lib/singularity/code/analyzers/architecture_analyzer.ex",
      "effort_minutes": 10
    },
    {
      "priority": "high",
      "action": "Add missing @spec annotations",
      "command": "mix quality.add_specs lib/singularity/code/analyzers/architecture_analyzer.ex",
      "effort_minutes": 15
    }
  ],

  "auto_fix_script": "#!/bin/bash\nmix quality.add_moduledoc lib/singularity/code/analyzers/architecture_analyzer.ex\nmix quality.add_specs lib/singularity/code/analyzers/architecture_analyzer.ex\nmix format lib/singularity/code/analyzers/architecture_analyzer.ex"
}
```

## Execution

To run this audit:

```bash
# Audit single file
mix audit.file lib/singularity/code/analyzers/architecture_analyzer.ex

# Audit entire codebase
mix audit.codebase --output report.json

# Auto-fix violations
mix audit.fix --auto-fixable-only

# Check compliance score
mix audit.score --min 0.90
```

## Improvements Over Basic Prompt

1. ✅ **Context-aware** - Detects architecture type automatically
2. ✅ **Multi-level analysis** - 5 levels of checking
3. ✅ **Semantic pattern matching** - Uses pseudocode vectors
4. ✅ **Violation scoring** - Prioritized fix list
5. ✅ **Auto-fix generation** - Provides exact commands
6. ✅ **JSON output** - Machine-readable for CI/CD
7. ✅ **Effort estimation** - Time to fix each violation
8. ✅ **Cross-file analysis** - Checks dependencies
9. ✅ **Quality metrics** - Overall score + breakdown
10. ✅ **Anti-pattern detection** - Uses our anti-patterns list

This enhanced prompt provides **10x more value** than basic checklist!
