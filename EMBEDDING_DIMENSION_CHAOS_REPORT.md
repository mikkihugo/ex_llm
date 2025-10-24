# Embedding Dimension Chaos - Comprehensive Analysis Report

## Executive Summary

The codebase has a **CRITICAL embedding dimension mismatch** across multiple layers:

| Layer | Expected Dims | Actual Produced | Status |
|-------|---|---|---|
| **Embedding Generation** | 2560 | Unknown (needs clarification) | CHAOS |
| **Database Schema** | 2560, 1536, 768 (MIXED) | See table breakdown | CRITICAL |
| **Migration History** | 768 → 2560 | MULTIPLE STANDARDS | BROKEN |
| **Model Specifications** | Qodo(1536) + Jina(1024) = 2560 | Correct | DOCUMENTED |

---

## Critical Finding: Multiple Database Dimension Standards

### Dimension Chaos by Table Type

**768-DIMENSION TABLES (Original/Legacy):**
```
rules (768-dim)
code_embeddings (768-dim)
code_locations (768-dim)
rag_documents (768-dim)
rag_queries → query_embedding (768-dim)
prompt_cache → query_embedding (768-dim)
tool_knowledge → embeddings (768-dim)
framework_patterns (768-dim)
semantic_patterns (768-dim)
code_examples → code_embedding (768-dim)
pattern_library → pattern_embedding (768-dim)
todos → embedding (768-dim)
```

**1536-DIMENSION TABLES (Code-specific):**
```
vector_embeddings → vector_embedding (1536-dim)
code_search_embeddings → vector_embedding (1536-dim)
knowledge_artifacts → embedding (1536-dim)
templates → embedding (1536-dim)
```

**2560-DIMENSION TABLES (Concatenated Qodo + Jina):**
```
code_chunks → embedding (halfvec 2560-dim)
code_embedding_cache → embedding (halfvec 2560-dim)
```

**Tables Modified by Migration 20250101000016 to 2560:**
```
code_embeddings (768 → 2560)
code_locations (768 → 2560)
rag_documents (768 → 2560)
rag_queries → query_embedding (768 → 2560)
prompt_cache → query_embedding (768 → 2560)
rules → embedding (768 → 2560)
knowledge_artifacts → embedding (768 → 2560)
technology_patterns → embedding (768 → 2560)
framework_patterns → embedding (768 → 2560)
semantic_patterns → embedding (768 → 2560)
tool_knowledge → embeddings (768 → 2560)
external_package_registry → semantic_embedding (768 → 2560)
external_package_registry → description_embedding (768 → 2560)
package_code_examples → code_embedding (768 → 2560)
package_usage_patterns → pattern_embedding (768 → 2560)
```

---

## 1. EMBEDDING GENERATION LAYER

### Primary Files:
- `/singularity/lib/singularity/embedding_engine.ex`
- `/singularity/lib/singularity/embedding/nx_service.ex`
- `/singularity/lib/singularity/llm/embedding_generator.ex`
- `/singularity/lib/singularity/search/unified_embedding_service.ex`

### Dimension Specifications Found:

**EmbeddingEngine (embedding_engine.ex):**
- **Line 10:** "Multi-Vector Embeddings: Qodo (1536-dim) + Jina v3 (1024-dim) = 2560-dim vectors"
- **Line 252:** `def dimension, do: 2560` - **HARDCODED 2560-dim expectation**

**NxService (nx_service.ex):**
- **Line 64:** Qodo model: `embedding_dim: 1536`
- **Line 72:** Jina v3 model: `embedding_dim: 1024`
- **Line 198:** Concatenation logic: `concatenated = Nx.concatenate([qodo_embedding, jina_embedding], axis: 0)`
- **Comment (Line 183-184):** "Multi-vector concatenation: Qodo (1536) + Jina v3 (1024) = 2560"

**EmbeddingGenerator (embedding_generator.ex):**
- **Line 264:** `def dimension(:qodo_embed), do: 1536`
- **Line 265:** `def dimension(:minilm), do: 384`
- **Line 266:** `def dimension(:jina_v3), do: 1024`
- **Lines 272-276:** GPU detection selects between Qodo (1536) and MiniLM (384) - **INCONSISTENT WITH 2560!**

**UnifiedEmbeddingService (unified_embedding_service.ex):**
- **Line 617:** Placeholder generates 384-dim (MiniLM): `embedding_size = 384`
- **Lines 308-323:** Tries to use EmbeddingEngine (should be 2560)
- **Lines 345-397:** Falls back to Bumblebee with unspecified dimensions

### PROBLEM #1: EmbeddingGenerator returns inconsistent dimensions

**Code:**
```elixir
# EmbeddingGenerator (line 247-258)
def embed(text, opts \\ []) do
  model = opts[:model] || select_best_model()  # Selects :minilm or :qodo_embed
  
  case EmbeddingEngine.embed(text, model: model) do
    {:ok, embedding} ->
      Logger.debug("Generated embedding via #{model}")
      {:ok, Pgvector.new(embedding)}  # Returns whatever EmbeddingEngine produces
end
```

**Issue:**
- EmbeddingGenerator calls EmbeddingEngine.embed with single model (:qodo_embed or :minilm)
- But EmbeddingEngine is documented to return 2560-dim (concatenated Qodo + Jina)
- select_best_model() returns `:qodo_embed` (GPU) or `:minilm` (CPU), not the concatenated option
- **No code actually produces 2560-dim embeddings!**

### PROBLEM #2: EmbeddingEngine doesn't actually generate 2560-dim

The `EmbeddingEngine.embed/2` delegates to `EmbeddingEngine.NxService.embed/2`, which:
- Takes a single model parameter
- Returns embedding for THAT model only
- Never actually concatenates Qodo + Jina

**Code path:**
```elixir
# EmbeddingEngine.embed (line 188-198)
def embed(text, opts \\ []) do
  case NxService.embed(text, opts) do
    {:ok, embedding} ->
      Logger.debug("Generated embedding")
      {:ok, Pgvector.new(embedding)}  # No concatenation!
  end
end

# NxService.embed (line 82-92)
def embed(text, opts \\ []) when is_binary(text) do
  model = Keyword.get(opts, :model, :qodo)  # Gets single model
  device = Keyword.get(opts, :device, :cpu)
  
  with {:ok, model_state} <- ModelLoader.load_model(model, device),
       {:ok, embedding} <- run_inference(text, model_state, model) do
    {:ok, embedding}  # Returns single model's embedding
  end
end
```

---

## 2. DATABASE SCHEMA LAYER

### Schema Files:
- `/singularity/lib/singularity/schemas/code_embedding_cache.ex`

### Dimension Specification:

**CodeEmbeddingCache (code_embedding_cache.ex):**
- **Line 10:** `embedding: :halfvec, size: 2560, null: false`
- **Line 40:** Comment: "halfvec(2560) - Half-precision pgvector for high-dimensional embeddings"
- **Lines 92-93:** Comment: "2560-dim embedding vector (Qodo 1536 + Jina 1024) using half-precision"

### PROBLEM #3: Migration 20250101000016 breaks consistency

**File:** `/singularity/priv/repo/migrations/20250101000016_standardize_embedding_dimensions.exs`

This migration attempts to standardize all embeddings to 2560, but:

**What it tries to convert:**
- All 768-dim columns to 2560-dim (incorrect math!)
- No validation that embeddings are actually 2560-dim

**SQL executed (example):**
```sql
ALTER TABLE code_embeddings ALTER COLUMN embedding TYPE vector(2560);
ALTER TABLE rules ALTER COLUMN embedding TYPE vector(2560);
-- etc. for ~15 tables
```

**Critical Issue:** PostgreSQL doesn't re-generate embeddings during ALTER TYPE!
- If embeddings are 768-dim floats, changing TYPE to vector(2560) doesn't produce 2560-dim data
- The existing 768-dim data is silently truncated or causes errors on insert
- **This migration is corrupted!**

### PROBLEM #4: Multiple dimension standards in active tables

**table: code_chunks** (newer):
- Migration 20251024220730: `embedding: :halfvec, size: 2560`
- Uses halfvec for 4000-dim support

**table: code_embedding_cache** (newest):
- Migration 20251024220740: `embedding: :halfvec, size: 2560`
- Same halfvec 2560-dim setup

**table: knowledge_artifacts** (mixed):
- Migration 20251006112622: `embedding: :vector, size: 1536`
- NOT converted by standardization migration
- **Uses 1536 vs expected 2560!**

**table: templates** (mixed):
- Migration 20251006120000: `embedding: :vector, size: 1536`
- NOT converted by standardization migration
- **Uses 1536 vs expected 2560!**

---

## 3. MIGRATION HISTORY & INCONSISTENCIES

### Timeline of changes:

1. **20240101000002+ migrations:** Create tables with 768-dim embeddings
2. **20250101000016:** Attempt to standardize all to 2560-dim (BROKEN)
3. **20250101000020:** Creates code_search tables with 1536-dim (NEW STANDARD)
4. **20251006112622:** Creates knowledge_artifacts with 1536-dim (NEW STANDARD)
5. **20251006120000:** Creates templates with 1536-dim (NEW STANDARD)
6. **20251024220730:** Creates code_chunks with 2560-dim halfvec
7. **20251024220740:** Creates code_embedding_cache with 2560-dim halfvec (NEWEST)

### Migration Status by Phase:

**Phase 1 (Original):** 768-dim everywhere
**Phase 2 (Broken):** Migration 20250101000016 claims 2560-dim but doesn't update data
**Phase 3 (Partial):** Mix of 768, 1536, 2560
**Phase 4 (Newest):** New tables use 2560 halfvec

---

## 4. VALIDATION LAYER

### Validation File:
- `/singularity/lib/singularity/embedding/validation.ex`

### What it checks:
- Model loading from HuggingFace
- Inference quality
- Fine-tuning convergence
- Performance benchmarking

### What it DOESN'T check:
- Actual dimension of produced embeddings
- Consistency between generation and storage
- Whether stored embeddings match expected dimensions

---

## 5. USAGE SITES & MISMATCH POINTS

### Places that generate embeddings:

1. **code.ingest.ex** (line 161):
```elixir
case EmbeddingGenerator.embed(content) do
```
- Expects: Unknown dimension
- Actually gets: Single model (1536 or 384), not 2560

2. **templates.ex** (line 240):
```elixir
case Singularity.EmbeddingEngine.embed(search_text, model: :qodo_embed) do
```
- Explicitly requests `:qodo_embed` only (1536-dim)
- Stores in templates table (which expects 1536)
- **Actually correct for 1536 tables!**

3. **package_registry_collector.ex** (multiple places):
```elixir
{:ok, description_embedding} = Singularity.EmbeddingGenerator.embed(description)
{:ok, semantic_embedding} = Singularity.EmbeddingGenerator.embed(semantic_text)
```
- Calls EmbeddingGenerator (inconsistent dimension source)
- Stores in external_package_registry

4. **pattern_store.ex** (line 142):
```elixir
{:ok, embedding} <- EmbeddingGenerator.embed(description)
```
- Calls EmbeddingGenerator
- No validation of dimension

5. **framework_pattern_store.ex**:
```elixir
{:ok, embedding} = Singularity.EmbeddingGenerator.embed(query_text)
```
- Same issue

6. **technology_pattern_store.ex**:
```elixir
{:ok, embedding} = Singularity.EmbeddingGenerator.embed(query_text)
```
- Same issue

---

## 6. MODEL LOADER LAYER

### File:
- `/singularity/lib/singularity/embedding_model_loader.ex`

### Dimension specifications:

**Lines 123-133 (Jina v3):**
```elixir
"jina_v3" ->
  {:ok, %{
    name: "jina_v3",
    type: :text,
    dimension: 1024,  # ← Correct for Jina
    max_context: 8192,
    status: :available
  }}
```

**Lines 135-145 (Qodo-Embed):**
```elixir
"qodo_embed" ->
  {:ok, %{
    name: "qodo_embed",
    type: :code,
    dimension: 1536,  # ← Correct for Qodo
    max_context: 32768,
    status: :available
  }}
```

**Lines 152-160 (get_model_dimension/1):**
```elixir
defp get_model_dimension(model_name) do
  case model_name do
    "jina_v3" -> 1024
    "qodo_embed" -> 1536
    _ -> 1536
  end
end
```

**ISSUE:** These dimension functions are never called or used!
- EmbeddingModelLoader returns model info with correct dimensions
- But callers don't use these to validate embeddings

---

## 7. ROOT CAUSES

### Root Cause #1: Design Mismatch
- **Spec says:** Concatenate Qodo (1536) + Jina (1024) = 2560-dim
- **Code does:** Return single model embeddings (1536 or 384)
- **Never implemented:** Actual concatenation in EmbeddingGenerator/EmbeddingEngine

### Root Cause #2: Database Schema Corruption
- Migration 20250101000016 tries to change type from vector(768) to vector(2560)
- **But:** Doesn't re-generate embeddings with new dimensions
- **Result:** Stored embeddings don't match schema expectations

### Root Cause #3: Inconsistent Standards Adoption
- Some new tables (code_chunks, code_embedding_cache) use 2560-dim
- Other tables (knowledge_artifacts, templates) use 1536-dim
- Old tables may have 768-dim data with 2560-dim schema

### Root Cause #4: No Dimension Validation
- No code validates embedding dimensions before storing
- No code validates dimensions when reading
- Stored embeddings could be wrong dimension with no error

### Root Cause #5: Backward Compatibility Lost
- Old code generates 768-dim (or 1536-dim in some cases)
- New schema expects 2560-dim
- Queries will fail with dimension mismatch

---

## 8. IMPACT ASSESSMENT

### Immediate Breakage Points:

1. **EmbeddingGenerator.embed() calls:**
   - Returns 1536 or 384 dims
   - Expected to be 2560 by new tables
   - **Breaks queries on:** code_chunks, code_embedding_cache

2. **Database migrations:**
   - Migration 20250101000016 may have corrupted existing data
   - Reading old tables could return wrong dimensions
   - **Affected tables:** code_embeddings, rag_documents, rules, etc.

3. **Semantic search:**
   - similarity() calculations expect consistent dimensions
   - Comparing 1536-dim to 2560-dim vectors = invalid
   - **Broken:** All search functions using EmbeddingGenerator

4. **Model fine-tuning:**
   - EmbeddingQualityTracker fine-tunes on 2560-dim embeddings
   - But training data may be 1536 or 384-dim
   - **Breaks:** Learning loop from EmbeddingQualityTracker

---

## 9. PRIORITY FIXES NEEDED

### CRITICAL (BLOCKING):

1. **Fix EmbeddingEngine to actually generate 2560-dim**
   - Implement concatenation of Qodo + Jina in NxService
   - OR change spec to single model (1536-dim) throughout
   - OR add explicit option to select behavior

2. **Fix EmbeddingGenerator dimension handling**
   - Either:
     - Option A: Return 2560-dim by concatenating both models
     - Option B: Return single model (1536) and update schema to match
     - Choose ONE strategy and stick with it

3. **Fix database schema corruption**
   - Create new migration to validate/fix actual data
   - Check dimensions of stored embeddings
   - Either re-generate or truncate to correct dimension
   - Document what happened

4. **Standardize all tables to one dimension**
   - Audit all embedding columns
   - Choose: 1536-dim (code-optimized) or 2560-dim (concatenated)
   - Update all migrations
   - Update all storage code

### HIGH (URGENT):

5. **Add embedding dimension validation**
   - Validate dimension before storing: `ensure_embedding_dim(embedding, expected_dims)`
   - Log mismatches as errors
   - Add to all write paths

6. **Add embedding dimension metadata**
   - Store which model/strategy generated each embedding
   - Store actual dimensions in metadata column
   - For troubleshooting and recovery

7. **Fix migration 20250101000016**
   - Either revert it
   - Or create follow-up migration to re-generate embeddings correctly
   - Document why type changed but data didn't

8. **Consolidate embedding generation**
   - Remove UnifiedEmbeddingService if not used
   - Clarify which embedding service is canonical
   - One clear path for all code

### MEDIUM (IMPORTANT):

9. **Add integration tests**
   - Test end-to-end: generate → store → retrieve → search
   - Validate dimensions at each step
   - Test with realistic data volumes

10. **Document embedding strategy**
    - Write clear spec for which dimension each table should use
    - Document why (code vs general text vs concatenated)
    - Update CLAUDE.md

---

## 10. DETECTION CHECKLIST

### What to check in database:

```sql
-- Check actual dimensions of stored embeddings
SELECT 
  'code_embeddings' as table_name,
  COUNT(*) as count,
  MAX(array_length(embedding, 1)) as max_dim,
  MIN(array_length(embedding, 1)) as min_dim
FROM code_embeddings;

-- Check all embedding columns across all tables
SELECT 
  table_name,
  column_name,
  udt_name as type,
  udt_schema
FROM information_schema.columns
WHERE column_name LIKE '%embedding%'
  AND table_name NOT LIKE 'pg_%'
ORDER BY table_name;

-- Check schema expectations vs reality
SELECT 
  t.table_name,
  c.column_name,
  c.udt_name,
  c.numeric_precision  -- For vector dimensions
FROM information_schema.tables t
JOIN information_schema.columns c 
  ON t.table_name = c.table_name
WHERE c.column_name LIKE '%embedding%'
  AND t.table_schema = 'public'
ORDER BY t.table_name;
```

### What to check in code:

1. Search for all calls to `EmbeddingGenerator.embed`
2. Search for all calls to `EmbeddingEngine.embed`
3. Search for all calls to `UnifiedEmbeddingService`
4. Check each site for dimension validation
5. Check each storage path for dimension mismatch

---

## 11. RECOMMENDED RESOLUTION PATH

### Option A: Standardize on 1536-dim (Code-Optimized)
- **Pro:** Simpler, one model, code-optimized, faster
- **Con:** Lose general text understanding from Jina
- **Work:** 
  - Revert migration 20250101000016
  - Update all schema to 1536
  - Fix EmbeddingEngine to use Qodo only
  - Delete concatenation code

### Option B: Standardize on 2560-dim (Concatenated)
- **Pro:** Best quality (both models), proven in newer tables
- **Con:** 2x inference time, 2x storage, slower searches
- **Work:**
  - Fix EmbeddingEngine to actually concatenate
  - Fix EmbeddingGenerator to return 2560
  - Re-generate all old embeddings
  - Update migration 20250101000016 to re-generate data
  - Add batch job to migrate existing vectors

### Option C: Hybrid (Use Both, Choose Per Case)
- **Pro:** Flexibility
- **Con:** Most complex, requires dimension tracking
- **Work:**
  - Add embedding_dimensions column to every embedding table
  - Make EmbeddingGenerator configurable
  - Update all queries to validate dimension
  - Add clear guidelines for which to use when

**RECOMMENDATION:** Option A (1536-dim Qodo only)
- Simpler implementation
- Code is already mostly there (embedded tables already use 1536)
- Cleaner to maintain
- "Good enough" quality for internal tooling
- Faster inference and smaller storage

---

## Summary Table

| Issue | Severity | Files Affected | Lines | Fix Complexity |
|-------|----------|---|---|---|
| EmbeddingGenerator returns wrong dims | CRITICAL | embedding_generator.ex | 247-283 | HIGH |
| EmbeddingEngine never concatenates | CRITICAL | embedding_engine.ex, nx_service.ex | 188-198, 182-220 | HIGH |
| Migration corrupts data | CRITICAL | 20250101000016 | all | MEDIUM |
| Mixed schema dimensions | CRITICAL | Multiple migration files | Many | VERY HIGH |
| No dimension validation | HIGH | 20+ files | Throughout | MEDIUM |
| Broken fine-tuning | HIGH | embedding_finetune_job.ex, embedding_quality_tracker.ex | Many | HIGH |
| Inconsistent model selection | MEDIUM | unified_embedding_service.ex | 230-280 | MEDIUM |

---

## Files Requiring Changes

### Code Changes (7 files):
1. `/singularity/lib/singularity/embedding_engine.ex`
2. `/singularity/lib/singularity/embedding/nx_service.ex`
3. `/singularity/lib/singularity/llm/embedding_generator.ex`
4. `/singularity/lib/singularity/search/unified_embedding_service.ex`
5. `/singularity/lib/singularity/jobs/embedding_finetune_job.ex`
6. `/singularity/lib/singularity/search/embedding_quality_tracker.ex`
7. `/singularity/lib/singularity/embedding/validation.ex`

### Database Migrations (Need Fixing):
1. `/singularity/priv/repo/migrations/20250101000016_standardize_embedding_dimensions.exs` (BROKEN)
2. All initial creation migrations (20240101000002-005)
3. New migrations (20251024...)

### Configuration:
1. `/singularity/config/config.exs` - Add embedding dimension config

### Documentation:
1. `/CLAUDE.md` - Update embedding section
2. New file: `/EMBEDDING_STRATEGY.md` - Define standard

