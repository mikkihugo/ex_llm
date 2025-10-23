---
name: find-todos
description: Scans entire codebase for TODO/FIXME comments, categorizes by type and priority, identifies patterns, and generates prioritized work lists.
---

# Find & Categorize TODOs Skill

Automatically scans and analyzes technical debt across the entire codebase.

## Scope

This skill runs when you:
- Need to understand technical debt
- Want to identify work priorities
- Need a roadmap for addressing issues
- Ask "what's the top technical debt?"

## What It Does

Searches all code files (.ex, .exs, .rs, .ts, .js) for:
- TODO comments
- FIXME comments
- HACK comments
- NOTE comments with deprecation warnings

For each item, extracts:
- File location
- Line number
- Comment text
- Context (surrounding code)

## Analysis

Categorizes by:
- **Type**: missing_feature, deprecated_pattern, optimization, refactoring, schema, integration, testing, documentation
- **Impact**: blocks_modernization, affects_system_capability, affects_specific_module, nice_to_have
- **Effort**: small (< 1 hour), medium (1-4 hours), large (4+ hours)
- **Priority**: CRITICAL, HIGH, MEDIUM, LOW

Identifies:
- Dependency chains (what blocks what)
- High-leverage items (fixes that unblock most others)
- Quick wins (small items with high impact)

## Output Format

```
CRITICAL (X items) - Start here:
  [effort] Module name - Description

HIGH (X items) - Important:
  ...

MEDIUM (X items) - Nice to have:
  ...

LOW (X items) - Future optimization:
  ...

Total: X items
Estimated effort: X-Y hours
Quick wins: X items (< 1 hour)
Blocking items: X items (critical path)
```

## When to Use

- Quarterly planning
- Sprint planning
- Identifying priorities
- Understanding codebase state
- Communicating technical debt to stakeholders
