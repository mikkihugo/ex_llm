# PostgreSQL Extensions - Analysis & Recommendations

## Currently Installed (21 extensions) ✅

### Core Infrastructure
- ✅ `plpgsql` 1.0 - PL/pgSQL procedural language
- ✅ `uuid-ossp` 1.1 - UUID generation
- ✅ `pgcrypto` 1.3 - Cryptographic functions

### Search & Text
- ✅ `pg_trgm` 1.6 - Trigram fuzzy search
- ✅ `unaccent` 1.1 - Remove accents for search
- ✅ `fuzzystrmatch` 1.2 - String similarity (Levenshtein, Soundex)

### Specialized Data Types
- ✅ `hstore` 1.8 - Key-value pairs
- ✅ `ltree` 1.2 - Hierarchical tree structures (PERFECT for code call graphs!)
- ✅ `vector` 0.8.1 - pgvector for embeddings

### Graph & Spatial
- ✅ `age` 1.5.0 - Apache AGE graph database (Cypher queries)
- ✅ `postgis` 3.6.0 - Spatial/geographic data
- ✅ `pgrouting` 3.8.0 - Graph routing algorithms

### Time-Series & Performance
- ✅ `timescaledb` 2.22.1 - Time-series optimization
- ✅ `pg_stat_statements` 1.10 - Query performance tracking
- ✅ `pg_buffercache` 1.4 - Buffer cache inspection
- ✅ `pg_prewarm` 1.2 - Preload data into cache

### Indexing
- ✅ `btree_gin` 1.3 - GIN indexes for common types
- ✅ `btree_gist` 1.7 - GiST indexes for common types

### Automation & Connectivity
- ✅ `pg_cron` 1.6 - Job scheduler
- ✅ `postgres_fdw` 1.1 - Connect to remote PostgreSQL

### Testing
- ✅ `pgtap` 1.3.3 - Unit testing framework

---

## Recommended to Add (High Value)

### 1. `citext` - Case-Insensitive Text ⭐⭐⭐⭐⭐
**Why:** Perfect for usernames, emails, artifact IDs, package names
```sql
CREATE EXTENSION IF NOT EXISTS citext;

-- Usage
CREATE TABLE users (
  email citext UNIQUE,  -- 'User@Example.com' = 'user@example.com'
  username citext
);

-- Benefits for code analysis
CREATE TABLE packages (
  name citext,  -- 'React' = 'react' = 'REACT'
  ecosystem VARCHAR
);
```

**Your use case:**
- Package names: `React` vs `react`
- Module names: `GenServer` vs `genserver`
- Technology names: `PostgreSQL` vs `postgresql`

---

### 2. `intarray` - Integer Array Operations ⭐⭐⭐⭐
**Why:** Fast operations on integer arrays (IDs, dependency lists)
```sql
CREATE EXTENSION IF NOT EXISTS intarray;

-- Fast queries on arrays
SELECT * FROM modules
WHERE dependency_ids @@ query_int('1 | 2 | 3');  -- ANY of these IDs

-- Array intersection (common dependencies)
SELECT id FROM modules
WHERE dependency_ids && ARRAY[100, 200, 300];
```

**Your use case:**
- Fast dependency graph queries
- Module relationship lookups
- Tag/category filtering

---

### 3. `bloom` - Bloom Filter Index ⭐⭐⭐⭐
**Why:** Space-efficient indexes for multi-column queries
```sql
CREATE EXTENSION IF NOT EXISTS bloom;

-- Perfect for wide tables with many optional filters
CREATE INDEX code_files_bloom_idx ON code_files
USING bloom (language, project_name, line_count, size_bytes)
WITH (length=80, col1=2, col2=2, col3=4, col4=4);

-- Faster queries with multiple WHERE conditions
SELECT * FROM code_files
WHERE language = 'elixir'
  AND project_name = 'singularity'
  AND line_count > 100;
```

**Your use case:**
- Code search with multiple filters (language + size + complexity)
- Knowledge artifact queries (type + tags + language + quality)

---

### 4. `cube` - Multi-dimensional Data ⭐⭐⭐
**Why:** Analyze code metrics in multi-dimensional space
```sql
CREATE EXTENSION IF NOT EXISTS cube;

-- Store code quality metrics as cube
CREATE TABLE code_quality (
  file_id UUID,
  metrics cube,  -- [complexity, test_coverage, doc_coverage, maintainability]
  CHECK (cube_dim(metrics) = 4)
);

-- Find similar code by quality profile
SELECT file_id FROM code_quality
ORDER BY metrics <-> cube(ARRAY[10, 0.8, 0.9, 0.85])  -- Target quality
LIMIT 10;
```

**Your use case:**
- Code quality clustering (complexity, coverage, maintainability)
- Multi-metric similarity search (like embeddings but for structured metrics)

---

### 5. `dblink` - Cross-Database Queries ⭐⭐⭐
**Why:** Query between `singularity` and `central_services` databases
```sql
CREATE EXTENSION IF NOT EXISTS dblink;

-- Query central_services from singularity database
SELECT * FROM dblink(
  'dbname=central_services',
  'SELECT package_name, version FROM packages WHERE ecosystem = ''npm'''
) AS packages(name TEXT, version TEXT);

-- Useful for unified queries across both databases
```

**Your use case:**
- Join Singularity's code with central_cloud's package intelligence
- Unified search across both databases
- Cross-database analytics

---

### 6. `tablefunc` - Pivot Tables & Crosstabs ⭐⭐⭐
**Why:** Generate reports and analytics
```sql
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Pivot: Languages by project
SELECT * FROM crosstab(
  'SELECT project_name, language, COUNT(*)
   FROM code_files
   GROUP BY project_name, language
   ORDER BY 1, 2',
  'SELECT DISTINCT language FROM code_files ORDER BY 1'
) AS ct(project TEXT, elixir INT, rust INT, gleam INT);
```

**Your use case:**
- Code statistics dashboards
- Language usage reports
- Dependency matrix visualization

---

### 7. `amcheck` - Database Integrity Verification ⭐⭐⭐
**Why:** Verify index and table integrity (internal tooling = safety!)
```sql
CREATE EXTENSION IF NOT EXISTS amcheck;

-- Verify index integrity
SELECT bt_index_check('code_files_pkey');
SELECT bt_index_check('code_files_search_vector_idx');

-- Catch corruption early
```

**Your use case:**
- Ensure FTS indexes are valid
- Verify graph database integrity
- Detect issues before they cause problems

---

### 8. `pgstattuple` - Table Statistics ⭐⭐
**Why:** Analyze table bloat and performance
```sql
CREATE EXTENSION IF NOT EXISTS pgstattuple;

-- Check table bloat
SELECT * FROM pgstattuple('code_files');
-- Shows: dead tuples, free space, bloat percentage

-- When to VACUUM
SELECT schemaname, tablename,
       n_dead_tup, n_live_tup,
       ROUND(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) as dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000
ORDER BY dead_pct DESC;
```

**Your use case:**
- Optimize large code_files table
- Monitor database health
- Tune VACUUM settings

---

### 9. `pg_visibility` - Visibility Map Inspection ⭐⭐
**Why:** Debug VACUUM and understand table visibility
```sql
CREATE EXTENSION IF NOT EXISTS pg_visibility;

-- Check visibility map
SELECT * FROM pg_visibility_map('code_files');

-- Optimize for large tables
```

---

### 10. `tcn` - Triggered Change Notifications ⭐⭐⭐
**Why:** Real-time notifications when data changes
```sql
CREATE EXTENSION IF NOT EXISTS tcn;

-- Notify when code files change
CREATE TRIGGER code_files_notify
AFTER INSERT OR UPDATE OR DELETE ON code_files
FOR EACH ROW EXECUTE FUNCTION triggered_change_notification();

-- Listen in Elixir
Postgrex.Notifications.listen(conn, "tcn")
```

**Your use case:**
- Real-time code ingestion updates
- Cache invalidation when data changes
- Live dashboard updates

---

## Maybe Later (Lower Priority)

### `postgis_raster` ⭐
Raster data (images, heatmaps). Could visualize code complexity as heatmaps.

### `postgis_topology` ⭐
Topology data structures. Could model code architecture topology.

### `file_fdw` ⭐
Read files as foreign tables. Could query log files directly.

### `isn` ⭐
International product numbers (ISBN, ISSN). Not needed for code.

### `earthdistance` ⭐
Geographic distances. Not relevant for code analysis.

---

## Recommended Installation Order

```sql
-- High priority (immediate value)
CREATE EXTENSION IF NOT EXISTS citext;       -- Case-insensitive text
CREATE EXTENSION IF NOT EXISTS intarray;     -- Fast array operations
CREATE EXTENSION IF NOT EXISTS bloom;        -- Space-efficient indexes

-- Medium priority (analytics & debugging)
CREATE EXTENSION IF NOT EXISTS cube;         -- Multi-dimensional metrics
CREATE EXTENSION IF NOT EXISTS tablefunc;    -- Pivot tables
CREATE EXTENSION IF NOT EXISTS amcheck;      -- Integrity checks

-- Low priority (optimization & monitoring)
CREATE EXTENSION IF NOT EXISTS dblink;       -- Cross-database queries
CREATE EXTENSION IF NOT EXISTS pgstattuple;  -- Table statistics
CREATE EXTENSION IF NOT EXISTS tcn;          -- Change notifications
```

---

## Extensions You DON'T Need

❌ `xml2` - No XML processing needed
❌ `dict_int`, `dict_xsyn` - Custom FTS dictionaries (unnecessary)
❌ `insert_username`, `moddatetime` - Use triggers instead
❌ `intagg` - Obsolete (use array_agg)
❌ `refint` - Obsolete (use foreign keys)
❌ `lo` - Large objects (use bytea or external storage)
❌ `pageinspect` - Low-level debugging (rarely needed)
❌ `old_snapshot` - Snapshot threshold utils (not needed)
❌ `sslinfo` - SSL certificate info (not relevant)
❌ `tsm_system_rows/time` - TABLESAMPLE methods (not needed)

---

## Summary

**Install These 3 Now:**
1. `citext` - Case-insensitive package/module names
2. `intarray` - Fast dependency graph queries
3. `bloom` - Multi-column search optimization

**Install These 3 Soon:**
4. `cube` - Quality metrics clustering
5. `tablefunc` - Analytics & reports
6. `amcheck` - Database health checks

**Total extensions after:** 27 (21 current + 6 new)

---

## Migration to Add Extensions

```elixir
# priv/repo/migrations/20251014140000_add_useful_extensions.exs
defmodule Singularity.Repo.Migrations.AddUsefulExtensions do
  use Ecto.Migration

  def up do
    # High priority
    execute "CREATE EXTENSION IF NOT EXISTS citext"
    execute "CREATE EXTENSION IF NOT EXISTS intarray"
    execute "CREATE EXTENSION IF NOT EXISTS bloom"

    # Medium priority
    execute "CREATE EXTENSION IF NOT EXISTS cube"
    execute "CREATE EXTENSION IF NOT EXISTS tablefunc"
    execute "CREATE EXTENSION IF NOT EXISTS amcheck"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS amcheck"
    execute "DROP EXTENSION IF EXISTS tablefunc"
    execute "DROP EXTENSION IF EXISTS cube"
    execute "DROP EXTENSION IF EXISTS bloom"
    execute "DROP EXTENSION IF EXISTS intarray"
    execute "DROP EXTENSION IF EXISTS citext"
  end
end
```
