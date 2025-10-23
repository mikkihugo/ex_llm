---
name: typescript-check
description: Runs TypeScript type checking, formatting checks, and linting on llm-server. Detects type errors, implicit any types, and style violations.
---

# TypeScript Code Quality Skill

Automatically runs comprehensive TypeScript quality checks on llm-server.

## Scope

This skill runs when you:
- Request type checking on TypeScript code
- Need to verify AI SDK v5 patterns
- Want to ensure strict type safety
- Need to validate NATS messaging code

## What It Does

```bash
cd llm-server
bunx tsc --noEmit              # Type checking without emission
bun run format:check           # Format verification
bunx eslint src/ --max-warnings 0  # Linting
```

## Output

Reports on:
- **Type errors** - TS compilation errors
- **Implicit any** - Variables without type annotations
- **Format violations** - Code style issues
- **Lint warnings** - ESLint findings

## Auto-Fix

For formatting:
```bash
cd llm-server
bun run format
```

For type errors, output includes specific fixes with examples.

## When to Use

- After modifying llm-server TypeScript
- Before deploying changes
- When implementing new AI provider integrations
- To ensure compliance with AI SDK v5 patterns
