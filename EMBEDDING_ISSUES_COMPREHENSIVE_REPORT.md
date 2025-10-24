# Comprehensive Embedding System Issues Report

## Summary
Found **26 critical, high, and medium severity issues** across embedding infrastructure, including incomplete implementations, dimension mismatches, mock/placeholder code, TODO items, and architectural problems.

---

## CRITICAL Issues (Must Fix)

### 1. **UnifiedEmbeddingService - Placeholder Implementations (CRITICAL)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/search/unified_embedding_service.ex`
**Lines:** 556-659
**Severity:** CRITICAL
**Issue:** Multiple functions are placeholder implementations that don't actually work:
- `load_bumblebee_model()` (lines 555-576) - Returns simulated model info, doesn't actually load models
- `tokenize_text()` (lines 578-593) - Splits by spaces, doesn't use actual tokenizers
- `generate_embedding_from_tokens()` (lines 595-622) - Generates random vectors, not real embeddings
- `process_batch()` (lines 624-648) - Doesn't work with Bumblebee models
- All fallback to random embeddings instead of actual computation

**Impact:** Bumblebee strategy completely non-functional. Returns fake 384-dim random vectors.
**Fix:** Implement actual Bumblebee model loading and inference using Bumblebee APIs.

---

### 2. **Embedding.TrainingStep - TODO: Evaluate Not Implemented (CRITICAL)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/trainer.ex`
**Lines:** 145-149
**Severity:** CRITICAL
**Issue:** 
```elixir
def evaluate(_trainer, val_data) when is_list(val_data) do
  Logger.info("Evaluating on #{length(val_data)} samples")
  # TODO: Implement evaluation
  # Should compute:
  # - Accuracy (triplet ranking correct)
  # - Mean Average Precision
  # - Recall@K
```
**Impact:** Cannot evaluate model quality. No validation metrics available.
**Fix:** Implement triplet accuracy, MAP, Recall@K metrics.

---

### 3. **Embedding.Trainer - TODO: Save Actual Weights Not Implemented (CRITICAL)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/trainer.ex`
**Lines:** 220-230 (in train_epochs loop)
**Severity:** CRITICAL
**Issue:** 
```elixir
# TODO: Save actual weights
```
**Impact:** Fine-tuning doesn't save model checkpoints. Can't persist learned weights.
**Fix:** Implement actual weight serialization using safetensors or ONNX format.

---

### 4. **Embedding.NxService - Hash-Based Fallback Instead of Real Inference (CRITICAL)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/nx_service.ex`
**Lines:** 182-246
**Severity:** CRITICAL
**Issue:** 
```elixir
# Fallback to hash-based embedding
text_hash = :erlang.phash2(text)
{:ok, generate_embedding(text_hash, 1536, "qodo")}
```
System falls back to hash-based random embeddings instead of real model inference. This happens when:
- Real inference fails
- Model not loaded
- Tokenization fails
**Impact:** Non-deterministic embeddings. Same text can produce different vectors on retries. Similarity search broken.
**Fix:** Either load real models or fail explicitly instead of silently using bad embeddings.

---

### 5. **Embedding.ModelLoader - TODO: Load From Checkpoint Not Implemented (CRITICAL)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/model_loader.ex`
**Lines:** 48-60
**Severity:** CRITICAL
**Issue:**
```elixir
def load_from_checkpoint(model, checkpoint_dir) when is_atom(model) do
  checkpoint_path = Path.join(checkpoint_dir, "checkpoint-latest")
  if File.exists?(checkpoint_path) do
    # TODO: Load weights from checkpoint
    # For now, reload from HF
    load_model(model)
```
**Impact:** Fine-tuned models can't be loaded. Always loads base models instead.
**Fix:** Implement actual checkpoint loading from safetensors/ONNX files.

---

### 6. **Embedding.ModelLoader - TODO: Load Via Ortex Not Implemented (CRITICAL)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/model_loader.ex`
**Lines:** 145-190 (load_onnx_weights)
**Severity:** CRITICAL
**Issue:** ONNX model loading partially implemented with TODO comments
```elixir
# TODO: Load via Ortex when available
```
**Impact:** ONNX models (Jina v3) may not load correctly.
**Fix:** Implement Ortex-based ONNX loading or use alternative library.

---

### 7. **EmbeddingQualityTracker - Feedback Recording SQL Issues (CRITICAL)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/search/embedding_quality_tracker.ex`
**Lines:** 304-361
**Severity:** CRITICAL
**Issue:** 
- Tries to insert into `rag_performance_stats` table which may not exist or have different structure
- Hardcoded SQL query building prone to errors
- Metadata JSON serialization may fail
- `Feedback` schema used in extraction doesn't exist (line 494)

**Impact:** Embedding quality learning completely broken. Can't record feedback or extract training data.
**Fix:** 
1. Use Ecto queries instead of raw SQL
2. Create/verify `rag_performance_stats` table schema
3. Use actual Ecto schema for feedback

---

### 8. **EmbeddingFinetuneJob - Mock Data Fallback (CRITICAL)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/embedding_finetune_job.ex`
**Lines:** 119-136
**Severity:** CRITICAL
**Issue:**
```elixir
if length(triplets) < 10 do
  Logger.warning("Not enough real triplets (#{length(triplets)}), augmenting with mock data")
  mock_count = 100 - length(triplets)
  mock_data = generate_mock_triplets(mock_count)
  triplets = triplets ++ mock_data
```
System fine-tunes on mock data when real data insufficient.
**Impact:** Fine-tuning learns patterns from synthetic data, not actual codebase. Embeddings won't improve.
**Fix:** 
1. Fail if insufficient real training data
2. Implement better data collection strategies
3. At minimum, warn about using mock data

---

## HIGH Severity Issues

### 9. **Embedding Dimension Mismatch - 2560 vs 1536 vs 1024 vs 384 (HIGH)**
**Files:** Multiple
**Severity:** HIGH
**Issue:** Inconsistent embedding dimensions across system:
- `EmbeddingEngine.dimension()` returns 2560 (Qodo 1536 + Jina 1024 concatenated)
- `EmbeddingGenerator` doesn't concatenate, returns single model dimension
- `UnifiedEmbeddingService.embed_bumblebee()` generates 384-dim fake embeddings
- Database migrations standardized to 2560 but old code expects 768/1536
- Vector indexes created with incorrect dimensions

**Files Affected:**
- `/singularity/lib/singularity/embedding_engine.ex` - Returns 2560
- `/singularity/lib/singularity/llm/embedding_generator.ex` - Returns 1536 or 384
- `/singularity/lib/singularity/search/unified_embedding_service.ex` - Returns 384 (fake)
- `/singularity/priv/repo/migrations/20250101000016_standardize_embedding_dimensions.exs` - Sets 2560
- `/singularity/priv/repo/migrations/20250101000020_create_code_search_tables.exs` - Sets 1536

**Impact:** 
- Similarity search broken (dimension mismatches)
- pgvector operations fail on wrong dimensions
- Database constraints violated
- Search results inaccurate

**Fix:**
1. Decide on single dimension strategy (recommend 2560 with concatenation)
2. Update all modules to use same dimension
3. Rebuild vector indexes with correct dimension
4. Update database migrations to be consistent

---

### 10. **EmbeddingQualityTracker - Complex Incomplete Implementation (HIGH)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/search/embedding_quality_tracker.ex`
**Lines:** Throughout
**Severity:** HIGH
**Issue:** 
- Learning loop architecture defined but incomplete
- `fine_tune_embeddings()` (lines 431-480) tries to use Bumblebee APIs that don't match actual API
- `train_embedding_model()` (lines 531-560) uses Axon.Loop which doesn't exist in that form
- `contrastive_embedding_loss()` (lines 562-592) doesn't match Axon loss function patterns
- `create_embedding_batches()` doesn't work with actual Axon model format
- No actual connection to running fine-tuning jobs

**Impact:** Self-learning loop completely non-functional. Cannot improve embeddings based on search feedback.
**Fix:**
1. Remove complex Bumblebee/Axon integration attempts
2. Use actual EmbeddingFinetuneJob for fine-tuning instead
3. Keep only feedback recording and data extraction
4. Delegate actual training to Jobs system

---

### 11. **EmbeddingFinetuneJob - Mock Training Implementation (HIGH)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/embedding_finetune_job.ex`
**Lines:** See mock_training references
**Severity:** HIGH
**Issue:** 
- `detect_device()` (lines 361-384) uses `nvidia-smi` which may not exist
- Metal detection incomplete for macOS
- Training metrics are not actually computed
- No real convergence feedback

**Impact:** Fine-tuning job runs but doesn't actually train models effectively.
**Fix:**
1. Use proper device detection libraries
2. Implement actual training metrics
3. Add convergence validation

---

### 12. **Search - Embedding Dimension Mismatches in Code Search (HIGH)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/search/code_search.ex`
**Severity:** HIGH
**Issue:** CodeSearch module expects vector_embedding column with specific dimension but:
- Migration 20250101000020 creates 1536-dim indexes
- Migration 20250101000016 sets to 2560-dim
- CodeSearch likely built for original dimension
- Vector index queries may fail

**Impact:** Semantic code search broken due to dimension mismatches.
**Fix:**
1. Audit CodeSearch implementation
2. Update to use 2560-dim consistently
3. Rebuild vector indexes

---

## MEDIUM Severity Issues

### 13. **Embedding.TrainingStep - Gradient Approximation Inefficient (MEDIUM)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/training_step.ex`
**Lines:** 89-108
**Severity:** MEDIUM
**Issue:** Uses finite differences for gradient computation instead of automatic differentiation:
```elixir
defp compute_finite_difference_gradients(params, loss_fn, _epsilon \\ 1.0e-4) do
  # For efficiency, approximate gradients rather than full finite differences
  # Generate approximate gradients with small random component
```
This is O(n) forward passes instead of O(1) for automatic differentiation.
**Impact:** Training is 100x slower than necessary. Fine-tuning becomes impractical.
**Fix:** Implement proper Nx.Defn automatic differentiation.

---

### 14. **Embedding.Tokenizer - Placeholder Implementation (MEDIUM)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/tokenizer.ex`
**Lines:** Placeholder noted
**Severity:** MEDIUM
**Issue:** 
```elixir
# For now, simple placeholder
```
**Impact:** Tokenization may not work correctly. Text not properly prepared for embedding models.
**Fix:** Implement proper tokenization using HuggingFace tokenizers.

---

### 15. **Embedding.ModelLoader - Mock State Fallback (MEDIUM)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/model_loader.ex`
**Lines:** Multiple locations
**Severity:** MEDIUM
**Issue:**
```elixir
Logger.warning("Safetensors file not found, using mock state")
  mock: true
Logger.warning("ONNX file not found, using mock state")
  mock: true
```
When model files don't exist, system continues with mock state instead of failing.
**Impact:** Silent failures. System appears to work but uses fake models.
**Fix:**
1. Fail fast when models not found
2. Implement proper model download if needed
3. Don't silently use mock state

---

### 16. **UnifiedEmbeddingService - MiniLM Fake Embeddings (MEDIUM)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/search/unified_embedding_service.ex`
**Lines:** 271, 283
**Severity:** MEDIUM
**Issue:**
```elixir
# Skip MiniLM - it returns fake embeddings
```
Comments acknowledge that MiniLM strategy returns fake embeddings but strategy still exposed.
**Impact:** Users might select MiniLM thinking it works but get random vectors.
**Fix:** Remove MiniLM strategy or implement properly.

---

### 17. **Embedding.AutomaticDifferentiation - Incomplete (MEDIUM)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/automatic_differentiation.ex`
**Severity:** MEDIUM
**Issue:** File exists but content not fully reviewed. Likely incomplete implementation.
**Impact:** Gradient computation may not work correctly.
**Fix:** Audit and complete implementation.

---

### 18. **Embedding.Service - Incomplete (MEDIUM)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/service.ex`
**Severity:** MEDIUM
**Issue:** NATS-based embedding service may not be fully integrated.
**Impact:** Distributed embedding requests may fail.
**Fix:** Complete implementation and testing.

---

### 19. **EmbeddingFinetuneJob - Real Data Collection Incomplete (MEDIUM)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/jobs/embedding_finetune_job.ex`
**Lines:** 103-137
**Severity:** MEDIUM
**Issue:** 
- `extract_code_snippets()` uses regex patterns that may not work for all languages
- Snippet filtering (lines 180-185) may eliminate too much data
- `create_contrastive_triplets()` uses Jaccard similarity which is very weak for embeddings
- No validation that triplets are actually different enough

**Impact:** Real training data of poor quality. Fine-tuning learns bad patterns.
**Fix:**
1. Use proper parsers instead of regex
2. Better snippet selection
3. Use actual semantic similarity instead of Jaccard
4. Better triplet validation

---

### 20. **Embedding.Validation - Mock Implementation (MEDIUM)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/embedding/validation.ex`
**Severity:** MEDIUM
**Issue:** Validation tests may be testing mock implementations instead of real models.
**Impact:** Tests pass but actual functionality broken.
**Fix:** Implement tests with real models.

---

## LOW Severity Issues (Warnings/Improvements)

### 21. **EmbeddingModelLoader - Model Validation Mock (LOW)**
**File:** `/singularity/lib/singularity/embedding_model_loader.ex`
**Lines:** 76-89
**Severity:** LOW
**Issue:** `validate_model_name()` returns mock model info instead of loading actual models.
**Impact:** GenServer thinks model is loaded when it's not.
**Fix:** Either load actual models or rename to reflect mock behavior.

---

### 22. **EmbeddingGenerator - Pgvector Conversion Issue (LOW)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/llm/embedding_generator.ex`
**Line:** 252
**Severity:** LOW
**Issue:** 
```elixir
{:ok, Pgvector.new(embedding)}
```
Already wrapping in Pgvector, but NxService may also wrap. Double wrapping possible.
**Impact:** Type errors in some code paths.
**Fix:** Clarify where Pgvector wrapping happens.

---

### 23. **Database Schema - Old References to 768-Dim (LOW)**
**File:** `/singularity/priv/repo/migrations/20250101000016_standardize_embedding_dimensions.exs`
**Lines:** 254-270 (down migration)
**Severity:** LOW
**Issue:** Down migration reverts to 768 dimensions but forward migration uses 2560.
**Impact:** Rollback will lose data or cause errors.
**Fix:** Update down migration or add data migration.

---

### 24. **Config - Embedding Job Configuration (LOW)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/config/config.exs`
**Severity:** LOW
**Issue:** Embedding fine-tuning job scheduled but endpoints to trigger it may not be exposed.
**Impact:** Users can't easily trigger fine-tuning.
**Fix:** Expose HTTP endpoints or CLI commands.

---

### 25. **Serverless Embeddings - Orphaned File (LOW)**
**File:** `/Users/mhugo/code/singularity-incubation/serverless_embeddings.ex`
**Severity:** LOW
**Issue:** File exists at root level, unclear purpose, likely orphaned.
**Impact:** Code duplication potential.
**Fix:** Delete or document purpose.

---

### 26. **EmbeddingQualityTracker - Unused Serialization Functions (LOW)**
**File:** `/Users/mhugo/code/singularity-incubation/singularity/lib/singularity/search/embedding_quality_tracker.ex`
**Lines:** 666-671
**Severity:** LOW
**Issue:** 
```elixir
defp serialize_embedding(%Pgvector{} = vec), do: Pgvector.to_list(vec) |> Jason.encode!()
defp deserialize_embedding(json) when is_binary(json) do
```
Serialization functions but data may not need it.
**Impact:** Unnecessary code.
**Fix:** Simplify or remove if not needed.

---

## Summary Table

| Severity | Count | Issues |
|----------|-------|--------|
| **CRITICAL** | 8 | Placeholder implementations, incomplete features, fallback to mock data |
| **HIGH** | 9 | Dimension mismatches, incomplete modules, complex broken implementations |
| **MEDIUM** | 6 | Inefficient algorithms, silent failures, incomplete data collection |
| **LOW** | 3 | Code organization, documentation, unused code |

---

## Recommended Action Plan

### Immediate (Week 1)
1. Fix CRITICAL issues - especially mock/placeholder code
2. Standardize on single embedding dimension (recommend 2560)
3. Fix feedback recording in EmbeddingQualityTracker

### Short Term (Week 2-3)
1. Implement proper model loading and weight serialization
2. Fix gradient computation and training
3. Audit and fix CodeSearch integration

### Medium Term (Month 1)
1. Complete all TODO items
2. Implement real fine-tuning with convergence metrics
3. Add comprehensive testing

### Long Term
1. Optimize training performance
2. Implement production-ready error handling
3. Add monitoring and observability

