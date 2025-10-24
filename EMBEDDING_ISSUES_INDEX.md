# Embedding System Issues - Complete Index

## Reports Generated

### 1. EMBEDDING_ISSUES_COMPREHENSIVE_REPORT.md (Main Report)
- **Size:** Full detailed analysis
- **Contains:** 26 issues organized by severity
- **Includes:** 
  - Detailed problem descriptions
  - Code snippets showing issues
  - Impact analysis
  - Suggested fixes
  - Recommended action plan

**Use this for:** Deep analysis, understanding root causes, comprehensive fixes

### 2. EMBEDDING_ISSUES_QUICK_REFERENCE.md (Quick Guide)
- **Size:** Concise reference
- **Contains:** Critical issues summary
- **Includes:**
  - Top 8 critical issues with fix times
  - Testing scripts to verify issues
  - File organization overview
  - Quick fixes
  - Success metrics

**Use this for:** Quick lookup, prioritization, rapid testing

---

## Issues Summary by Severity

### CRITICAL (8 issues) - 18-22 hours to fix
1. Bumblebee placeholder implementations (4-6 hours)
2. Model training evaluation not implemented (3-4 hours)
3. Weight saving not implemented (3-4 hours)
4. Hash-based fallback embeddings (3-4 hours)
5. Quality tracker SQL issues (4-5 hours)
6. Fine-tune job mock data (2-3 hours)
7. Embedding dimension chaos (8-12 hours)
8. ONNX loading not implemented (3-4 hours)

### HIGH (9 issues) - 12-15 hours to fix
9. Gradient computation inefficient (4-5 hours)
10. Quality tracker incomplete redesign (6-8 hours)
11. Code search dimension mismatches (3-4 hours)
12. Fine-tune job poor data collection (variable)
13. Tokenizer placeholder (2-3 hours)
14. Model loader mock state fallback (2-3 hours)
15. MiniLM fake embeddings (1-2 hours)
16-18. Various incomplete modules (varies)

### MEDIUM (6 issues)
19. AutomaticDifferentiation incomplete
20. Service incomplete
21. Validation testing mocks
22. Training step gradient approximation
23. EmbeddingModelLoader mock validation
24. Double Pgvector wrapping

### LOW (4 issues)
25. Database migration rollback issues
26. Orphaned serverless_embeddings.ex
27. Unused serialization functions
28. Missing configuration endpoints

---

## Critical Files to Fix (Priority Order)

### Tier 1: Foundational (Must Fix First)
1. `singularity/lib/singularity/embedding/nx_service.ex`
   - Remove hash-based fallback (lines 182-246)
   - Either implement real inference or fail explicitly

2. `singularity/lib/singularity/search/unified_embedding_service.ex`
   - Remove or implement Bumblebee placeholders (lines 556-659)
   - Remove MiniLM fake embeddings

3. `singularity/lib/singularity/embedding/model_loader.ex`
   - Implement checkpoint loading (lines 48-60)
   - Implement ONNX loading (lines 145-190)
   - Remove mock state fallback

### Tier 2: Training (Fix Second)
4. `singularity/lib/singularity/embedding/trainer.ex`
   - Implement evaluate() function (line 145)
   - Implement weight saving (line 220)

5. `singularity/lib/singularity/jobs/embedding_finetune_job.ex`
   - Remove mock data augmentation (lines 119-136)
   - Implement real data collection validation

### Tier 3: Search (Fix Third)
6. `singularity/lib/singularity/search/embedding_quality_tracker.ex`
   - Fix SQL issues (lines 304-361)
   - Remove Bumblebee/Axon attempts
   - Simplify to just feedback recording

7. `singularity/lib/singularity/search/code_search.ex`
   - Update for 2560-dim embeddings
   - Fix vector index queries

### Tier 4: Database/Config (Fix Fourth)
8. Database migrations
   - Standardize all to 2560-dim
   - Fix vector indexes

9. Configuration
   - Expose fine-tuning endpoints
   - Add device detection config

---

## Testing Checklist

### Before Fixes
- [ ] Document current embedding behavior
- [ ] Create test suite for baseline
- [ ] Verify mock/fallback usage

### During Fixes
- [ ] Test each module independently
- [ ] Verify no regressions
- [ ] Check database constraints

### After Fixes
- [ ] All embeddings 2560-dim
- [ ] Deterministic behavior
- [ ] Similarity scores consistent
- [ ] Vector search working
- [ ] Fine-tuning on real data
- [ ] Models persist correctly
- [ ] Quality tracking works

---

## Dependencies Between Issues

```
Issue #7 (Dimensions) 
  └─> Issue #9 (NxService fallback)
  └─> Issue #11 (Code Search)
  └─> All database migrations

Issue #1 (Bumblebee)
  └─> Issue #9 (Unified service strategy)

Issue #2,#3 (Training)
  └─> Issue #13 (Gradient computation)
  └─> Issue #19 (Fine-tune job data)

Issue #5 (Quality Tracker)
  └─> Issue #10 (Complete rearchitect)

Issue #6 (Fine-tune mock data)
  └─> Issue #19 (Data collection)
```

---

## Performance Impact

### Current State
- Hash-based fallbacks: 0ms (but wrong)
- Real inference: Not working
- Training: 100x slower than needed
- Similarity search: Broken
- Data collection: Using 90% fake data

### After Fixes
- Real inference: 15-40ms per embedding
- Batch inference: 100-500ms for 100 texts
- Training: Reduced by 100x with autodiff
- Similarity search: Accurate with 2560-dim
- Data collection: Real codebase patterns

---

## Related Documentation

- `CLAUDE.md` - Project overview and guidelines
- `singularity/lib/singularity/embedding/` - Implementation directory
- `singularity/lib/singularity/search/` - Search integration
- `singularity/priv/repo/migrations/` - Database schema

---

## Key Numbers

- **Files affected:** 15
- **Critical issues:** 8
- **Total issues:** 26
- **Lines of problematic code:** ~1500
- **Estimated fix time:** 38-47 hours
- **Test coverage needed:** TBD

---

## Issue Lookup by File

| File | Issues | Severity |
|------|--------|----------|
| `embedding/nx_service.ex` | #4, #7 | CRITICAL |
| `search/unified_embedding_service.ex` | #1, #16 | CRITICAL |
| `embedding/trainer.ex` | #2, #3 | CRITICAL |
| `embedding/model_loader.ex` | #3, #5, #6 | CRITICAL |
| `search/embedding_quality_tracker.ex` | #5, #7, #10 | CRITICAL |
| `jobs/embedding_finetune_job.ex` | #6, #8, #11 | CRITICAL |
| Database migrations | #7, #9 | CRITICAL |
| `embedding/training_step.ex` | #13 | MEDIUM |
| `search/code_search.ex` | #9, #11 | HIGH |
| `embedding/tokenizer.ex` | #14 | MEDIUM |
| `embedding/automatic_differentiation.ex` | #17 | MEDIUM |
| `embedding/service.ex` | #18 | MEDIUM |
| `embedding_model_loader.ex` | #21 | LOW |
| `embedding_generator.ex` | #22 | LOW |

---

## Next Steps

1. Read EMBEDDING_ISSUES_COMPREHENSIVE_REPORT.md for full details
2. Use EMBEDDING_ISSUES_QUICK_REFERENCE.md for quick lookup
3. Start with Tier 1 files in order
4. Run tests from quick reference guide
5. Track progress in checklist
6. Update this index as you fix issues
