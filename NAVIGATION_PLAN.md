# AI Code Navigation Plan - 7B Line Monorepo

## The Real Problem

**AI needs to:**
1. Find where to add new feature (without duplicating existing code)
2. Understand what already exists (avoid reinventing the wheel)
3. Wire up correctly (connect to existing patterns)
4. Not break anything (understand dependencies and impact)

**At 7B lines in ONE system:**
- Can't read everything
- Can't search by brute force
- Need intelligent navigation
- Need context awareness

---

## Current State (1-2M Lines)

Start here - prove the system works at manageable scale first.

### What You Need NOW (Week 1-2)

#### 1. Pattern Index (DONE ✅)
```elixir
# Already built today
CodePatternExtractor.extract_from_code(file, :elixir)
# => ["genserver", "nats", "http_client", "supervisor"]

# This tells AI: "This file implements a NATS HTTP client with GenServer"
```

#### 2. Code Location Index (WEEK 1)
**Purpose:** "Where is X implemented?"

```elixir
defmodule Singularity.CodeLocationIndex do
  @moduledoc """
  Index what patterns exist WHERE in the codebase.

  Answers:
  - "Where are GenServers implemented?" → List of files
  - "Where is NATS used?" → List of files
  - "Where is authentication handled?" → List of files
  - "What does this file do?" → Pattern summary
  """

  # Build index from codebase
  def index_codebase(path) do
    Path.wildcard("#{path}/**/*.{ex,exs,gleam,rs}")
    |> Task.async_stream(&index_file/1, max_concurrency: 10)
    |> Enum.into(%{})
  end

  defp index_file(filepath) do
    code = File.read!(filepath)
    language = detect_language(filepath)
    patterns = CodePatternExtractor.extract_from_code(code, language)

    # Store in database
    %{
      filepath: filepath,
      patterns: patterns,
      exports: extract_public_api(code, language),
      imports: extract_dependencies(code, language)
    }
  end

  # Query: "Where is NATS used?"
  def find_pattern(pattern_keyword) do
    # Query database
    Repo.all(
      from c in CodeIndex,
      where: fragment("? @> ARRAY[?]::text[]", c.patterns, ^pattern_keyword),
      select: c.filepath
    )
  end
end
```

**Database schema:**
```sql
CREATE TABLE code_index (
  filepath text PRIMARY KEY,
  patterns text[],           -- ["genserver", "nats", "http"]
  exports text[],            -- Public API
  imports text[],            -- Dependencies
  summary text,              -- One-line description
  last_indexed timestamp
);

CREATE INDEX idx_patterns ON code_index USING GIN(patterns);
```

**Timeline:** 2 days

---

#### 3. Deduplication Detector (WEEK 1)
**Purpose:** "Does this already exist?"

```elixir
defmodule Singularity.DuplicationDetector do
  @moduledoc """
  Before AI writes new code, check if similar code exists.

  AI: "I want to create a NATS consumer"
  System: "We have 47 NATS consumers. Here are the 3 most similar..."
  """

  def find_similar(description_or_code, limit: 5) do
    # Extract patterns from what AI wants to build
    patterns = CodePatternExtractor.extract_from_text(description_or_code)

    # Find files with similar patterns
    candidates = CodeLocationIndex.find_by_patterns(patterns)

    # Rank by similarity
    candidates
    |> Enum.map(fn file ->
      file_patterns = get_file_patterns(file)
      similarity = pattern_overlap(patterns, file_patterns)
      {file, similarity}
    end)
    |> Enum.sort_by(fn {_file, sim} -> sim end, :desc)
    |> Enum.take(limit)
  end

  defp pattern_overlap(patterns1, patterns2) do
    set1 = MapSet.new(patterns1)
    set2 = MapSet.new(patterns2)
    intersection = MapSet.intersection(set1, set2) |> MapSet.size()
    union = MapSet.union(set1, set2) |> MapSet.size()

    # Jaccard similarity
    intersection / union
  end
end
```

**Timeline:** 2 days

---

#### 4. Dependency Mapper (WEEK 2)
**Purpose:** "What will I break if I change this?"

```elixir
defmodule Singularity.DependencyMapper do
  @moduledoc """
  Build dependency graph of the codebase.

  Answers:
  - "What depends on this module?" → List of dependents
  - "What does this module depend on?" → List of dependencies
  - "Safe to modify this?" → Impact analysis
  """

  def build_graph(codebase_path) do
    files = index_all_files(codebase_path)

    # Build directed graph
    graph = :digraph.new([:acyclic])

    # Add edges: file A imports file B → A depends on B
    Enum.each(files, fn file ->
      :digraph.add_vertex(graph, file.filepath)

      Enum.each(file.imports, fn imported ->
        imported_file = resolve_import(imported, codebase_path)
        if imported_file do
          :digraph.add_edge(graph, file.filepath, imported_file)
        end
      end)
    end)

    graph
  end

  # What will break if I modify this file?
  def impact_analysis(filepath) do
    graph = get_cached_graph()

    # Find all files that (directly or indirectly) depend on this
    dependents = :digraph.out_neighbours(graph, filepath)

    # Recursive search
    all_dependents = find_all_dependents(graph, filepath)

    %{
      direct_dependents: dependents,
      total_impact: length(all_dependents),
      critical: is_critical?(all_dependents)  # Used by >10 files = critical
    }
  end
end
```

**Timeline:** 3 days

---

### Week 1-2 Deliverables (1-2M Lines)

1. ✅ **Pattern Extraction** (DONE)
2. 🔨 **Code Location Index** (2 days)
   - Table: `code_index` with GIN index
   - API: `find_pattern/1`, `index_file/1`

3. 🔨 **Duplication Detector** (2 days)
   - API: `find_similar/2`
   - Prevents duplicate implementations

4. 🔨 **Dependency Mapper** (3 days)
   - Graph in memory (digraph)
   - API: `impact_analysis/1`
   - Prevents breaking changes

**Total:** ~1 week of focused work

---

## AI Navigation Flow (How It Works)

### User: "Add webhook support to the NATS consumer"

```
┌─────────────────────────────────────────────────┐
│ 1. Extract Intent                              │
│ Patterns: ["webhook", "nats", "consumer"]      │
└─────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────┐
│ 2. Find Existing Code                          │
│ CodeLocationIndex.find_pattern("nats")         │
│ → 47 files use NATS                            │
│ → 12 are NATS consumers                        │
└─────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────┐
│ 3. Check for Duplicates                        │
│ DuplicationDetector.find_similar(              │
│   "webhook NATS consumer"                      │
│ )                                              │
│ → Found: lib/webhooks/nats_webhook.ex (85%)   │
│ → "This already exists! Extend it."            │
└─────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────┐
│ 4. Analyze Impact (if modifying)               │
│ DependencyMapper.impact_analysis(              │
│   "lib/webhooks/nats_webhook.ex"              │
│ )                                              │
│ → 3 files depend on this                      │
│ → Not critical, safe to modify                │
└─────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────┐
│ 5. AI Decision                                 │
│ "Don't create new file - extend existing      │
│  lib/webhooks/nats_webhook.ex                 │
│  Add new webhook type handler.                │
│  Test: 3 dependent files still work."         │
└─────────────────────────────────────────────────┘
```

---

## Scaling to 7B Lines (Later)

### Current Plan (1-2M Lines)
- **Code Index**: Postgres GIN index (~50 MB)
- **Dependency Graph**: In-memory digraph (~100 MB)
- **Query time**: 10-50ms

### At 7B Lines (Future)
- **Code Index**: Sharded Postgres (~5 GB)
- **Dependency Graph**: Distributed graph (Neo4j or Apache AGE) (~50 GB)
- **Query time**: 100-200ms
- **Smart Sampling**: Index only public APIs + unique patterns (10% of code)

**But don't build this yet!** Prove it works at 1-2M first.

---

## Implementation Priority

### Phase 1: Foundation (THIS WEEK) ⭐
1. ✅ Pattern extraction (DONE)
2. 🔨 Code location index (2 days)
3. 🔨 Duplication detector (2 days)

**Result:** AI can find existing code and avoid duplicates

### Phase 2: Safety (NEXT WEEK)
4. 🔨 Dependency mapper (3 days)
5. 🔨 Impact analysis (2 days)

**Result:** AI knows what will break

### Phase 3: Intelligence (LATER)
6. Template matching (use existing templates)
7. Auto-wiring suggestions
8. Test coverage analysis

---

## Database Schema (Simple)

```sql
-- Code location index
CREATE TABLE code_index (
  id SERIAL PRIMARY KEY,
  filepath TEXT UNIQUE NOT NULL,
  patterns TEXT[] NOT NULL,           -- GIN indexed
  exports TEXT[],                     -- Public API
  imports TEXT[],                     -- Dependencies
  summary TEXT,                       -- One-line description
  language TEXT,                      -- elixir, gleam, rust
  lines_of_code INTEGER,
  last_indexed TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_patterns ON code_index USING GIN(patterns);
CREATE INDEX idx_filepath ON code_index(filepath);

-- Dependency edges (for graph)
CREATE TABLE dependencies (
  id SERIAL PRIMARY KEY,
  from_file TEXT REFERENCES code_index(filepath),
  to_file TEXT REFERENCES code_index(filepath),
  import_type TEXT,                   -- module, function, type
  UNIQUE(from_file, to_file)
);

CREATE INDEX idx_from ON dependencies(from_file);
CREATE INDEX idx_to ON dependencies(to_file);
```

**Size at 1-2M lines:**
- ~10K files
- ~50K dependencies
- ~50 MB total

---

## What You DON'T Need (Yet)

❌ Vector embeddings - Keywords work fine for navigation
❌ ML models - Pattern matching is enough
❌ Complex deduplication - Jaccard similarity works
❌ Distributed system - Single Postgres handles 2M lines
❌ Graph database - Postgres + digraph is sufficient

---

## Success Metrics

After Phase 1 (this week):

✅ AI can answer:
- "Where is NATS used?" (in <50ms)
- "Show me all GenServers" (in <50ms)
- "Does webhook consumer exist?" (in <100ms)
- "Find similar implementations" (in <200ms)

After Phase 2 (next week):

✅ AI can answer:
- "What depends on this module?" (in <100ms)
- "Safe to modify this file?" (in <200ms)
- "Impact of changing this?" (in <300ms)

---

## Quick Start (This Week)

```bash
# 1. Create migration
mix ecto.gen.migration create_code_index

# 2. Run migration (use schema above)
mix ecto.migrate

# 3. Index your codebase
iex -S mix
iex> Singularity.CodeLocationIndex.index_codebase(".")

# 4. Test queries
iex> Singularity.CodeLocationIndex.find_pattern("genserver")
["lib/workers/nats_consumer.ex", "lib/services/webhook_handler.ex", ...]

iex> Singularity.DuplicationDetector.find_similar("NATS webhook consumer")
[{"lib/webhooks/nats_webhook.ex", 0.85}, ...]
```

---

## The Big Picture (Don't Implement Yet)

```
User: "Add feature X"
        ↓
    Intent Extraction (patterns)
        ↓
    Location Index (where is related code?)
        ↓
    Duplication Check (already exists?)
        ↓
    ┌─────────┬─────────┐
    Yes       No
    ↓         ↓
    Extend    Create New
    Existing      ↓
    ↓         Template Match
    ↓         (from existing templates)
    ↓             ↓
    Impact    Choose Template
    Analysis      ↓
    ↓         Generate Code
    ↓             ↓
    Test      Wire Up (dependency map)
    Coverage      ↓
    ↓         Add Tests
    ↓             ↓
    └─────────┬───┘
              ↓
        Commit Changes
```

**But start with:** Index → Deduplicate → Dependencies

---

## Summary

**Problem:** Navigate 7B lines without duplicating code or breaking things

**Solution (Week 1-2):**
1. ✅ Pattern extraction (DONE)
2. 🔨 Code location index (find existing code)
3. 🔨 Duplication detector (avoid reinventing)
4. 🔨 Dependency mapper (avoid breaking)

**Current scope:** 1-2M lines (prove it works)
**Future scale:** 7B lines (same approach, add sampling)

**Timeline:** 1 week for basic navigation

**No embeddings needed yet** - keywords are enough! 🚀
