# Dual Storage Design (Raw JSON + JSONB)

## Philosophy

Store knowledge artifacts in **two formats** for different use cases:

1. **Raw JSON** (`content_raw` TEXT) - Exact original, audit trail
2. **Parsed JSONB** (`content` JSONB) - Fast queries, indexing, semantic search

## Inspired By

- **Terraform**: Stores state as both JSON file + in-memory parsed
- **Vault**: Stores policies as raw HCL + parsed AST
- **Git**: Stores both raw blobs + parsed tree objects

## Schema

```sql
CREATE TABLE knowledge_artifacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  artifact_type TEXT NOT NULL,
  artifact_id TEXT NOT NULL,
  version TEXT NOT NULL DEFAULT '1.0.0',

  -- Dual storage
  content_raw TEXT NOT NULL,        -- Original JSON string
  content JSONB NOT NULL,           -- Parsed for queries

  -- Semantic search
  embedding vector(1536),

  -- Generated columns (auto-extracted from JSONB)
  language TEXT GENERATED ALWAYS AS (content->>'language') STORED,
  tags TEXT[] GENERATED ALWAYS AS (
    ARRAY(SELECT jsonb_array_elements_text(content->'tags'))
  ) STORED,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(artifact_type, artifact_id, version),
  CHECK (content = content_raw::jsonb)  -- Ensure consistency
);
```

## Use Cases

### Raw JSON (`content_raw`)

✅ **Audit Trail**
```sql
-- See exact JSON as submitted (preserves formatting)
SELECT content_raw FROM knowledge_artifacts WHERE id = ?;
```

✅ **Debugging**
```sql
-- Compare original vs current
SELECT content_raw, content FROM knowledge_artifacts WHERE artifact_id = 'elixir-production';
```

✅ **Export to Git**
```sql
-- Export exact original for version control
COPY (SELECT content_raw FROM knowledge_artifacts WHERE artifact_type = 'quality_template')
TO '/tmp/exports/quality_templates.json';
```

✅ **Full-Text Search**
```sql
-- Search across raw JSON (includes formatting, comments if extended)
SELECT artifact_id FROM knowledge_artifacts
WHERE to_tsvector('english', content_raw) @@ to_tsquery('production & quality');
```

### Parsed JSONB (`content`)

✅ **Fast Queries** (GIN index)
```sql
-- Find all Elixir production templates
SELECT artifact_id FROM knowledge_artifacts
WHERE content @> '{"language": "elixir", "quality_level": "production"}';
```

✅ **Extract Fields**
```sql
-- Get specific fields
SELECT content->>'name', content->'requirements' FROM knowledge_artifacts;
```

✅ **Update Fields**
```sql
-- Update nested JSONB
UPDATE knowledge_artifacts
SET content = jsonb_set(content, '{quality_score}', '0.95')
WHERE artifact_id = 'elixir-production';
```

✅ **Aggregations**
```sql
-- Count by language
SELECT content->>'language', COUNT(*)
FROM knowledge_artifacts
GROUP BY content->>'language';
```

## Generated Columns

**Auto-extracted from JSONB for fast filtering:**

```sql
language TEXT GENERATED ALWAYS AS (content->>'language') STORED,
tags TEXT[] GENERATED ALWAYS AS (
  ARRAY(SELECT jsonb_array_elements_text(content->'tags'))
) STORED,
```

**Benefits:**
- ✅ Indexed for fast WHERE clauses
- ✅ Always in sync with JSONB (PostgreSQL guarantees)
- ✅ No manual denormalization needed

**Example:**
```sql
-- Uses index on generated column (fast!)
SELECT * FROM knowledge_artifacts WHERE language = 'elixir';

-- Equivalent JSONB query (slower without generated column)
SELECT * FROM knowledge_artifacts WHERE content->>'language' = 'elixir';
```

## Consistency Check

```sql
CHECK (content = content_raw::jsonb)
```

Ensures `content_raw` and `content` are always synchronized.

If they drift (corruption), constraint fails and alerts us.

## Insert Pattern

```elixir
defmodule Singularity.KnowledgeArtifactStore do
  def store(artifact_type, artifact_id, json_map, opts \\ []) do
    # Encode to pretty JSON string (for Git/human readability)
    content_raw = Jason.encode!(json_map, pretty: true)

    %KnowledgeArtifact{}
    |> KnowledgeArtifact.changeset(%{
      artifact_type: artifact_type,
      artifact_id: artifact_id,
      version: opts[:version] || "1.0.0",
      content_raw: content_raw,  # Raw JSON string
      content: json_map          # Ecto converts to JSONB
    })
    |> Repo.insert()
  end
end
```

## Query Patterns

### Use Raw JSON When:
- Exporting to Git
- Debugging discrepancies
- Audit logs
- Displaying original format

### Use JSONB When:
- Filtering (`WHERE content @> ...`)
- Extracting fields (`content->>'field'`)
- Updating nested data (`jsonb_set`)
- Aggregations (`GROUP BY content->>'language'`)
- Semantic search (embedding generated from JSONB)

## Storage Overhead

**Raw JSON:** ~1.2x size (includes whitespace, formatting)
**JSONB:** ~1.0x size (compressed binary)

**Total:** ~2.2x storage vs single JSONB

**Worth it?** YES for:
- Audit compliance
- Debug capabilities
- Export fidelity
- Data integrity verification

## Migration Path

1. **Load from Git** → Insert with both `content_raw` and `content`
2. **Validate** → CHECK constraint ensures consistency
3. **Query** → Use JSONB for runtime, raw for exports
4. **Export** → Use `content_raw` for exact Git representation

## Summary

| Feature | Raw JSON | JSONB |
|---------|----------|-------|
| **Storage** | TEXT | Binary |
| **Speed** | Slower | Faster (indexed) |
| **Format** | Exact original | Parsed |
| **Use Case** | Audit, export | Queries, search |
| **Indexing** | Full-text (GIN) | GIN, operators |
| **Size** | +20% (whitespace) | Compressed |

**Best of both worlds:** Audit trail + performance!
