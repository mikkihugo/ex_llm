# Package Registry Knowledge System Setup

## Status: ✓ Fixed and Ready

The Package Registry Knowledge system schemas were already created, but were missing database migrations. This has been resolved.

## What Was Fixed

### Problem
The file `/home/mhugo/code/singularity/singularity_app/lib/singularity/search/package_registry_knowledge.ex` referenced schemas that existed but had no corresponding database tables.

### Solution
1. **Created Migration**: `20240101000006_create_package_registry_tables.exs`
2. **Updated Schema**: Fixed foreign_key declarations in `PackageRegistryKnowledge`

## Schema Architecture

### Main Tables

#### 1. `tools` (PackageRegistryKnowledge)
**Purpose:** Stores package metadata from npm, cargo, hex, pypi registries

**Key Fields:**
- `package_name`, `version`, `ecosystem` - Package identification
- `description`, `documentation` - Package documentation
- `semantic_embedding` (vector) - For semantic search
- `github_stars`, `download_count` - Quality signals
- `tags`, `keywords`, `categories` - Classification

**File:** `/home/mhugo/code/singularity/singularity_app/lib/singularity/schemas/package_registry_knowledge.ex`

#### 2. `tool_examples` (PackageCodeExample)
**Purpose:** Code examples extracted from package documentation

**Key Fields:**
- `tool_id` - Foreign key to tools
- `title`, `code`, `language` - Example content
- `code_embedding` (vector) - For semantic search
- `example_order` - Display ordering

**File:** `/home/mhugo/code/singularity/singularity_app/lib/singularity/schemas/package_code_example.ex`

#### 3. `tool_patterns` (PackageUsagePattern)
**Purpose:** Best practices, anti-patterns, usage patterns

**Key Fields:**
- `tool_id` - Foreign key to tools
- `pattern_type` - best_practice, anti_pattern, usage_pattern, migration_guide
- `title`, `description`, `code_example` - Pattern content
- `pattern_embedding` (vector) - For semantic search

**File:** `/home/mhugo/code/singularity/singularity_app/lib/singularity/schemas/package_usage_pattern.ex`

#### 4. `tool_dependencies` (PackageDependency)
**Purpose:** Package dependency tracking

**Key Fields:**
- `tool_id` - Foreign key to tools
- `dependency_name`, `dependency_version` - Dependency info
- `dependency_type` - runtime, dev, peer, optional
- `is_optional` - Boolean flag

**File:** `/home/mhugo/code/singularity/singularity_app/lib/singularity/schemas/package_dependency.ex`

## Relationships

```
PackageRegistryKnowledge (tools)
  ├── has_many :examples → PackageCodeExample (tool_examples)
  ├── has_many :patterns → PackageUsagePattern (tool_patterns)
  └── has_many :dependencies → PackageDependency (tool_dependencies)
```

## Running the Migration

```bash
cd /home/mhugo/code/singularity/singularity_app
mix ecto.migrate
```

## Verifying the Setup

### 1. Check Tables Exist
```bash
# In iex -S mix
Singularity.Repo.query!("""
  SELECT tablename FROM pg_tables
  WHERE schemaname = 'public'
  AND tablename LIKE 'tool%'
  ORDER BY tablename
""")
```

Expected output:
- tool_dependencies
- tool_examples
- tool_patterns
- tools

### 2. Test Basic Search (will return empty until data is loaded)
```elixir
# In iex -S mix
alias Singularity.PackageRegistryKnowledge

# Should execute without errors (empty results until data loaded)
PackageRegistryKnowledge.search("async runtime", ecosystem: "cargo", limit: 5)
```

### 3. Test Schema Relationships
```elixir
# In iex -S mix
alias Singularity.Schemas.{PackageRegistryKnowledge, PackageCodeExample}

# Should compile without errors
%PackageRegistryKnowledge{}
%PackageCodeExample{}
```

## Key Features

### Vector Similarity Search
- Uses pgvector with ivfflat indexes for fast approximate search
- Cosine similarity (`<->` operator) for semantic matching
- Embeddings size: 768 dimensions (Google text-embedding-004)

### Quality Signals
- GitHub stars
- Download counts
- Last release date
- Ecosystem (npm/cargo/hex/pypi)

### Cross-Ecosystem Search
```elixir
# Find Rust equivalents of Express.js
PackageRegistryKnowledge.find_equivalents("express",
  from: "npm",
  to: "cargo"
)
# => [%{package_name: "actix-web", ...}, %{package_name: "axum", ...}]
```

### Semantic Code Example Search
```elixir
# Find examples across all packages
PackageRegistryKnowledge.search_examples("async http request",
  ecosystem: "cargo",
  limit: 10
)
```

## Migration Details

**File:** `/home/mhugo/code/singularity/singularity_app/priv/repo/migrations/20240101000006_create_package_registry_tables.exs`

**Indexes Created:**
- Unique index: `tools (package_name, version, ecosystem)`
- Performance indexes: package_name, ecosystem, github_stars, download_count, last_release_date
- Vector indexes: ivfflat for all embedding columns

**Foreign Keys:**
- All child tables reference `tools.id` with cascade delete
- Type: `binary_id` (UUID)

## Files Modified

1. **Created:**
   - `/home/mhugo/code/singularity/singularity_app/priv/repo/migrations/20240101000006_create_package_registry_tables.exs`

2. **Updated:**
   - `/home/mhugo/code/singularity/singularity_app/lib/singularity/schemas/package_registry_knowledge.ex`
     - Added explicit `foreign_key: :tool_id` to all has_many associations

## All Schemas Verified ✓

All 4 schemas exist and are properly configured:
- ✓ `/home/mhugo/code/singularity/singularity_app/lib/singularity/schemas/package_registry_knowledge.ex`
- ✓ `/home/mhugo/code/singularity/singularity_app/lib/singularity/schemas/package_code_example.ex`
- ✓ `/home/mhugo/code/singularity/singularity_app/lib/singularity/schemas/package_usage_pattern.ex`
- ✓ `/home/mhugo/code/singularity/singularity_app/lib/singularity/schemas/package_dependency.ex`

## Next Steps

1. Run the migration: `mix ecto.migrate`
2. Load package data using Rust collectors (see `/home/mhugo/code/singularity/rust/tool_doc_index/`)
3. Test semantic search functionality
4. Integrate with PackageAndCodebaseSearch for unified search

## Architecture Notes

**This is NOT RAG!** This is structured package knowledge with semantic search capabilities.

**RAG (Semantic Code Search):** Searches YOUR actual codebase
**Package Registry Knowledge:** Searches curated package metadata from registries

Both can be combined via `PackageAndCodebaseSearch.unified_search()` for best results.
