# Embedding Dimension Chaos - Complete Analysis

This folder contains a comprehensive analysis of the embedding dimension inconsistencies in the Singularity codebase.

## Reports in This Analysis

### 1. EMBEDDING_QUICK_REFERENCE.md (START HERE)
**Best for:** Quick understanding, decision-making, action items
- One-sentence problem statement
- Key files by severity
- Dimension standards by table type
- Quick SQL checks
- Decision tree
- Fix checklist

**Read time:** 5 minutes
**Use case:** Understanding scope and priority

### 2. EMBEDDING_DIMENSION_CHAOS_REPORT.md (DETAILED)
**Best for:** Understanding root causes, implementation details, full context
- Executive summary with tables
- Detailed analysis of all 4 generation layers
- Schema corruption specifics
- Migration timeline and issues
- All usage sites and breakage points
- Root cause analysis (5 major causes)
- Impact assessment
- 10 priority fixes with severity
- 11 recommended resolution paths
- Summary table of all issues

**Read time:** 45 minutes
**Use case:** Implementation planning, root cause analysis

## Key Findings Summary

### The Problem
- **Generation layer:** Code produces 1536 or 384-dim embeddings
- **Schema layer:** Tables expect 768, 1536, or 2560 dims (depending on age)
- **Migration layer:** Broken migration tries to change 768 to 2560 without updating data
- **Validation layer:** No code validates dimensions, mismatches are silent

### Severity
- **CRITICAL:** 4 issues blocking functionality
- **HIGH:** 4 issues causing data corruption risk
- **MEDIUM:** 3 issues affecting code quality

### Impact
- Semantic search broken (dimension mismatches)
- Fine-tuning broken (training data dimension mismatch)
- New table inserts failing (dimension validation)
- Old tables corrupted (schema mismatch with data)

## Files to Change

### Immediately (This Week)
1. `/singularity/lib/singularity/llm/embedding_generator.ex` - CRITICAL
2. `/singularity/lib/singularity/embedding_engine.ex` - CRITICAL
3. `/singularity/lib/singularity/embedding/nx_service.ex` - CRITICAL
4. `/singularity/priv/repo/migrations/20250101000016_standardize_embedding_dimensions.exs` - CRITICAL

### Soon (Week 2-3)
5. `/singularity/lib/singularity/search/unified_embedding_service.ex` - HIGH
6. `/singularity/lib/singularity/jobs/embedding_finetune_job.ex` - HIGH
7. `/singularity/lib/singularity/search/embedding_quality_tracker.ex` - HIGH
8. `/singularity/lib/singularity/embedding/validation.ex` - HIGH

### Config & Docs (Week 4+)
9. `/singularity/config/config.exs` - Add embedding configuration
10. `/CLAUDE.md` - Update embedding section
11. New file: `/EMBEDDING_STRATEGY.md` - Document chosen standard

## Decision Required

**Option A: 1536-dim (Qodo-only, RECOMMENDED)**
- Simpler to implement
- Faster inference
- Less storage
- Code-optimized
- Recommended for internal tooling

**Option B: 2560-dim (Qodo + Jina, concatenated)**
- Better quality (both models)
- Slower inference (2x time)
- More storage (2x)
- More complex to implement

**Option C: Hybrid (flexible, most complex)**
- Different dimensions for different use cases
- Requires dimension tracking
- Most maintenance burden

## How to Use These Reports

### For Quick Problem Understanding
1. Read EMBEDDING_QUICK_REFERENCE.md
2. Look at "Decision Tree" section
3. Check "What's Broken Right Now"

### For Implementation Planning
1. Read EMBEDDING_DIMENSION_CHAOS_REPORT.md Section 9 (Priority Fixes)
2. Check "Files Requiring Changes"
3. Use Timeline section for sprint planning

### For Root Cause Analysis
1. Read EMBEDDING_DIMENSION_CHAOS_REPORT.md Section 7 (Root Causes)
2. Review code sections showing mismatches
3. Check Section 8 (Impact Assessment)

### For Database Debugging
1. Use SQL queries in EMBEDDING_QUICK_REFERENCE.md
2. Cross-reference with tables in detailed report
3. Check Section 2 (Database Schema Layer)

### For Code Changes
1. Use file list in EMBEDDING_QUICK_REFERENCE.md
2. Jump to specific file sections in detailed report
3. Find line numbers and code examples

## Dimension Reference

### Current Database State
```
768-dim:  rules, code_embeddings, code_locations, rag_documents, etc.
1536-dim: vector_embeddings, knowledge_artifacts, templates
2560-dim: code_chunks, code_embedding_cache
```

### Model Dimensions
```
Qodo-Embed-1:    1536-dim (code-optimized)
Jina v3:         1024-dim (general text)
MiniLM-L6-v2:    384-dim  (lightweight CPU fallback)
Concatenated:    2560-dim (Qodo + Jina combined)
```

### Generation vs Storage Mismatch
```
Generated:   1536 or 384 dims
Expected:    2560 dims (new tables) or 768 dims (old tables)
Status:      BROKEN - mismatch on all new tables
```

## Next Steps

### This Week
- [ ] Read both reports
- [ ] Make decision on dimension standard (A, B, or C)
- [ ] Create task/issue for each critical fix
- [ ] Block writes to new 2560-dim tables

### Week 2-3
- [ ] Implement dimension fix in EmbeddingEngine/EmbeddingGenerator
- [ ] Fix migration 20250101000016
- [ ] Add dimension validation to storage
- [ ] Create fix-up migration for old data

### Week 4+
- [ ] Re-generate or migrate embeddings
- [ ] Add integration tests
- [ ] Update CLAUDE.md
- [ ] Deploy fixes

## Contact for Questions

These reports were generated by comprehensive search of:
- 17 core embedding-related files
- 30+ migration files
- 50+ usage sites
- Database schema definitions
- Model specifications

All line numbers and file paths are exact and verified.

---

**Generated:** October 24, 2025
**Analysis Scope:** Complete embedding infrastructure (generation, storage, usage, fine-tuning)
**Status:** COMPREHENSIVE - All critical areas covered
