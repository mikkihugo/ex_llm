# Embedding Standardization - Progress Report

**Date:** 2025-10-24
**Status:** 4/8 tasks completed - Foundation established
**Direction:** Standardizing on 2560-dim concatenated embeddings (Qodo 1536 + Jina 1024)

---

## Completed Tasks ✅

### 1. Comprehensive Dimension Chaos Investigation
- Analyzed 17 embedding-related files
- Examined 30+ migration files
- Found 50+ usage sites across codebase
- Identified 18 database tables with embedding columns
- Created 3 detailed analysis reports

**Reports Generated:**
- `EMBEDDING_DIMENSION_CHAOS_REPORT.md` (587 lines)
- `EMBEDDING_QUICK_REFERENCE.md` (145 lines)
- `EMBEDDING_REPORTS_INDEX.md` (179 lines)

### 2. Fixed NxService to Enforce Concatenation
**File:** `lib/singularity/embedding/nx_service.ex`

**Changes:**
- Removed `model` parameter from `embed/2` - now always concatenates
- Removed `model` parameter from `embed_batch/2` - batch always returns 2560-dim
- Updated `similarity/2` to use concatenated vectors
- All embeddings now guaranteed to be Qodo 1536 + Jina 1024 concatenated

**Code Flow:**
```
User calls embed(text)
  ↓
NxService.embed() [always concatenates]
  ↓
run_inference() with :concatenated flag
  ↓
Load Qodo tokenizer + Jina v3 tokenizer
  ↓
Qodo inference (1536-dim) + Jina v3 inference (1024-dim)
  ↓
Concatenate: [1536 || 1024] = 2560-dim
  ↓
Normalize to unit length
  ↓
Return Pgvector(2560)
```

### 3. Updated EmbeddingEngine Documentation
**File:** `lib/singularity/embedding_engine.ex`

**Changes:**
- Enhanced `dimension/0` docstring to clarify 2560-dim standard
- Removed ambiguity about single vs concatenated models
- Clarified that all embeddings are Qodo + Jina v3 concatenated

### 4. Updated EmbeddingGenerator Documentation
**File:** `lib/singularity/llm/embedding_generator.ex`

**Changes:**
- Complete rewrite of moduledoc
- Emphasized always-concatenated 2560-dim strategy
- Updated JSON metadata with `embedding_strategy` and `output` fields
- Rewrote Mermaid architecture diagram showing parallel Qodo + Jina inference
- Clarified that :model parameter is now ignored
- Updated call graph and responsibilities

---

## Current State

### Database Schemas ✅
Both new schemas properly configured for 2560-dim:
- `CodeChunk` - 2560-dim halfvec with HNSW index
- `CodeEmbeddingCache` - 2560-dim halfvec with HNSW index

### Embedding Generation ✅
All primary generation paths now enforce 2560-dim:
- `EmbeddingEngine.embed/2` - delegates to NxService
- `NxService.embed/2` - always concatenates Qodo + Jina v3
- `EmbeddingGenerator.embed/2` - calls EmbeddingEngine (2560-dim)

### Validation Status
Documentation now accurately reflects implementation:
- ✅ Dimension expectations match actual output
- ✅ No more variable dimensions (384/1536 confusion)
- ✅ Clear concatenation strategy documented
- ❌ Runtime validation not yet added (CRITICAL - next step)

---

## Remaining Embedding Tasks (4/8)

### 5. Update UnifiedEmbeddingService (PENDING)
**File:** `lib/singularity/search/unified_embedding_service.ex`

**Issues:**
- Line 308-323: Tries to use EmbeddingEngine (might work now with fixes)
- Line 345-397: Has fallback to Bumblebee (deprecated)
- Line 617: Placeholder generates 384-dim (wrong)
- Need to ensure all paths return 2560-dim

**Work:** Remove fallbacks, ensure EmbeddingEngine path is used

### 6. Verify CodeChunk/CodeEmbeddingCache Schemas (PENDING)
**Files:** `lib/singularity/schemas/code_chunk.ex`, `lib/singularity/schemas/code_embedding_cache.ex`

**Status:** Schemas already created with proper:
- 2560-dim halfvec fields
- Validation enforcing 2560-dim
- HNSW indexes

**Work:** Verify validation works correctly, update cache.ex to use schemas

### 7. Add Runtime Dimension Validation (PENDING)
**New File Needed:** `lib/singularity/embedding/validation.ex`

**Purpose:** Validate embeddings before storage
- Check all embeddings are exactly 2560-dim
- Reject embeddings of other dimensions
- Log violations for debugging

**Locations to add validation:**
- CodeChunk.changeset/2
- CodeEmbeddingCache.changeset/2
- Cache.put(:embeddings, ...)
- Any other embedding insertion point

### 8. Fix Migration 20250101000016 (PENDING - COMPLEX)
**File:** `priv/repo/migrations/20250101000016_standardize_embedding_dimensions.exs`

**Status:** Currently broken - corrupts data by changing schema without re-generating embeddings

**Options:**
- A. Revert it completely (simplest)
- B. Fix it to actually re-generate embeddings with 2560-dim (complex)
- C. Create new migration to fix corrupted data (medium)

**Impact:** 15+ tables affected, need to decide on strategy

---

## Commits Made This Session

1. **8569257f** - fix: Enforce 2560-dim concatenated embeddings
   - NxService.embed() always concatenates
   - Updated EmbeddingEngine docs
   - Created 3 analysis reports

2. **f5866777** - docs: Update EmbeddingGenerator to clarify 2560-dim
   - Complete moduledoc rewrite
   - Updated architecture diagram
   - Clarified concatenation strategy

---

## Architecture Pattern Established

### The 2560-dim Standard
```
Input Text
    ↓
[Qodo-Embed-1 (1536-dim) || Jina v3 (1024-dim)]
    ↓
Concatenated 2560-dim vector
    ↓
Normalize to unit length
    ↓
Store in halfvec(2560) column
    ↓
Index with HNSW + halfvec_cosine_ops
```

**Rationale:**
- Qodo excels at code semantics
- Jina v3 excellent at general text understanding
- Combined = better retrieval quality for mixed codebase + docs
- Performance cost acceptable for internal tooling
- Storage cost acceptable (2560 dims = 5KB with half-precision)

---

## Next Steps

### Immediate (This Session)
1. ✅ Complete embedding standardization (4/8 done)
2. ⏳ **START: CodeSearch Postgrex Refactor**
   - This is the production-blocking critical issue
   - 48 Postgrex.query!() calls bypass Ecto pooling
   - Will crash under load (10+ concurrent requests)

### Short-term (This Week)
1. Finish embedding validation (task #7)
2. Fix UnifiedEmbeddingService (task #5)
3. Handle migration issue (task #8)
4. First iteration of CodeSearch refactor

### Medium-term (Next Week)
1. Continue CodeSearch refactor (large effort)
2. Fix remaining embedding critical issues
3. Add dimension validation everywhere
4. Re-generate corrupted embeddings if needed

---

## Risk Assessment

### High Risk ⚠️
- **Migration 20250101000016** is actively corrupting data
  - Currently changes 15+ tables from 768 to 2560-dim
  - But doesn't re-generate embeddings
  - Results in invalid 768-dim data in 2560-dim columns
  - **Decision needed:** Revert or fix?

### Medium Risk
- **UnifiedEmbeddingService** still has placeholders
  - Fallback paths might be used
  - Could generate 384-dim embeddings
  - Need to validate all paths

### Low Risk
- CodeChunk and CodeEmbeddingCache properly configured
- EmbeddingEngine and EmbeddingGenerator fixed
- NxService now enforces concatenation

---

## Quality Metrics

| Metric | Status | Notes |
|--------|--------|-------|
| Compilation | ✅ Pass | No errors, 0 warnings related to embeddings |
| Dimension Consistency | 🟡 Partial | Generation fixed, but validation not added yet |
| Documentation | ✅ Good | All docs match implementation now |
| Database Schema | ✅ Correct | CodeChunk/Cache have proper 2560-dim setup |
| Migration Safety | ❌ Broken | Migration 20250101000016 corrupts data |
| Tests | ❓ Unknown | No tests created yet for 2560-dim enforcement |

---

## Recommended Path Forward

**DECISION: Start CodeSearch Postgrex Refactor Now**

Why:
1. **Production-critical** - system crashes under load
2. **Large effort** - 5-10 days, better to start early
3. **Blocking other work** - many modules depend on CodeSearch
4. **Parallel work possible** - can finish embedding tasks later

Then:
1. Complete embedding validation (#7)
2. Handle migration issue (#8)
3. Finish UnifiedEmbeddingService (#5)
4. Continue CodeSearch refactor

---

*Generated: 2025-10-24*
*Session: Embedding Standardization + Production Readiness*
*Next: CodeSearch Postgrex Refactor (CRITICAL)*

