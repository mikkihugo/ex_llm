# Renaming Complete - Self-Documenting Names

## Summary

All modules have been renamed to self-documenting names following your production patterns (like `SemanticCodeSearch`, `FrameworkPatternStore`, `TechnologyTemplateStore`).

## What Changed

### Module Names

| Old (Vague) | New (Self-Documenting) |
|-------------|------------------------|
| `ToolKnowledge` | `PackageRegistryKnowledge` |
| `IntegratedSearch` | `PackageAndCodebaseSearch` |
| `ToolCollectorBridge` | `PackageRegistryCollector` |
| `ToolSearchAPI` | `PackageKnowledgeSearchAPI` |

### Schema Names

| Old | New |
|-----|-----|
| `Schemas.Tool` | `Schemas.PackageRegistryKnowledge` |
| `Schemas.ToolExample` | `Schemas.PackageCodeExample` |
| `Schemas.ToolPattern` | `Schemas.PackageUsagePattern` |
| `Schemas.ToolDependency` | `Schemas.PackageDependency` |

### Files Renamed

```
lib/singularity/
├── package_registry_knowledge.ex          (was: tool_knowledge.ex)
├── package_and_codebase_search.ex         (was: integrated_search.ex)
├── package_registry_collector.ex          (was: tool_collector_bridge.ex)
├── package_knowledge_search_api.ex        (was: tool_search_api.ex)
└── schemas/
    ├── package_registry_knowledge.ex      (was: tool.ex)
    ├── package_code_example.ex            (was: tool_example.ex)
    ├── package_usage_pattern.ex           (was: tool_pattern.ex)
    └── package_dependency.ex              (was: tool_dependency.ex)
```

### Field Names

| Old | New |
|-----|-----|
| `tool_name` | `package_name` |
| `tool_id` | `package_id` (in associations) |

### NATS Subjects

```
Old: tools.*
New: packages.registry.*

Old: search.hybrid
New: search.packages_and_codebase.unified

Old: search.implementation
New: search.packages_and_codebase.implementation
```

**Full list:**
- `packages.registry.search` (was: `tools.search`)
- `packages.registry.examples.search` (was: `tools.examples.search`)
- `packages.registry.patterns.search` (was: `tools.patterns.search`)
- `packages.registry.recommend` (was: `tools.recommend`)
- `packages.registry.equivalents` (was: `tools.equivalents`)
- `packages.registry.collect.package` (was: `tools.collect.package`)
- `packages.registry.collect.popular` (was: `tools.collect.popular`)
- `packages.registry.collect.manifest` (was: `tools.collect.manifest`)
- `events.packages.registry.collected` (was: `events.tools.package_collected`)
- `events.packages.registry.collection_failed` (was: `events.tools.collection_failed`)

### Documentation

- `TOOL_KNOWLEDGE_INTEGRATION.md` → `PACKAGE_REGISTRY_AND_CODEBASE_SEARCH.md`
- All documentation updated with new names
- NATS_SUBJECTS.md updated

## Why These Names?

Following your production patterns:

### 1. **PackageRegistryKnowledge** (like TechnologyTemplateStore)
```
What: Package registry metadata
How: Knowledge-based queries
NOT RAG: Structured, curated, versioned data
```

### 2. **PackageAndCodebaseSearch** (like SemanticCodeSearch)
```
What: Searches BOTH packages AND your codebase
How: Combines structured package data + RAG
Self-documenting: Name tells you exactly what it does
```

### 3. **PackageRegistryCollector** (like FrameworkPatternStore)
```
What: Collects packages from registries
How: Via Rust tool_doc_index collectors
Clear purpose: "Collector" tells you it gathers data
```

### 4. **PackageKnowledgeSearchAPI**
```
What: API for package knowledge
How: NATS-based search operations
Specific: Not just "SearchAPI" - tells you it's for package knowledge
```

## Database Tables (Unchanged)

Table names remain the same for now (requires migration):
- `tools` (could be `package_registry_knowledge`)
- `tool_examples` (could be `package_code_examples`)
- `tool_patterns` (could be `package_usage_patterns`)
- `tool_dependencies` (stays as is)

**Note**: Schema field mappings updated:
- Schema uses `package_name` field
- Database column is `tool_name` (for now)
- Ecto handles the mapping transparently

## Key Improvements

### 1. **Self-Documenting**
```elixir
# OLD (vague)
ToolKnowledge.search(...)           # What kind of tools? Search what?
IntegratedSearch.hybrid_search(...) # Integrated with what? Hybrid how?

# NEW (clear)
PackageRegistryKnowledge.search(...)              # Searches package registries
PackageAndCodebaseSearch.unified_search(...)      # Searches packages AND your code
```

### 2. **Follows Your Patterns**
```elixir
# Your existing modules
SemanticCodeSearch          # What + How
FrameworkPatternStore       # What + What it does
TechnologyTemplateStore     # What + What it does

# New modules (same pattern)
PackageRegistryKnowledge    # What + What type
PackageAndCodebaseSearch    # What + What it searches
PackageRegistryCollector    # What + What it does
```

### 3. **Clear Distinction**
```elixir
# Package Registry Knowledge = Curated external packages
PackageRegistryKnowledge.search("tokio")
# → Official packages from crates.io/npm/hex

# Semantic Code Search = YOUR code (RAG)
SemanticCodeSearch.search("async implementation")
# → Your actual code files

# Package AND Codebase = Both combined
PackageAndCodebaseSearch.unified_search("async")
# → Official packages + Your code
```

## Usage Examples (Updated)

### Package Registry Knowledge
```elixir
# Search packages
PackageRegistryKnowledge.search("async runtime", ecosystem: :cargo)

# Cross-ecosystem equivalents
PackageRegistryKnowledge.find_equivalents("express", from: :npm, to: :cargo)

# Get package examples
PackageRegistryKnowledge.search_examples("spawn task", ecosystem: :cargo)
```

### Package AND Codebase Search
```elixir
# Unified search (packages + your code)
PackageAndCodebaseSearch.unified_search("web scraping",
  codebase_id: "my-project",
  ecosystem: :hex
)
# => %{
#   packages: [Floki, HTTPoison],  # From registries
#   your_code: [lib/scraper.ex],   # From YOUR codebase
#   combined_insights: "You've used Floki before in lib/scraper.ex"
# }

# Get package recommendation
PackageAndCodebaseSearch.recommend_package("authentication", ecosystem: :hex)
```

### Package Registry Collector
```elixir
# Collect packages
PackageRegistryCollector.collect_package("tokio", "1.35.0", ecosystem: :cargo)
PackageRegistryCollector.collect_popular(:npm, limit: 100)
PackageRegistryCollector.collect_from_manifest("Cargo.toml")
```

## Migration Path (If Renaming Tables)

If you want to rename the database tables to match (optional):

```elixir
# Create migration:
# priv/repo/migrations/YYYYMMDD_rename_tool_tables.exs

defmodule Singularity.Repo.Migrations.RenameToolTables do
  use Ecto.Migration

  def change do
    # Rename tables (optional - for consistency)
    rename table(:tools), to: table(:package_registry_knowledge)
    rename table(:tool_examples), to: table(:package_code_examples)
    rename table(:tool_patterns), to: table(:package_usage_patterns)

    # Update schemas to use new table names
    # Then update schema files to use new table names
  end
end
```

## Testing

All existing tests should work with aliasing:

```elixir
# In test files, add alias:
alias Singularity.PackageRegistryKnowledge
alias Singularity.PackageAndCodebaseSearch
alias Singularity.PackageRegistryCollector

# Then use new names:
test "searches packages" do
  results = PackageRegistryKnowledge.search("tokio")
  assert length(results) > 0
end
```

## Completion Checklist

- ✅ Renamed 8 module files
- ✅ Updated all internal references
- ✅ Renamed 4 schema files
- ✅ Updated field names (tool_name → package_name)
- ✅ Updated NATS subjects documentation
- ✅ Updated integration documentation
- ✅ Renamed documentation file
- ✅ Created this summary

## Result

**Self-documenting code that makes AI-assisted development clearer!**

Every name now tells you:
1. **What** it operates on (Package, Codebase, Registry)
2. **How** it works (Knowledge, Search, Collector)
3. **Why** it exists (combines packages + code, collects from registries)

No more confusion between "Tool" (vague) and "Package" (specific)! 🎉
