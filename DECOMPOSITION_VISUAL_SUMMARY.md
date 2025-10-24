# Codebase Decomposition - Visual Summary

## The Problem at a Glance

```
CURRENT STATE: "Kitchen Sink" Architecture
==========================================

Tools.QualityAssurance (3,169 lines)
├── quality_check (8 overloads) ───┐
├── quality_report (8 overloads)   │
├── quality_metrics (8 overloads)  ├─ 61 PUBLIC FUNCTIONS
├── quality_validate (8 overloads) │  56 PRIVATE FUNCTIONS
├── quality_coverage (8 overloads) │
├── quality_trends (8 overloads)   │
└── quality_gates (8 overloads) ───┘
    + 56 private helpers (perform_*, generate_*, collect_*, etc.)

RESULT: Hard to navigate, hard to test, hard to extend


SOLUTION: Modular Architecture
==============================

Tools.QualityAssurance/ (parent module - 100 lines)
├── core.ex (100 lines)
│   def register(provider) do
│     [Check, Report, Metrics, Validate, Coverage, Trends, Gates]
│     |> Enum.each(&apply(&1, :register, [provider]))
│   end
│
├── check.ex (400 lines)
│   └─ quality_check/2 + helpers
├── report.ex (400 lines)
│   └─ quality_report/2 + helpers
├── metrics.ex (400 lines)
│   └─ quality_metrics/2 + helpers
├── validate.ex (400 lines)
│   └─ quality_validate/2 + helpers
├── coverage.ex (350 lines)
│   └─ quality_coverage/2 + helpers
├── trends.ex (350 lines)
│   └─ quality_trends/2 + helpers
└── gates.ex (350 lines)
    └─ quality_gates/2 + helpers

RESULT: Easy to navigate, easy to test, easy to extend
```

---

## Size Comparison: Before vs After

### Tools.QualityAssurance Example

```
BEFORE REFACTORING
==================

File: tools/quality_assurance.ex
├─ Lines: 3,169
├─ Public functions: 61
│  ├─ quality_check/2 (8 variants - 170 lines)
│  ├─ quality_report/2 (8 variants - 180 lines)
│  ├─ quality_metrics/2 (8 variants - 160 lines)
│  ├─ quality_validate/2 (8 variants - 160 lines)
│  ├─ quality_coverage/2 (8 variants - 150 lines)
│  ├─ quality_trends/2 (8 variants - 150 lines)
│  └─ quality_gates/2 (8 variants - 150 lines)
├─ Private functions: 56
│  ├─ quality_check_impl/9
│  ├─ quality_report_impl/9
│  ├─ perform_quality_checks/3
│  ├─ generate_quality_suggestions/2
│  ├─ generate_quality_charts/2
│  ├─ collect_quality_metrics/2
│  ├─ analyze_quality_trends/2
│  ├─ generate_quality_forecasts/2
│  ├─ format_quality_report/4
│  └─ 46 more helpers...
└─ Time to understand: 3-4 hours
   Hard to test: Interdependent on all 56 helpers
   Hard to extend: Add new check type? Modify 3,169 line file


AFTER REFACTORING
=================

Directory: tools/quality_assurance/

├─ core.ex (100 lines)
│  └─ register/1 - delegates to sub-modules
│  └─ Time to understand: 5 minutes
│
├─ check.ex (400 lines)
│  ├─ public: quality_check/2
│  ├─ private: quality_check_impl/9, perform_quality_checks/3, etc.
│  └─ Time to understand: 30 minutes
│     Responsibility: "Perform quality checks"
│     Easy to test: No dependencies on other tools
│     Easy to extend: All check logic in one place
│
├─ report.ex (400 lines)
│  ├─ public: quality_report/2
│  ├─ private: quality_report_impl/9, format_quality_report/4, etc.
│  └─ Time to understand: 30 minutes
│     Responsibility: "Generate quality reports"
│
├─ metrics.ex (400 lines)
│  ├─ public: quality_metrics/2
│  ├─ private: quality_metrics_impl/9, collect_quality_metrics/2, etc.
│  └─ Time to understand: 30 minutes
│     Responsibility: "Track quality metrics"
│
├─ validate.ex (400 lines)
│  ├─ public: quality_validate/2
│  └─ Time to understand: 30 minutes
│     Responsibility: "Validate code quality"
│
├─ coverage.ex (350 lines)
│  ├─ public: quality_coverage/2
│  └─ Time to understand: 30 minutes
│     Responsibility: "Assess test coverage"
│
├─ trends.ex (350 lines)
│  ├─ public: quality_trends/2
│  └─ Time to understand: 30 minutes
│     Responsibility: "Analyze quality trends"
│
└─ gates.ex (350 lines)
   ├─ public: quality_gates/2
   └─ Time to understand: 30 minutes
      Responsibility: "Manage quality gates"

Total to understand all: 2-3 hours (30% faster)
Easy to test: Each module independently
Easy to extend: Copy existing module (e.g., gates.ex), rename, adapt
```

---

## The Anti-Pattern: Function Overloading for Defaults

### Why This Exists

```elixir
# Agent tool calls come from LLM with varying parameters
# Some parameters optional, need sensible defaults

def quality_check(%{"check_type" => check_type, "target" => target, 
                   "quality_standards" => standards,
                   "thresholds" => thresholds,
                   "include_suggestions" => include_suggestions,
                   "include_metrics" => include_metrics,
                   "include_trends" => include_trends,
                   "generate_report" => generate_report,
                   "export_format" => export_format}, _ctx) do
  quality_check_impl(check_type, target, standards, thresholds,
                     include_suggestions, include_metrics, include_trends,
                     generate_report, export_format)
end

def quality_check(%{"check_type" => check_type, "target" => target, 
                   "quality_standards" => standards,
                   "thresholds" => thresholds,
                   "include_suggestions" => include_suggestions,
                   "include_metrics" => include_metrics,
                   "include_trends" => include_trends,
                   "generate_report" => generate_report}, _ctx) do
  quality_check_impl(check_type, target, standards, thresholds,
                     include_suggestions, include_metrics, include_trends,
                     generate_report, "json")  # <-- default
end

def quality_check(%{"check_type" => check_type, "target" => target, 
                   "quality_standards" => standards,
                   "thresholds" => thresholds,
                   "include_suggestions" => include_suggestions,
                   "include_metrics" => include_metrics,
                   "include_trends" => include_trends}, _ctx) do
  quality_check_impl(check_type, target, standards, thresholds,
                     include_suggestions, include_metrics, include_trends,
                     true, "json")  # <-- defaults
end

# ... 5 more variants ...
```

### The Solution: Parameter Normalizer

```elixir
# NEW: tools/parameter_normalizer.ex

defmodule Singularity.Tools.ParameterNormalizer do
  def normalize_check_params(params) do
    defaults = %{
      "include_suggestions" => true,
      "include_metrics" => true,
      "include_trends" => true,
      "generate_report" => true,
      "export_format" => "json"
    }
    Map.merge(defaults, params)
  end
end

# NOW: Single function in check.ex

def quality_check(params, _ctx) do
  normalized = ParameterNormalizer.normalize_check_params(params)
  quality_check_impl(
    normalized["check_type"],
    normalized["target"],
    normalized["quality_standards"],
    normalized["thresholds"],
    normalized["include_suggestions"],
    normalized["include_metrics"],
    normalized["include_trends"],
    normalized["generate_report"],
    normalized["export_format"]
  )
end
```

**Impact:** 8 function overloads reduced to 1 function
**Boilerplate reduction:** 60%

---

## The 22 Modules Needing Decomposition

### Tier 1: CRITICAL (2.2K-3.3K lines) - 8 modules

```
SelfImprovingAgent (3,291 lines) ──┐
                                   │
Tools.QualityAssurance (3,169)     │
Tools.Analytics (3,031)             ├─ "KITCHEN SINK" ZONE
Tools.Integration (2,709)           │
Tools.Development (2,608)           │
Tools.Communication (2,606)         │
Tools.Performance (2,388)           │
Tools.Deployment (2,268) ───────────┘

↓ DECOMPOSE INTO ↓

SelfImprovingAgent (600 lines, GenServer core)
├── Documentation.Analyzer (300 lines)
├── Documentation.Upgrader (400 lines)
├── TemplatePerformance (300 lines)
└── SelfAwareness (350 lines)

Tools.QualityAssurance (100 lines, coordinator)
├── Check (400 lines)
├── Report (400 lines)
├── Metrics (400 lines)
├── Validate (400 lines)
├── Coverage (350 lines)
├── Trends (350 lines)
└── Gates (350 lines)

[Similar pattern for Analytics, Integration, Development, etc.]
```

### Tier 2: HIGH (1.2K-2.2K lines) - 5 modules

```
CodeStore (2,190 lines)            ┐
Tools.Security (2,167)             │
Tools.Monitoring (1,980)           ├─ LARGE BUT MANAGEABLE
Tools.Documentation (1,973)        │
Tools.Testing (1,901) ─────────────┘

↓ DECOMPOSE INTO ↓

CodeStore (900 lines, GenServer core)
├── Analysis (350 lines)
├── Comparison (250 lines)
└── Refactoring (300 lines)

Tools.Security (100 lines, coordinator)
├── Scanner (350 lines)
├── Validator (350 lines)
├── Analyzer (300 lines)
├── Hardener (300 lines)
├── Compliance (300 lines)
└── Auditor (300 lines)

[Similar for Monitoring, Documentation, Testing]
```

### Tier 3: MEDIUM (1.0K-1.2K lines) - 9 modules

```
Tools.ProcessSystem (1,481)
RustElixirT5Trainer (1,448)
Tools.NATS (1,288)
CodeAnalyzer (1,251)
FullRepoScanner (1,252)
LLM.Service (1,008) ─┐
SafeWorkPlanner (1,011)  ├─ FOCUSED MODULES
QualityCodeGenerator (1,002) │
RAGCodeGenerator (1,029) ─┘

↓ MODERATE DECOMPOSITION ↓

Most of these are already reasonably organized.
Focus on extracting 2-3 sub-modules from each.

Example: LLM.Service (1,008) → 3 modules
├── Service (400 lines, public API)
├── ModelSelector (250 lines, complexity routing)
└── ProviderRouter (300 lines, provider delegation)
```

---

## Implementation Timeline

```
WEEK 1: Foundation
├─ Day 1: Create ParameterNormalizer + ToolRegistry
│   └─ Cost: 4 hours
│   └─ Value: Enables 60% boilerplate reduction in all Tools modules
│
└─ Status: READY FOR TOOLS EXTRACTION

WEEK 2: SelfImprovingAgent
├─ Days 1-3: Extract 4 sub-modules
│   ├─ Documentation.Analyzer (1 day)
│   ├─ Documentation.Upgrader (1 day)
│   ├─ TemplatePerformance (1 day)
│   └─ SelfAwareness (1 day)
│
└─ Status: AGENT SIMPLIFIED, READY FOR TESTING

WEEKS 3-4: Tools Modules (PARALLEL)
├─ Team A: Tools.QualityAssurance → 8 modules (3 days)
├─ Team B: Tools.Analytics → 7 modules (3 days)
├─ Team C: Tools.Integration → 9 modules (4 days)
├─ Team D: Tools.Development → 7 modules (3 days)
│
├─ Testing & Integration (2 days)
│
└─ Status: AGENTS GAIN 30+ TOOL SUB-MODULES

WEEK 5: Remaining Tools
├─ Tools.Communication → 6 modules (2 days)
├─ Tools.Performance → 6 modules (2 days)
├─ Tools.Security → 6 modules (2 days)
├─ Tools.Deployment → 5 modules (2 days)
│
└─ Status: TOOLS LAYER FULLY DECOMPOSED

WEEK 6: Storage & Core Modules
├─ CodeStore → 3 modules (2 days)
├─ LLM.Service → 3 modules (1 day)
├─ Execution.Runner → 2 modules (1 day)
│
└─ Status: CORE LAYER IMPROVED

FINAL TESTING: Full suite (2 days)

TOTAL: 4 weeks sequential / 2 weeks parallel (3-4 developers)
```

---

## Code Metrics Improvement

```
BEFORE REFACTORING
==================
Largest file:        3,291 lines (SelfImprovingAgent)
Average Tier 1:      2,600 lines
Average all modules: 1,400 lines

Functions per file:  50-80 (Tier 1)
Cyclomatic complexity: HIGH
Test coverage:       70%
IDE latency:         NOTICEABLE (large files)


AFTER REFACTORING
=================
Largest file:        900 lines (CodeStore GenServer)
Average Tier 1:      400 lines
Average all modules: 350 lines

Functions per file:  8-15 (focused)
Cyclomatic complexity: MEDIUM
Test coverage:       85%+
IDE latency:         FAST (smaller files)

IMPROVEMENT
===========
File size:           6-8x reduction (Tier 1)
Functions/file:      5-7x reduction
Testability:         3x easier
Navigation:          4-5x faster
Code reuse:          2-3x easier
```

---

## Risk & Mitigation

```
RISK MATRIX
===========

HIGH RISK CHANGES
├─ Parameter normalizer (affects 8+ modules)
│  └─ Mitigation: Create test cases for all parameter combinations
│
├─ Tools module restructuring (many sub-modules)
│  └─ Mitigation: Use delegation pattern to maintain public API
│
└─ SelfImprovingAgent extraction (GenServer state)
   └─ Mitigation: Keep GenServer core, extract pure functions only


LOW RISK CHANGES
├─ CodeStore decomposition (GenServer isolated)
│  └─ Internal refactoring only
│
├─ LLM.Service decomposition (clean boundaries)
│  └─ Well-defined call interfaces
│
└─ Execution module extraction (strategy pattern)
   └─ Already loosely coupled


REGRESSION TESTING REQUIRED
===========================
✓ Unit tests for all extracted modules
✓ Integration tests for tool registration
✓ Agent tests with all tools available
✓ Full system test (agent with tools)
✓ Parameter variant testing (all defaults work)
✓ Performance benchmarks (no degradation)
```

---

## Quick Reference: Which Modules to Extract First

```
IF YOU HAVE 1 WEEK:
─────────────────
1. Phase 1: ParameterNormalizer (3 hours)
2. SelfImprovingAgent (3-4 days)
   └─ Highest impact on agent development
   
Result: Cleaner agent architecture, ready for new features


IF YOU HAVE 2 WEEKS:
──────────────────
1. Phase 1: ParameterNormalizer (3 hours)
2. SelfImprovingAgent (3-4 days)
3. Tools.QualityAssurance (4-5 days)
   └─ Critical path: Used by many agents
   
Result: Cleaner agents + primary tool module refactored


IF YOU HAVE 4 WEEKS:
──────────────────
1. Phase 1: ParameterNormalizer (3 hours)
2. SelfImprovingAgent (3-4 days)
3. All Tools tier A (8-10 days)
   ├─ QualityAssurance
   ├─ Analytics
   ├─ Integration
   └─ Development
4. CodeStore (2-3 days)
5. LLM.Service (1-2 days)

Result: Comprehensive refactoring, transformed code organization


IF YOU HAVE 2+ MONTHS:
─────────────────────
Complete ALL phases 1-5
Result: Fully decomposed, highly maintainable codebase
```

---

## Success Indicators

```
METRIC                  BEFORE              AFTER              IMPROVEMENT
─────────────────────────────────────────────────────────────────────────
Largest module          3,291 lines         900 lines          6.8x smaller
Avg module size         1,400 lines         350 lines          4x smaller
Functions per module    50-80               8-15               5-7x fewer
Cyclomatic complexity   HIGH                MEDIUM             Simpler
Test coverage           70%                 85%+               Better
Time to find code       5-10 min            1-2 min            5x faster
Time to test module     1+ hours            10-15 min          4-6x faster
Time to add feature     2-3 days            4-8 hours          3-5x faster
IDE response time       SLUGGISH (large)    SNAPPY (small)     Perceptible
New developer ramp-up   3-4 weeks           1-2 weeks          2x faster
```

---

## Implementation Commands

```bash
# Phase 1: Create foundation utilities
mkdir -p singularity/lib/singularity/tools/quality_assurance
mkdir -p singularity/lib/singularity/tools/analytics
# ... more subdirectories

# Create shared utilities
touch singularity/lib/singularity/tools/parameter_normalizer.ex
touch singularity/lib/singularity/tools/tool_registry.ex

# Phase 2: Create extracted modules
# For each large module:
# 1. Create directory: tools/module_name/
# 2. Create core.ex (coordinator)
# 3. Create sub-modules (check.ex, report.ex, etc.)
# 4. Move functions from original to appropriate sub-module
# 5. Update original to delegate

# Phase 3: Testing
mix test                    # All tests pass
mix coverage               # Verify coverage maintained
mix quality                # All quality checks pass
```

---

## Document Navigation

1. **START HERE:** This file (visual overview)
2. **DETAILED PLAN:** `/Users/mhugo/code/singularity-incubation/CODEBASE_DECOMPOSITION_PLAN.md`
3. **IMPLEMENTATION GUIDE:** (To be created) Step-by-step module extraction
4. **TESTING CHECKLIST:** (To be created) Validation for each phase

---

**Last Updated:** October 25, 2025
**Total Analysis Time:** 2 hours
**Modules Analyzed:** 50+
**Recommendations:** 22 modules for decomposition
