# Embedding System Issues - Quick Reference Guide

## Critical Issues (Fix First)

### Issue #1: Bumblebee Placeholder (Line 556-659)
- **File:** `singularity/lib/singularity/search/unified_embedding_service.ex`
- **Problem:** All Bumblebee embedding functions return fake 384-dim random vectors
- **Status:** BROKEN - DO NOT USE
- **Fix Time:** 4-6 hours

### Issue #2: Model Training Not Implemented (Trainer.ex)
- **File:** `singularity/lib/singularity/embedding/trainer.ex`
- **Problems:**
  - Line 145: TODO - evaluate() not implemented
  - Line 220: TODO - weight saving not implemented
- **Status:** INCOMPLETE
- **Fix Time:** 3-4 hours

### Issue #3: Checkpoint Loading Not Implemented
- **File:** `singularity/lib/singularity/embedding/model_loader.ex:48-60`
- **Problem:** Always reloads base models, can't load fine-tuned checkpoints
- **Status:** BROKEN
- **Fix Time:** 2-3 hours

### Issue #4: Hash-Based Fallback Embeddings (NxService)
- **File:** `singularity/lib/singularity/embedding/nx_service.ex:182-246`
- **Problem:** Falls back to hash-based random vectors instead of real inference
- **Impact:** Non-deterministic embeddings, broken similarity search
- **Status:** BROKEN
- **Fix Time:** 3-4 hours

### Issue #5: Quality Tracker SQL Issues
- **File:** `singularity/lib/singularity/search/embedding_quality_tracker.ex:304-361`
- **Problems:**
  - Hard-coded SQL with wrong table/schema
  - References non-existent Feedback schema
  - Metadata serialization fragile
- **Status:** BROKEN
- **Fix Time:** 4-5 hours

### Issue #6: Fine-tune Job Uses Mock Data
- **File:** `singularity/lib/singularity/jobs/embedding_finetune_job.ex:119-136`
- **Problem:** When real triplets < 10, augments with 100% fake data
- **Impact:** Model learns from synthetic patterns, not actual code
- **Status:** BROKEN
- **Fix Time:** 2-3 hours

### Issue #7: Embedding Dimension Chaos
- **Files:** Multiple (see full report)
- **Problem:** 2560, 1536, 1024, 384-dim vectors all mixed together
- **Impact:** pgvector operations fail, similarity search broken
- **Status:** CRITICAL - AFFECTS ALL SEARCH
- **Fix Time:** 8-12 hours

### Issue #8: ONNX Loading Not Implemented
- **File:** `singularity/lib/singularity/embedding/model_loader.ex:145-190`
- **Problem:** TODO - Load via Ortex when available (never happens)
- **Impact:** Jina v3 model not loadable
- **Status:** BROKEN
- **Fix Time:** 3-4 hours

---

## High Priority Issues

### Gradient Computation Too Slow (TrainingStep.ex)
- **Problem:** Uses finite differences (O(n) passes) instead of autodiff (O(1))
- **Impact:** Training 100x slower than necessary
- **Fix Time:** 4-5 hours

### Quality Tracker Incomplete (search/embedding_quality_tracker.ex)
- **Problem:** Tries to use non-existent Bumblebee/Axon APIs
- **Impact:** Self-learning loop completely non-functional
- **Fix Time:** 6-8 hours (rearchitect)

### Code Search Broken (code_search.ex)
- **Problem:** Dimension mismatches with vector indexes
- **Impact:** Semantic search returns wrong results or errors
- **Fix Time:** 3-4 hours

---

## Testing the Issues

### Test #1: Check Actual Embeddings
```elixir
# If this returns 384-dim vector with all random values, it's using fallback
{:ok, emb} = Singularity.EmbeddingEngine.embed("def hello")
IO.inspect(Pgvector.to_list(emb) |> length())  # Should be 2560
```

### Test #2: Check Determinism
```elixir
# Run twice, should get same vector
{:ok, emb1} = Singularity.EmbeddingEngine.embed("test")
{:ok, emb2} = Singularity.EmbeddingEngine.embed("test")
emb1 == emb2  # Should be true
```

### Test #3: Check Model Loading
```elixir
{:ok, state} = Singularity.Embedding.ModelLoader.load_model(:qodo)
Map.get(state, :mock)  # Should be nil or false, NOT true
```

### Test #4: Check Similarity Search
```elixir
# Should return consistent similarity scores
{:ok, sim1} = Singularity.EmbeddingEngine.similarity("async fn", "async function")
{:ok, sim2} = Singularity.EmbeddingEngine.similarity("async fn", "async function")
sim1 == sim2  # Should be true
```

---

## File Organization

### Core Embedding Files
- `embedding_engine.ex` - Public API (delegates to NxService)
- `embedding_generator.ex` - High-level API with auto model selection
- `embedding_model_loader.ex` - GenServer wrapper (mostly mock)

### Implementation Files (Under embedding/)
- `nx_service.ex` - Main inference engine (HAS FALLBACKS)
- `model_loader.ex` - Downloads and loads models (INCOMPLETE)
- `trainer.ex` - Fine-tuning orchestration (INCOMPLETE)
- `training_step.ex` - Gradient computation (SLOW)
- `tokenizer.ex` - Text tokenization (PLACEHOLDER)
- `validation.ex` - Testing utilities (TESTING MOCKS)
- `automatic_differentiation.ex` - Gradient computation (INCOMPLETE)
- `model.ex` - Model architecture (CHECK CONTENT)
- `service.ex` - NATS integration (INCOMPLETE)

### Search/Quality Files
- `search/unified_embedding_service.ex` - Multi-strategy wrapper (HAS PLACEHOLDERS)
- `search/embedding_quality_tracker.ex` - Self-learning loop (BROKEN)
- `search/code_search.ex` - Vector search (BROKEN)

### Jobs
- `jobs/embedding_finetune_job.ex` - Daily fine-tuning (USES MOCK DATA)

### Database
- `migrations/20250101000016_standardize_embedding_dimensions.exs` - Dimension migration
- `migrations/20250101000020_create_code_search_tables.exs` - Search tables
- `migrations/20250101000008_add_missing_vector_indexes.exs` - Vector indexes

---

## Quick Fixes (First Priority)

### 1. Disable Bumblebee Strategy
```elixir
# Comment out in unified_embedding_service.ex
# Return error instead of placeholder implementations
```

### 2. Fix NxService Fallback
```elixir
# Instead of:
{:ok, generate_embedding(text_hash, 1536, "qodo")}

# Should be:
{:error, :real_inference_failed}
```

### 3. Fix Fine-Tune Job
```elixir
# Instead of:
triplets = triplets ++ generate_mock_triplets(mock_count)

# Should be:
if length(triplets) < 100 do
  {:error, :insufficient_training_data}
end
```

### 4. Standardize Dimensions
- **Decision:** Use 2560-dim (Qodo 1536 + Jina 1024 concatenated)
- **Update:** All modules to return 2560-dim vectors
- **Rebuild:** All vector indexes to 2560-dim

---

## Success Metrics

After fixes:
- [ ] All embeddings are 2560-dim
- [ ] Same text always produces same embedding
- [ ] Similarity scores consistent
- [ ] Vector search returns correct results
- [ ] Fine-tuning actually trains on real data
- [ ] Models persist and load correctly
- [ ] No more hash-based fallbacks
- [ ] Quality tracker records feedback correctly

---

## Estimated Total Fix Time
- **Critical Issues:** 18-22 hours
- **High Priority Issues:** 12-15 hours
- **Testing & Validation:** 8-10 hours
- **Total:** 38-47 hours (1 week full-time)
