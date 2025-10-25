# Why We Don't Have pg_search

**Question**: Why no pg_search? It's a powerful search engine.

**Answer**: Short version - **Semantic search (pgvector) is better for code than keyword search (pg_search).**

---

## What is pg_search?

pg_search is a PostgreSQL extension from ParadeDB that:
- Implements **BM25 ranking algorithm** (used by Elasticsearch)
- Provides **full-text search** (keyword-based)
- Optimized for documents, articles, logs
- NOT optimized for code

**Example pg_search query**:
```sql
SELECT * FROM code_chunks
WHERE content @@ 'asyncio'  -- Find all mentions of "asyncio"
ORDER BY rank DESC;         -- BM25 ranking
```

---

## Why We Chose pgvector Over pg_search

### 1. Different Search Paradigms

| Aspect | pg_search (Keyword) | pgvector (Semantic) |
|--------|-------------------|-------------------|
| **Finds** | Words/phrases | Similar meaning |
| **Example** | "Find code containing 'async'" | "Find code with async pattern" |
| **Best for** | Text, documents, logs | Code, embeddings, semantics |
| **Algorithm** | BM25 ranking | Vector similarity (cosine) |

### 2. Code Search is Semantic, Not Keyword-Based

**What we care about in code search**:
- Find similar code patterns ✅
- Understand intent and meaning ✅
- Match across different implementations ✅
- Find related but differently-named code ✅

**What we DON'T care about**:
- Find exact keyword matches ❌
- Count word frequency ❌
- Rank by term importance ❌

**Example**:
```python
# With pgvector (semantic):
"Find code that handles async operations"
→ Returns: async/await, asyncio, promises, callbacks, etc.
→ All semantically similar approaches

# With pg_search (keyword):
"Find code containing 'asyncio'"
→ Returns: Only files with the word "asyncio"
→ Misses: async/await, promises, etc.
```

### 3. pgvector is Purpose-Built for Code

Our setup:
- **Qodo (1536-dim) + Jina v3 (1024-dim) = 2560-dim vectors**
- Trained specifically to understand code semantics
- Captures intent, patterns, algorithms
- NOT general document vectors

Example queries pgvector enables:
```elixir
# Find code with similar error handling patterns
similar = CodeSearch.find_similar(error_handling_embedding)

# Find code with similar database access patterns
similar = CodeSearch.find_similar(db_query_embedding)

# Find code using similar algorithms
similar = CodeSearch.find_similar(algorithm_embedding)
```

**pg_search cannot do any of this.** It's keyword-based.

---

## Why Not Have BOTH?

### Availability
- **pgvector**: ✅ In nixpkgs for PostgreSQL 17
- **pg_search**: ❌ NOT in nixpkgs (ParadeDB not packaged)

To add pg_search would require:
1. Clone ParadeDB repository
2. Build Rust extension from source
3. Test compatibility with our setup
4. Maintain fork in Nix

### Value Proposition
**If we added pg_search, what new capability?**
- "Find code containing keyword X" (e.g., find all "TODO" comments)
- Keyword-based filtering
- Full-text ranking

**Do we actually need this?**
- pg_trgm (built-in) already handles fuzzy matching
- git grep handles literal keyword search
- Semantic search (pgvector) finds patterns > keywords

**Cost vs Benefit**:
- Cost: Package ParadeDB, maintain it, complexity
- Benefit: Keyword search (which git/grep already do)
- Decision: Not worth it

---

## Could We Add pg_search Later?

**Yes, absolutely.**

If we decide "we want keyword search AS WELL as semantic search":

```bash
# Option 1: Build ParadeDB from source
git clone https://github.com/paradedb/paradedb.git
# ... build and package for Nix

# Option 2: Use existing Docker container
docker run -p 5432:5432 paradedb/paradedb:latest
# ... connect from app

# Then use both:
# pgvector for semantic: "Find similar code"
# pg_search for keyword: "Find code containing 'bug'"
```

## LLM Coders Might Need Full-Text Search

Good point. LLM agents might want:

**Examples where agents need keyword search**:
1. "Find all TODO comments" → needs exact keyword match
2. "Find all occurrences of deprecated API X" → literal search
3. "Find all files importing module Y" → text matching
4. "Find all error messages containing 'timeout'" → keyword search
5. "Find all SQL queries with specific pattern" → text matching

**Current tools**:
- ✅ git grep (command-line, works today)
- ✅ pg_trgm (fuzzy keyword matching, built-in)
- ❌ pg_search (BM25 full-text, not installed)

**Options for agents**:

### Option A: Use git grep (TODAY)
```elixir
{:ok, results} = System.cmd("git", ["grep", "-n", "TODO"])
# Instant, no DB needed, perfect for keyword search
```

### Option B: Add pg_search (FUTURE)
```elixir
{:ok, results} = Repo.query("""
  SELECT path, content FROM code_chunks
  WHERE content @@ 'deprecated_api'
""")
```

### Option C: Hybrid (BEST)
- Use **pgvector** for semantic/pattern search ("find similar code")
- Use **git grep** for keyword search ("find this text")
- Add **pg_search** if git grep becomes bottleneck

**Decision**: Start with git grep + pgvector, add pg_search if needed

But right now: **We optimized for semantic search, which is better for most code analysis.**

---

## Real-World Comparison

### Scenario: "I need to understand how we handle database errors"

**With pgvector (what we have)**:
```elixir
error_handling_code = "try-catch error logging retry"
similar = CodeSearch.find_similar(error_handling_code)
# Returns: All code with similar error patterns
# Time: <50ms
# Result: Find ALL error handling, regardless of keywords
```

**With pg_search (what we don't have)**:
```sql
SELECT * FROM code WHERE content @@ 'error|exception|catch'
ORDER BY rank;
# Returns: Code containing these keywords
# Time: Fast
# Result: Find code with these words, miss some patterns
```

**Winner**: pgvector (semantic)
- Finds more patterns
- Understands intent
- Better for code analysis

---

## The Decision Rationale

```
CHOICE: Semantic (pgvector) > Keyword (pg_search)

REASON: Code search is about understanding meaning, not matching words

EVIDENCE:
- Industry uses vector search for code (GitHub Copilot, etc.)
- Keyword search is what git grep already does
- Code intent > keywords

TRADE-OFF: Can't do keyword-only search
         But: Have better semantic search

AVAILABILITY: pg_search not in nixpkgs anyway

CONCLUSION: Semantic-first, no regrets
```

---

## Summary

| Question | Answer |
|----------|--------|
| What is pg_search? | BM25 full-text search (keyword-based) |
| Why not include it? | Semantic search (pgvector) > keyword search for code |
| Could we add it? | Yes, but would need to build ParadeDB from source |
| Do we need it? | No - git grep handles keyword search, pgvector handles semantic |
| Is pgvector better? | For code: YES. For documents: pg_search is better |
| What if we want both? | Can add later if needed (Nix-compatible) |

**Bottom line**: We chose the right tool for the job. pgvector for code analysis beats keyword search every time.

---

**Date**: October 25, 2025
**Status**: Intentional design decision, not oversight
