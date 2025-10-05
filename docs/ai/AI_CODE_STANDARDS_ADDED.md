# AI Code Standards Documentation Added

## Summary

Comprehensive code naming conventions and architecture patterns have been added to both `CLAUDE.md` and `AGENTS.md` to guide AI-assisted development.

## What Was Added

### 1. To CLAUDE.md (For Claude Code)

Added complete section: **"Code Naming Conventions & Architecture Patterns"**

**Includes:**
- Self-documenting naming patterns
- Production examples (SemanticCodeSearch, FrameworkPatternStore, etc.)
- Architecture distinctions (Package Registry Knowledge vs RAG)
- Module organization patterns (Store, Search, Collector, Analyzer)
- Field naming conventions
- NATS subject naming patterns
- Documentation requirements (@moduledoc, @doc)
- Anti-patterns to avoid
- Summary guidelines

### 2. To AGENTS.md (For AI Agents)

Added complete section: **"AI Agent Code Standards"**

**Includes:**
- Self-documenting module names with examples
- Critical architecture distinctions table
- Module organization patterns
- Agent code generation rules (5 key rules)
- Anti-patterns for AI agents
- Code quality checklist
- Summary for AI agents

## Key Standards Documented

### 1. Naming Pattern

**Rule**: `<What><WhatItDoes>` or `<What><How>`

**Examples:**
```elixir
✅ SemanticCodeSearch          # What: Code, How: Semantic search
✅ PackageRegistryKnowledge     # What: Package registry, Type: Knowledge
✅ PackageAndCodebaseSearch     # What: Packages AND Codebase, How: Search
✅ PackageRegistryCollector     # What: Package registry, What it does: Collect

❌ ToolKnowledge               # Vague
❌ IntegratedSearch            # Ambiguous
❌ Utils/Helper/Manager        # Generic
```

### 2. Architecture Distinctions

**Critical**: Package Registry Knowledge ≠ RAG

| System | What | How | Purpose |
|--------|------|-----|---------|
| PackageRegistryKnowledge | External packages | Structured queries | "What packages exist?" |
| SemanticCodeSearch | User's codebase | RAG via embeddings | "What did I do?" |
| PackageAndCodebaseSearch | Both combined | Hybrid search | Best of both |

### 3. Module Patterns

**Four main patterns documented:**

1. **Store Modules**: `<What>Store` or `<What>Knowledge`
   - FrameworkPatternStore
   - TechnologyTemplateStore
   - PackageRegistryKnowledge

2. **Search Modules**: `<What>Search` or `<What>And<What>Search`
   - SemanticCodeSearch
   - PackageAndCodebaseSearch

3. **Collector Modules**: `<What>Collector`
   - PackageRegistryCollector

4. **Analyzer Modules**: `<What>Analyzer`
   - ArchitectureAnalyzer
   - RustToolingAnalyzer

### 4. Field Naming

**Rule**: Use full, descriptive names

```elixir
✅ package_name, package_version, ecosystem
❌ pkg_nm, ver, eco
```

### 5. NATS Subject Pattern

**Rule**: `<domain>.<subdomain>.<action>`

```elixir
✅ packages.registry.search
✅ search.packages_and_codebase.unified
❌ tools.search
❌ search.hybrid
```

### 6. Documentation Requirements

**Every module must have:**

1. **@moduledoc** with:
   - What it operates on
   - How it works
   - Why it exists
   - Key differences from similar modules
   - Examples

2. **@doc** for all public functions with:
   - Description
   - Parameters
   - Return value
   - Examples

## Anti-Patterns Documented

**NEVER use:**
- Vague names: `Utils`, `Helper`, `Common`
- Generic terms: `Manager`, `Handler`, `Service`
- Ambiguous prefixes: `Tool*` (without context)
- Abbreviations: `PkgReg`, `TmplMgr`

**ALWAYS use:**
- Descriptive compound names
- Full words, no abbreviations
- Clear indication of What + How

## Code Quality Checklist Added

For AI agents before committing:

- [ ] Module name is self-documenting (`<What><How>`)
- [ ] Has comprehensive `@moduledoc` with examples
- [ ] Public functions have `@doc` with type specs
- [ ] Field names are full words, not abbreviations
- [ ] NATS subjects follow `<domain>.<subdomain>.<action>`
- [ ] Distinguishes PackageRegistryKnowledge from SemanticCodeSearch
- [ ] Follows existing architecture patterns

## Benefits

### For Claude Code (CLAUDE.md)

- Clear guidance when writing/modifying code
- Examples from actual production code
- Comprehensive patterns to follow
- Anti-patterns to avoid

### For AI Agents (AGENTS.md)

- Specific rules for code generation
- Table showing architecture distinctions
- Checklist before committing
- Summary of key principles

### Overall Benefits

1. **Consistency**: All AI-generated code follows same patterns
2. **Self-Documenting**: Names tell the full story
3. **Maintainable**: Easy for humans and AI to understand
4. **Prevents Confusion**: Clear distinction between different systems
5. **Quality**: Built-in standards enforcement

## Example Application

### Before (Vague):
```elixir
defmodule ToolKnowledge do
  def search(query), do: ...
end
```

### After (Self-Documenting):
```elixir
defmodule Singularity.PackageRegistryKnowledge do
  @moduledoc """
  Package Registry Knowledge - Structured package metadata queries (NOT RAG)

  Provides semantic search for external packages (npm, cargo, hex, pypi)
  using structured metadata collected by Rust tool_doc_index collectors.

  ## Key Differences from RAG (SemanticCodeSearch):

  - **Structured Data**: Queryable with versions, dependencies, quality scores
  - **Curated Knowledge**: Official package information from registries
  - **Cross-Ecosystem**: Find equivalents across npm/cargo/hex/pypi

  ## Examples

      iex> PackageRegistryKnowledge.search("async runtime", ecosystem: :cargo)
      [%{package_name: "tokio", version: "1.35.0", similarity: 0.94}]
  """

  @doc """
  Search for packages using semantic similarity.
  """
  def search(query, opts \\ []), do: ...
end
```

## Files Modified

1. **CLAUDE.md**
   - Added "Code Naming Conventions & Architecture Patterns" section
   - ~250 lines of comprehensive guidance

2. **AGENTS.md**
   - Added "AI Agent Code Standards" section
   - ~170 lines of agent-specific rules

3. **AI_CODE_STANDARDS_ADDED.md** (this file)
   - Summary of what was added
   - Quick reference

## Next Steps

**For Developers:**
1. Read the new sections in CLAUDE.md and AGENTS.md
2. Apply patterns to new code
3. Refactor existing code gradually

**For AI Agents:**
1. Always check AGENTS.md before generating code
2. Follow the checklist before committing
3. Use examples as templates

**For Code Reviews:**
1. Verify names follow `<What><How>` pattern
2. Check @moduledoc clarity
3. Ensure no anti-patterns used

## Result

AI-generated code will now be:
- ✅ Self-documenting
- ✅ Consistent with production patterns
- ✅ Clear about architecture distinctions
- ✅ Easy to maintain and understand
- ✅ Following Elixir best practices

**The code tells its own story!** 🚀
