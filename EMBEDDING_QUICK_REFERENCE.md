# Embedding Dimension Chaos - Quick Reference

## The Problem (One Sentence)
Code generates 1536-dim or 384-dim embeddings, but database schemas expect 768, 1536, or 2560 dims depending on table age.

## Key Files by Severity

### CRITICAL - Fix First
1. `/singularity/lib/singularity/llm/embedding_generator.ex` (line 247)
   - Returns single model (1536 or 384), NOT 2560
   
2. `/singularity/lib/singularity/embedding_engine.ex` (line 188)
   - Claims to return 2560-dim but delegates to NxService which doesn't concatenate
   
3. `/singularity/priv/repo/migrations/20250101000016_standardize_embedding_dimensions.exs`
   - CORRUPTED: Converts schema to 2560 but doesn't update data
   
4. `/singularity/lib/singularity/embedding/nx_service.ex` (line 82)
   - Takes single model, never concatenates Qodo + Jina

### HIGH - Fix Next
5. `/singularity/lib/singularity/search/unified_embedding_service.ex`
   - Fallback implementation, inconsistent dimensions
   
6. `/singularity/lib/singularity/jobs/embedding_finetune_job.ex`
   - Fine-tunes on embeddings with dimension mismatch
   
7. `/singularity/lib/singularity/search/embedding_quality_tracker.ex`
   - Tracks search quality but doesn't validate embedding dimensions

## Dimension Standards by Table

### 768-DIM (LEGACY - 12+ tables)
```
rules, code_embeddings, code_locations, rag_documents, rag_queries,
prompt_cache, tool_knowledge, framework_patterns, semantic_patterns,
code_examples, pattern_library, todos
```

### 1536-DIM (ACTIVE - 4 tables)
```
vector_embeddings (code_search_embeddings), 
knowledge_artifacts, templates
```

### 2560-DIM (NEWEST - 2 tables)
```
code_chunks, code_embedding_cache
```

## Quick SQL Checks

```sql
-- What dimensions are actually stored?
SELECT array_length(embedding, 1) as dim, COUNT(*)
FROM code_embeddings
GROUP BY 1;

-- Which tables have embedding columns?
SELECT table_name, column_name, udt_name
FROM information_schema.columns
WHERE column_name LIKE '%embedding%'
ORDER BY table_name;

-- Are there mismatches?
SELECT t.table_name, c.column_name, c.udt_name
FROM information_schema.tables t
JOIN information_schema.columns c ON t.table_name = c.table_name
WHERE c.column_name LIKE '%embedding%'
AND t.table_schema = 'public'
ORDER BY t.table_name;
```

## What's Broken Right Now

1. **code.ingest.ex** - Generates wrong dims for new tables
2. **Semantic search** - Can't compare different dimension vectors
3. **Fine-tuning** - Training data/inference dimension mismatch
4. **Table inserts** - Will fail on new 2560-dim tables

## Decision Tree

```
Choose Standard:
  ├─ Option A: 1536-dim (Qodo only)
  │   ├─ Simpler
  │   ├─ Faster
  │   ├─ Less storage
  │   └─ Code-optimized
  │
  └─ Option B: 2560-dim (Qodo + Jina)
      ├─ Better quality
      ├─ Slower
      ├─ More storage
      └─ 2x inference time

RECOMMENDATION: Option A (1536-dim)
```

## Fix Checklist

- [ ] Choose dimension standard (1536 vs 2560)
- [ ] Fix EmbeddingEngine to match standard
- [ ] Fix EmbeddingGenerator to match standard
- [ ] Revert/fix migration 20250101000016
- [ ] Add dimension validation to storage code
- [ ] Re-generate old embeddings OR migrate dimension
- [ ] Add integration tests
- [ ] Update CLAUDE.md documentation
- [ ] Block writes to new 2560-dim tables until fixed

## File Changes Needed

```
Core Fixes (3 files):
- embedding_engine.ex - Change to produce 1536 or implement 2560 concatenation
- embedding_generator.ex - Fix dimension handling
- nx_service.ex - Either remove concatenation code or make it reachable

Database (1 file):
- migration 20250101000016 - Revert or add fix-up migration

Tests (2 files):
- embedding_validation.ex - Add dimension checks
- New test file - End-to-end dimension tests

Documentation (2 files):
- CLAUDE.md - Update embedding section
- EMBEDDING_STRATEGY.md - New, define standard
```

## Timeline

- **This week:** Fix core code, add validation
- **Week 2-3:** Migrate data, fix schema
- **Week 4+:** Tests, monitoring, cleanup

## Success Criteria

All of these must be true:
1. EmbeddingGenerator consistently returns N dimensions (1536 or 2560)
2. All embedding tables expect same N dimensions
3. Queries comparing embeddings never get dimension mismatch
4. Fine-tuning uses correct training data dimension
5. Tests validate end-to-end pipeline
