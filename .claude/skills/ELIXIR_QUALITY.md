---
name: elixir-quality
description: Runs Elixir code quality checks including format, credo linting, dialyzer type checking, sobelow security analysis, and dependency audits. Automatically detects issues and provides fixes.
---

# Elixir Quality Check Skill

Automatically runs comprehensive Elixir quality checks and provides actionable fixes.

## Scope

This skill runs when you:
- Request quality checks on Elixir code
- Ask to verify code meets project standards
- Need pre-commit verification
- Want to catch issues before PR creation

## What It Does

```bash
cd singularity
mix quality  # Runs all checks:
  - mix format --check-formatted
  - mix credo --strict
  - mix dialyzer
  - mix sobelow --exit-on-warning
  - mix deps.audit
```

## Output

Reports on:
- **Formatting issues** - Code style violations
- **Lint warnings** - Credo issues
- **Type errors** - Dialyzer findings
- **Security vulnerabilities** - Sobelow alerts
- **Dependency vulnerabilities** - deps.audit issues

## Auto-Fix

For formatting issues, run:
```bash
cd singularity
mix format
```

## When to Use

- After writing Elixir code
- Before committing changes
- When verifying architectural patterns
- To ensure consistency with project standards
