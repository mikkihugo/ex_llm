---
name: rust-check
description: Runs Rust code quality checks including clippy linting, format verification, and cargo audit for vulnerabilities. Works on all rust/ crates.
---

# Rust Code Quality Skill

Automatically runs comprehensive Rust quality checks across all NIF engines.

## Scope

This skill runs when you:
- Request quality checks on Rust code
- Need to verify NIF code before compilation
- Want to catch style/performance issues
- Need security vulnerability scanning

## What It Does

```bash
cd rust/{engine_name}
cargo clippy --all-targets --all-features -- -D warnings
cargo fmt -- --check
cargo audit
```

## Output

Reports on:
- **Clippy issues** - Performance, correctness, style
- **Format violations** - Code style issues
- **Security vulnerabilities** - cargo audit findings

## Auto-Fix

For formatting:
```bash
cd rust/{engine_name}
cargo fmt
```

For clippy issues, output includes specific fixes.

## When to Use

- After modifying Rust NIF code
- Before recompiling NIFs
- When verifying error handling patterns
- To ensure consistency with Rustler 0.34+ standards
