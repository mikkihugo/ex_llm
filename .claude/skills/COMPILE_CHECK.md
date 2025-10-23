---
name: compile-check
description: Runs compilation checks for Elixir, Rust, and TypeScript. Detects compilation errors, warnings, and linking issues before attempting to run code.
---

# Compilation Check Skill

Automatically verifies all components compile without errors.

## Scope

This skill runs when you:
- Need to verify code compiles
- Want to catch Rust NIF linking issues
- Need to check TypeScript before running
- Want pre-commit verification

## What It Does

### Elixir Compilation
```bash
cd singularity
mix clean
mix compile 2>&1
```

Checks:
- Elixir syntax errors
- Ecto schema issues
- Module loading errors
- Dependency resolution

### Rust NIF Compilation
```bash
cd rust/{engine_name}
cargo check
cargo build --release
```

Checks:
- Rustler NIF compilation
- Linking against Erlang runtime
- Dependency availability
- Platform-specific issues (Metal, CUDA)

### TypeScript Compilation
```bash
cd llm-server
bunx tsc --noEmit
```

Checks:
- Type errors
- Module resolution
- Implicit any types

## Output

Reports:
- **Errors** - MUST fix before proceeding
- **Warnings** - Should fix to maintain quality
- **Linking issues** - Path problems, missing dependencies

## When to Use

- After modifying any code
- Before committing changes
- When setting up development environment
- When debugging runtime errors
