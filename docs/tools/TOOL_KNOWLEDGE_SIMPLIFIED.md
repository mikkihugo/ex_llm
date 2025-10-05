# Tool Knowledge: Simplified Production Design

## Current Problem

The `tool_knowledge` migration creates **5 embedding columns** across **4 tables**, but **NONE are actually used** in code!

- `tools.semantic_embedding` - ❌ Never queried
- `tools.description_embedding` - ❌ Never queried
- `tool_examples.code_embedding` - ❌ Never queried
- `tool_patterns.pattern_embedding` - ❌ Never queried (different from framework_patterns!)
- `code_embeddings.embedding` - ✅ Used by RustToolingAnalyzer

Only 1 out of 5 is actually used!

---

## Recommended: Simplified Design

### Keep What's Used, Remove What's Not

```
Current: 5 embeddings across 4 tables
Proposed: 2 embeddings across 2 tables
Savings: 60% reduction in vector storage
```

### Proposal A: **Minimal (Recommended)**

**Keep only actively used embeddings:**

1. **`code_embeddings`** table (KEEP - used by RustToolingAnalyzer)
   - Purpose: Analyze Rust tooling output
   - Embedding: Code analysis results
   - Usage: Active

2. **`framework_patterns`** table (KEEP - used by FrameworkPatternStore)
   - Purpose: Technology detection patterns
   - Embedding: Framework patterns for similarity search
   - Usage: Active

**Remove unused tables:**
- ❌ `tools` - Never queried, no feature built
- ❌ `tool_examples` - Never used
- ❌ `tool_patterns` - Duplicate of framework_patterns
- ❌ `tool_dependencies` - Unused
- ❌ `tool_commands` - Unused
- ❌ `tool_frameworks` - Unused
- ❌ `tool_usage_stats` - Unused

**Result**: Simple, focused schema with only what's actually needed.

---

### Proposal B: **Keep But Fix** (If you want tool discovery later)

If you plan to implement MCP tool discovery in the future:

**Consolidate to 1 embedding per entity:**

```sql
-- TOOLS (consolidate to 1 embedding)
CREATE TABLE tools (
  id UUID PRIMARY KEY,
  tool_name TEXT NOT NULL,
  version TEXT,
  ecosystem TEXT NOT NULL,  -- npm, cargo, hex, pypi

  -- Metadata
  description TEXT,
  documentation TEXT,
  homepage_url TEXT,
  tags TEXT[],

  -- ONE embedding for everything
  embedding VECTOR(768),  -- Embeds: name + description + tags

  timestamps
);

-- TOOL EXAMPLES (keep separate - different search domain)
CREATE TABLE tool_examples (
  id BIGSERIAL PRIMARY KEY,
  tool_id UUID REFERENCES tools,
  title TEXT,
  code TEXT,
  language TEXT,

  -- Code-specific embedding
  code_embedding VECTOR(768),  -- Embeds: code + explanation

  timestamps
);

-- REMOVE these tables (unused):
-- ❌ tool_patterns (use framework_patterns instead)
-- ❌ tool_dependencies (just store in JSONB on tools)
-- ❌ tool_commands (store in JSONB on tools)
-- ❌ tool_frameworks (use framework_patterns)
-- ❌ tool_usage_stats (use rag_performance_stats)
```

**Result**: 2 embeddings total, clear separation between tool metadata and code examples.

---

## Migration Strategy

### Option 1: Clean Slate (Recommended - no data yet)

Since the tables are unused, just **remove the migration entirely** and keep only what's actively used.

```bash
# Remove unused migration
rm singularity_app/priv/repo/migrations/20251004210118_create_tool_knowledge.exs

# Keep only:
# - code_embeddings (via RustToolingAnalyzer)
# - framework_patterns (existing, works)
```

### Option 2: Simplify Migration (Keep for future)

Replace the complex migration with a simpler version:

```elixir
# New: 20251006000000_create_tool_catalog.exs
defmodule Singularity.Repo.Migrations.CreateToolCatalog do
  use Ecto.Migration

  def up do
    # Simple tool catalog (MCP, npm, cargo, hex packages)
    create table(:tools, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :text, null: false
      add :version, :text
      add :ecosystem, :text, null: false
      add :description, :text
      add :homepage_url, :text
      add :tags, {:array, :string}, default: []

      # ONE embedding: tool semantics (name + description + tags)
      add :embedding, :vector, size: 768

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tools, [:name, :ecosystem])
    create index(:tools, [:ecosystem])

    execute """
    CREATE INDEX tools_embedding_idx ON tools
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    """

    # Code examples (separate - different embedding domain)
    create table(:tool_code_examples) do
      add :tool_id, references(:tools, type: :uuid, on_delete: :delete_all)
      add :title, :text
      add :code, :text, null: false
      add :language, :text
      add :explanation, :text

      # Code-specific embedding
      add :code_embedding, :vector, size: 768

      timestamps(type: :utc_datetime)
    end

    create index(:tool_code_examples, [:tool_id])
    create index(:tool_code_examples, [:language])

    execute """
    CREATE INDEX tool_code_examples_embedding_idx ON tool_code_examples
    USING hnsw (code_embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)
    """
  end

  def down do
    drop table(:tool_code_examples)
    drop table(:tools)
  end
end
```

---

## Feature Roadmap (When to use tool catalog)

**Now**: Remove unused tables, keep only `code_embeddings` + `framework_patterns`

**Later** (when implementing MCP tool discovery):
- Add simplified `tools` table
- Populate from MCP server registries
- Add `tool_code_examples` for usage patterns
- Implement semantic tool search

---

## Comparison

| Aspect | Current (Unused) | Proposal A (Minimal) | Proposal B (Simplified) |
|--------|------------------|----------------------|-------------------------|
| Tables | 8 tables | 2 tables | 3 tables |
| Embeddings | 5 columns | 2 columns | 3 columns |
| Vector Storage | ~30MB per 10k tools | ~7MB | ~12MB |
| Actually Used | 1 embedding | 2 embeddings | 3 embeddings |
| Complexity | High | Low | Medium |
| Future-proof | No (over-engineered) | Yes (add when needed) | Yes (ready for MCP) |

---

## Recommendation

**Go with Proposal A (Minimal)** because:

1. ✅ Remove dead code (7 unused tables)
2. ✅ Keep what works (`code_embeddings`, `framework_patterns`)
3. ✅ Add tool catalog later when you actually need it (MCP integration)
4. ✅ YAGNI principle - don't build features you don't use yet
5. ✅ Simpler = easier to maintain

**When you're ready for MCP tool discovery**, add the simplified `tools` + `tool_code_examples` tables from Proposal B.

---

## Action Items

1. ❌ **Remove** `20251004210118_create_tool_knowledge.exs` migration
2. ✅ **Keep** `code_embeddings` usage in `RustToolingAnalyzer`
3. ✅ **Keep** `framework_patterns` usage in `FrameworkPatternStore`
4. 📝 **Document** that MCP tool catalog will be added when needed
5. 🚀 **Deploy** with cleaner, simpler schema

**Want me to create the removal migration and clean up?**
