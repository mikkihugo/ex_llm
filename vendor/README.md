# Vendor Directory

This directory contains forks of external projects that require custom modifications.

## codex/

Fork of [openai/codex](https://github.com/openai/codex) with custom modifications for Singularity.

### Setup

```bash
cd vendor/codex
git remote -v
# origin: mikkihugo/codex (our fork)
# upstream: openai/codex (official repo)
```

### Sync with upstream

```bash
# Using Moon
moon run codex:sync

# Or manually
cd vendor/codex
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

### Current modifications

**Branch:** `feat/builtin-tool-filtering`

**Feature:** Add `exclude_builtin_tools` and `include_builtin_tools` config options

This allows disabling Codex's built-in tools (shell, read_file, write_file, etc.) to only use MCP-provided tools from Elixir orchestrator.

**Why:** Singularity has RAG-enabled code generation in Elixir. Codex's built-in file/shell tools bypass this system and don't have access to knowledge base, quality standards, or templates.

### Upstream PR

Once tested and working, we'll submit PR to openai/codex.

**Related Issues:**
- [#2963](https://github.com/openai/codex/issues/2963) - MCP tool filtering (implemented pattern we're following)

## Development Workflow (Moon Tasks)

```bash
# Check implementation status
moon run codex:status

# Run tests
moon run codex:test
moon run codex:test-filtering  # Just builtin tool filtering tests

# Format and lint
moon run codex:format
moon run codex:lint

# Build
moon run codex:build

# Prepare for PR (cleans fork-specific files, runs quality checks)
moon run codex:prepare-pr

# Push to fork
moon run codex:push

# Create PR to upstream
moon run codex:create-pr

# Install locally for testing
moon run codex:install

# Sync with upstream
moon run codex:sync
```
