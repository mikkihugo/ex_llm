# Phase 4.1 Test Execution Guide

## Overview

Phase 4.1 implements comprehensive validation testing for the embedding system's Phase 4 features:
- Real model weight loading from HuggingFace
- Production inference with fallbacks
- Fast automatic differentiation (Nx.Defn)

The validation suite is provided by `Singularity.Embedding.Validation` module.

## Quick Start

### Single Test Execution

Run any individual validation test in IEx:

```bash
cd singularity
iex -S mix
```

Then in IEx:

```elixir
# Test 1: Load real models from HuggingFace
{:ok, results} = Singularity.Embedding.Validation.test_real_model_loading()

# Test 2: Verify inference quality
{:ok, quality} = Singularity.Embedding.Validation.verify_inference_quality(:qodo)

# Test 3: Test fine-tuning convergence
{:ok, convergence} = Singularity.Embedding.Validation.test_convergence(:qodo)

# Test 4: Benchmark complete system
{:ok, benchmarks} = Singularity.Embedding.Validation.benchmark_complete_system()

# Complete validation suite (runs all 4 tests)
{:ok, results} = Singularity.Embedding.Validation.run_complete_validation()
```

## Tests Explained

### Test 1: Real Model Loading

**Function:** `test_real_model_loading/0`

**What it tests:**
- Downloads Qodo-Embed-1 model from HuggingFace
- Downloads Jina v3 model from HuggingFace
- Extracts weights from safetensors binary format
- Converts tensors to Nx format
- Reports load time, model size, and tensor counts

**Expected output:**
```
================================================================================
🧪 TEST: Real Model Loading from HuggingFace
================================================================================

📦 Testing Qodo-Embed-1 loading...
✅ Model loaded successfully
   Time: 2345 ms
   Size: 435 MB
   Has weights: true
   Tensors: 156

📦 Testing Jina v3 loading...
✅ Model loaded successfully
   Time: 1890 ms
   Size: 320 MB
   Has weights: true
   Tensors: 142

================================================================================
📊 Model Loading Summary:
  Qodo: :success
  Jina: :success
================================================================================
```

**Success criteria:**
- ✅ Both models load successfully
- ✅ Load times < 5 seconds each
- ✅ Both have weight tensors extracted
- ✅ Tensor counts are reasonable (100+)

**Fallback behavior:**
- If HuggingFace download fails, uses mock weights
- If safetensors parsing fails, returns fallback status
- Never raises exception - always returns valid result

### Test 2: Inference Quality Verification

**Function:** `verify_inference_quality(model \\ :qodo)`

**What it tests:**
- Generates embeddings for 5 test code snippets
- Verifies embedding shape (2560-dimensional)
- Verifies L2 normalization (norm ≈ 1.0)
- Computes similarity between text pairs
- Validates similarity scores are in valid range [0, 1]

**Expected output:**
```
================================================================================
🎯 TEST: Inference Quality Verification (:qodo)
================================================================================

🧬 Generating embeddings for 5 test texts...
  [1] def hello_world: return 42...
  [2] async fn fetch_data() {}...
  [3] class MyClass: pass...
  [4] SELECT * FROM users WHERE id = 1...
  [5] const API_URL = 'https://api.example.com'...

📏 Testing similarity computation...
   ✅ Computed 10 similarity pairs
      def hello_world ↔ async fn fetch: 0.4521
      def hello_world ↔ class MyClass: 0.3892
      [... 8 more pairs ...]
```

**Success criteria:**
- ✅ All embeddings are 2560-dimensional
- ✅ Embeddings are normalized (norm ≈ 1.0)
- ✅ Min/max values are in reasonable range [-1, 1]
- ✅ Similarity scores are in [0, 1]
- ✅ Similar texts have higher similarity (domain-specific code similar to domain-specific)

### Test 3: Fine-Tuning Convergence

**Function:** `test_convergence(model \\ :qodo)`

**What it tests:**
- Creates 5 training triplets (anchor, positive, negative)
- Initializes trainer with model weights
- Runs 3 epochs of fine-tuning
- Tracks loss per epoch
- Verifies loss decreases (convergence)

**Expected output:**
```
================================================================================
📊 TEST: Fine-Tuning Convergence (:qodo)
================================================================================

📚 Creating training data...
✅ Created 5 training triplets

🏋️  Initializing trainer...
✅ Trainer initialized

🚀 Running fine-tuning (3 epochs)...
✅ Fine-tuning completed in 4523 ms

📈 Loss per epoch:
   Epoch 1: 0.8234
   Epoch 2: 0.6152
   Epoch 3: 0.4891

✨ Convergence Analysis:
   First loss: 0.8234
   Last loss:  0.4891
   Improved:   true
   Improvement: 40.6%
```

**Success criteria:**
- ✅ Fine-tuning completes without error
- ✅ Loss decreases each epoch (convergence)
- ✅ Training time < 30 seconds for 3 epochs
- ✅ Improvement > 20%

### Test 4: Performance Benchmarking

**Function:** `benchmark_complete_system/0`

**What it tests:**
- Measures inference latency (10 iterations)
- Benchmarks gradient computation via Nx.Defn
- Compares inference with real weights vs fallback
- Tests automatic differentiation availability

**Expected output:**
```
================================================================================
⚡ BENCHMARK: Complete System Performance
================================================================================

🔍 Benchmarking inference...
   Running 10 iterations...

🔍 Benchmarking gradient computation...
   Testing Nx.Defn availability...

================================================================================
📊 Performance Summary:
================================================================================

⚙️  Inference:
   Avg time: 28.45 ms
   Min time: 22 ms
   Max time: 35 ms

📐 Gradient Computation:
   Nx.Defn available: true
   Time: 67 ms
```

**Success criteria:**
- ✅ Inference latency < 50ms per embedding
- ✅ Gradient computation < 200ms per batch
- ✅ Nx.Defn successfully detected
- ✅ Benchmark completes without error

### Complete Validation Suite

**Function:** `run_complete_validation/0`

Runs all 4 tests sequentially and provides final summary.

**Expected execution time:** 30-60 seconds total

**Final output:**
```
🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬
🔬 PHASE 4.1: COMPLETE VALIDATION SUITE
🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬🔬

[1/4] Testing model loading...
[2/4] Testing inference quality...
[3/4] Testing fine-tuning convergence...
[4/4] Running performance benchmarks...

✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨
✨ VALIDATION SUITE COMPLETE ✨
✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨✨
```

## Running with Mix Task

Create a mix task to run validation (optional, for automation):

```bash
# Create the task file
cat > lib/mix/tasks/validation.run.ex << 'EOF'
defmodule Mix.Tasks.Validation.Run do
  use Mix.Task

  @shortdoc "Run Phase 4.1 validation suite"

  def run(_args) do
    Mix.Task.run("app.start")

    case Singularity.Embedding.Validation.run_complete_validation() do
      {:ok, results} ->
        IO.puts("\n✅ VALIDATION PASSED")
        IO.inspect(results, pretty: true)
      {:error, reason} ->
        IO.puts("\n❌ VALIDATION FAILED")
        IO.inspect(reason)
        System.halt(1)
    end
  end
end
EOF

# Run it
mix validation.run
```

## Troubleshooting

### Issue: "Model loading failed" or "uses_mock: true"

**Cause:** HuggingFace download failed or safetensors parsing failed

**Solution:**
1. Check internet connection
2. Verify HuggingFace API is accessible
3. Check disk space for model downloads (500+ MB)
4. Ensure Singularity.Embedding.ModelLoader is working

### Issue: "Exception during model loading"

**Cause:** Unexpected error in model loading pipeline

**Solution:**
1. Check logs for specific error message
2. Verify BEAM memory is sufficient
3. Restart IEx and try again

### Issue: "Failed: Module not found" for NxService

**Cause:** Embedding modules not compiled

**Solution:**
```bash
cd singularity
mix clean
mix compile
iex -S mix
```

### Issue: Inference quality test shows "nil" values

**Cause:** NxService failing silently due to missing model

**Solution:**
1. Verify `test_real_model_loading()` succeeds first
2. Check ModelLoader is working correctly
3. Ensure weights are extracted properly

### Issue: Convergence test doesn't show loss decreasing

**Cause:**
- Model weights not properly loaded (using random initialization)
- Training data too simple
- Learning rate too low

**Solution:**
1. Run `test_real_model_loading()` to verify weights loaded
2. Increase number of epochs in test_convergence
3. Try with larger training dataset

## Expected Outcomes

### All Tests Pass ✅

**Indicates:**
- Phase 4 implementation is complete and working
- Real model weights are loading correctly
- Inference pipeline is functional
- Automatic differentiation is available
- Fine-tuning converges on real data

**Next steps:** Phase 5 - Production Deployment

### Some Tests Fail ⚠️

**Indicates:**
- Specific component needs debugging
- See "Troubleshooting" section for component-specific fixes

### All Tests Fail ❌

**Indicates:**
- Embedding infrastructure issue
- Environment configuration problem

**Resolution:**
1. Verify all modules compiled: `mix compile`
2. Check database is running
3. Verify BEAM environment is correct
4. Try: `mix clean && mix compile && iex -S mix`

## Performance Expectations

| Component | CPU Time | GPU Time | Notes |
|-----------|----------|----------|-------|
| Model Loading | 2-5s | 2-5s | HuggingFace download + parsing |
| Single Inference | 20-40ms | 2-10ms | Axon forward pass |
| Batch (5 samples) | 100-200ms | 10-50ms | Triplet loss computation |
| Gradient (Nx.Defn) | 20-100ms | 5-20ms | Automatic differentiation |
| Gradient (Finite Diff) | 2-10s | 2-10s | Fallback method |
| 3-Epoch Fine-tune | 10-30s | 5-15s | With 5 triplets |

## Testing Checklist

```
Phase 4.1 Validation Tests

[ ] Model Loading Test
    [ ] Qodo loads successfully
    [ ] Jina loads successfully
    [ ] Load time < 5s each
    [ ] Tensors extracted correctly

[ ] Inference Quality Test
    [ ] Embeddings are 2560-dim
    [ ] Embeddings normalized
    [ ] Similarities computed
    [ ] Scores in valid range

[ ] Convergence Test
    [ ] Trainer initializes
    [ ] Training runs 3 epochs
    [ ] Loss decreases
    [ ] Improvement > 20%

[ ] Benchmark Test
    [ ] Inference latency measured
    [ ] Gradient computation measured
    [ ] All metrics reported

[ ] Complete Validation Suite
    [ ] All 4 tests run sequentially
    [ ] Final summary shows results
    [ ] Execution time < 60s
```

## Integration with CI/CD

Once tests are validated locally, integrate into CI pipeline:

```elixir
# In your test file
defmodule Singularity.Embedding.ValidationTest do
  use ExUnit.Case

  @tag :embedding_validation
  test "complete validation suite passes" do
    {:ok, results} = Singularity.Embedding.Validation.run_complete_validation()

    assert results.model_loading != nil
    assert results.inference_quality != nil
    assert results.convergence != nil
    assert results.benchmarks != nil
  end
end
```

Run with: `mix test --include embedding_validation`

## Next Steps

After validation confirms Phase 4.1 works:

1. **Phase 5: Production Deployment**
   - Create HTTP endpoints for embeddings
   - Implement batch processing API
   - Set up caching layer

2. **Performance Optimization**
   - Profile with real workloads
   - Optimize hot paths
   - Consider GPU utilization

3. **Fine-tuning as a Service**
   - Schedule jobs via Oban
   - Track metrics over time
   - Implement A/B testing

## Reference

- **Phase 4 Implementation:** `PHASE_4_IMPLEMENTATION_COMPLETE.md`
- **Complete System:** `COMPLETE_EMBEDDING_SYSTEM_SUMMARY.md`
- **Validation Module:** `lib/singularity/embedding/validation.ex`
- **ModelLoader:** `lib/singularity/embedding/model_loader.ex`
- **NxService:** `lib/singularity/embedding/nx_service.ex`
- **Trainer:** `lib/singularity/embedding/trainer.ex`

---

**Status:** Phase 4.1 testing framework ready for execution ✅

Test this documentation by running the complete validation suite in IEx!
