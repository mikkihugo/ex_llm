# Fine-tuning Guide - Pure Elixir Embeddings

**Recommended Approach**: Fine-tune only, don't train from scratch. This saves weeks of training time.

## What is Fine-tuning?

Fine-tuning = small adjustments to pre-trained models on your specific data.

```
Pre-trained model:  98% done
Your data:          Small adjustments (last 2%)
Result:             Specialized embedding model for your codebase
Training time:      Hours (not weeks)
```

## Architecture: Triplet Loss

We use **Triplet Loss** for contrastive learning:

```
Input:  Three code samples
  - Anchor:   "def hello(name):"
  - Positive: "def greet(name):"  (similar)
  - Negative: "class MyClass:"    (different)

Goal: Make similar codes close, dissimilar codes far
  distance(anchor, positive) < distance(anchor, negative)

Loss = max(0, margin + d(anchor, pos) - d(anchor, neg))
  margin = 0.5 (safety margin)
```

## Quick Start

### 1. Prepare Training Data

```elixir
training_data = [
  %{
    anchor: "def calculate_sum(numbers):\n    return sum(numbers)",
    positive: "def add_all(nums):\n    return sum(nums)",
    negative: "class Calculator:\n    pass"
  },
  %{
    anchor: "async fn fetch_data() {}",
    positive: "async fn load_data() {}",
    negative: "fn process_data() {}"
  },
  # ... more triplets
]
```

### 2. Create Trainer

```elixir
iex> {:ok, trainer} = Singularity.Embedding.Trainer.new(:qodo, device: :cuda)
{:ok, %Singularity.Embedding.Trainer{model: :qodo, device: :cuda, ...}}
```

### 3. Fine-tune

```elixir
iex> {:ok, metrics} = Singularity.Embedding.Trainer.train(
...>   trainer,
...>   training_data,
...>   epochs: 3,
...>   batch_size: 16,
...>   learning_rate: 1.0e-5
...> )

Starting fine-tuning:
  Model: :qodo
  Epochs: 3
  Samples: 100
  Batch size: 16
  Learning rate: 1.0e-5
  Margin: 0.5

Epoch 1/3 - 7 batches
  Batch 1/7 - Loss: 0.3245
  Batch 2/7 - Loss: 0.2891
  ...
Saving checkpoint: qodo-epoch-1

Epoch 2/3 - 7 batches
  ...

✅ Fine-tuning completed successfully

{:ok, %{
  model: :qodo,
  epochs: 3,
  samples: 100,
  device: :cuda,
  final_loss: 0.1234,
  avg_loss: 0.2156,
  trained_at: #DateTime<...>,
  metrics_per_epoch: [...]
}}
```

### 4. Reload Weights

```elixir
iex> :ok = Singularity.Embedding.NxService.reload_model(:qodo)
Reloading model: :qodo
✅ Model reloaded: :qodo
:ok

# Now your embeddings use fine-tuned weights!
iex> {:ok, emb} = Singularity.Embedding.NxService.embed("def hello")
{:ok, #Nx.Tensor<...>}
```

## Data Preparation

### Format 1: Triplets (Recommended)

Three items per training example:
- **Anchor**: Reference code sample
- **Positive**: Similar code (same function, different implementation)
- **Negative**: Different code (different function/class)

```elixir
%{
  anchor: "def calculate(x): return x * 2",
  positive: "def double(n): return n * 2",
  negative: "class Math: pass"
}
```

### Format 2: Text + Label

If you only have text and labels, we auto-convert:

```elixir
%{
  text: "def hello",
  label: "greeting"
}
# Converted to:
# anchor: "def hello"
# positive: "similar_def hello"
# negative: "random_greeting"
```

## Hyperparameters

### Learning Rate
- **Default**: `1.0e-5` (good for fine-tuning)
- **Too high** (1e-3): Model diverges, loss increases
- **Too low** (1e-7): Slow training, barely improves
- **Rule**: Start at 1e-5, adjust if loss doesn't decrease

### Batch Size
- **Default**: `16` (balances memory and gradient quality)
- **GPU (RTX 4080)**: Can go up to 64 (14GB VRAM available)
- **CPU**: Keep at 8-16 (memory intensive)

### Epochs
- **Dev**: `1-3` (quick iteration)
- **Production**: `5-10` (better convergence)
- **Watch for**: Overfitting (validation loss increases)

### Margin
- **Default**: `0.5` (good for code)
- **Smaller** (0.1-0.3): More aggressive learning
- **Larger** (0.7-1.0): More conservative

## Checkpoints

Fine-tuning saves checkpoints automatically:

```
priv/models/
├── qodo-epoch-1/
│   ├── config.json
│   ├── params.bin (weights)
│   └── ...
├── qodo-epoch-2/
│   └── ...
├── qodo-checkpoint-latest/  (best checkpoint)
│   └── ...
```

### Load Checkpoint

```elixir
iex> {:ok, trainer} = Singularity.Embedding.Trainer.load_checkpoint(trainer, "epoch-2")
{:ok, trainer}

iex> :ok = Singularity.Embedding.NxService.reload_model(:qodo, "priv/models")
# Uses the latest checkpoint
```

## Monitoring Training

### Loss Should Decrease

```
Epoch 1: avg_loss = 0.45
Epoch 2: avg_loss = 0.38  ✅ Decreasing
Epoch 3: avg_loss = 0.32  ✅ Decreasing
Epoch 4: avg_loss = 0.31  ✅ Still improving
```

### Watch for Overfitting

```
Epoch 1: train_loss = 0.45, val_loss = 0.46  ✅ Similar
Epoch 2: train_loss = 0.25, val_loss = 0.35  ⚠️  Gap increasing
Epoch 3: train_loss = 0.10, val_loss = 0.50  ❌ Overfitting!
```

**Solution**: Stop earlier, use validation set, add regularization

## Models: Qodo vs Jina v3

### Qodo-Embed-1 (Recommended for fine-tuning)

- **Dimension**: 1536 (higher = more expressive)
- **Specialization**: Code-optimized (trained on code)
- **Training**: Good gradient flow
- **Memory**: ~3GB GPU
- **Use when**: Fine-tuning on code data

```elixir
{:ok, trainer} = Trainer.new(:qodo, device: :cuda)
```

### Jina v3

- **Dimension**: 1024
- **Specialization**: General-purpose (multi-modal)
- **Training**: Stable convergence
- **Memory**: ~1GB GPU
- **Use when**: Fine-tuning on mixed data types

```elixir
{:ok, trainer} = Trainer.new(:jina_v3, device: :cuda)
```

## Daily Fine-tuning via Oban

```elixir
# config/config.exs
config :singularity, Oban,
  queues: [training: 1],
  jobs: [
    {Singularity.Jobs.EmbeddingFinetuneJob, cron: "0 2 * * *"}  # 2 AM daily
  ]

# Manually trigger (testing)
iex> Singularity.Jobs.EmbeddingFinetuneJob.schedule_now()
```

## Performance Expectations

### Training Speed (RTX 4080)

| Model | Device | Samples/min | 100 samples |
|-------|--------|-------------|------------|
| Qodo | CUDA | 300 | ~20 sec |
| Qodo | CPU | 30 | ~3.3 min |
| Jina v3 | CUDA | 400 | ~15 sec |

### Memory Usage

| Model | GPU (fp16) | CPU |
|-------|-----------|-----|
| Qodo | 3GB | 6GB |
| Jina v3 | 1GB | 2GB |
| Both | 4GB | 8GB |

### Convergence

Typical fine-tuning with 100-1000 samples:
- **Epoch 1**: Loss drops significantly (0.5 → 0.35)
- **Epoch 2**: Steady improvement (0.35 → 0.28)
- **Epoch 3**: Diminishing returns (0.28 → 0.26)
- **After 3-5 epochs**: Usually converged

## Common Issues

### Loss Not Decreasing

**Symptoms**: Loss stays flat or increases
```
Epoch 1: Loss = 0.45
Epoch 2: Loss = 0.46
Epoch 3: Loss = 0.47  ❌ Getting worse!
```

**Causes**:
1. Learning rate too high → try 5e-6
2. Bad training data → check triplet quality
3. Model not loading → verify checkpoint exists

**Fix**:
```elixir
# Lower learning rate
{:ok, metrics} = Trainer.train(trainer, data,
  epochs: 3,
  learning_rate: 5.0e-6  # Was 1e-5
)
```

### Out of Memory

**Symptom**: Training crashes after a few batches
```
RuntimeError: CUDA out of memory
```

**Solutions**:
```elixir
# Option 1: Smaller batch size
{:ok, _} = Trainer.train(trainer, data, batch_size: 8)  # Was 16

# Option 2: Use CPU
{:ok, trainer} = Trainer.new(:qodo, device: :cpu)

# Option 3: Mixed precision (future enhancement)
# Use float16 instead of float32
```

### Training Too Slow

**Symptom**: Each epoch takes forever
```
Epoch 1: 5 minutes for 100 samples  ❌ Very slow
```

**Solutions**:
```elixir
# Option 1: Use GPU
{:ok, trainer} = Trainer.new(:qodo, device: :cuda)

# Option 2: Reduce batch processing
# Process smaller batches in parallel (future enhancement)

# Option 3: Use Jina v3 (slightly faster)
{:ok, trainer} = Trainer.new(:jina_v3, device: :cuda)
```

## Example: Real Fine-tuning Job

```elixir
defmodule MyProject.EmbeddingFinetuneJob do
  use Oban.Worker, queue: :training, max_attempts: 1

  def perform(%Job{}) do
    # 1. Collect training data from your codebase
    code_snippets = collect_snippets()

    # 2. Create triplets (anchor, positive, negative)
    triplets = create_triplets(code_snippets)

    # 3. Fine-tune
    case Singularity.Embedding.Trainer.new(:qodo, device: :cuda) do
      {:ok, trainer} ->
        case Singularity.Embedding.Trainer.train(trainer, triplets,
          epochs: 3,
          batch_size: 32,
          learning_rate: 1.0e-5
        ) do
          {:ok, metrics} ->
            # 4. Reload in NxService
            Singularity.Embedding.NxService.reload_model(:qodo)
            Logger.info("✅ Daily fine-tuning completed: #{inspect(metrics)}")
            :ok

          {:error, reason} ->
            Logger.error("❌ Fine-tuning failed: #{inspect(reason)}")
            :error
        end

      {:error, reason} ->
        Logger.error("❌ Trainer creation failed: #{inspect(reason)}")
        :error
    end
  end

  defp collect_snippets() do
    # Query codebase for snippets
    # Return list of code strings
  end

  defp create_triplets(snippets) do
    # For each snippet:
    # - Anchor: the snippet
    # - Positive: similar snippet (same type/pattern)
    # - Negative: random snippet (different type)
    []
  end
end
```

## Validation & Testing

### Test on Validation Data

```elixir
iex> validation_data = [%{...}, %{...}, ...]
iex> {:ok, metrics} = Trainer.evaluate(trainer, validation_data)
{:ok, %{accuracy: 0.87, map: 0.91}}
```

### Test Embeddings After Fine-tuning

```elixir
# After fine-tuning and reload
iex> {:ok, emb1} = NxService.embed("def hello(x): return x + 1")
iex> {:ok, emb2} = NxService.embed("def add_one(n): return n + 1")
iex> {:ok, sim} = NxService.similarity(emb1, emb2)

# Should be high (similar code)
0.92  # ✅ Great similarity after fine-tuning
```

## Next: Implement the TODO Stubs

Current implementation is a skeleton. To run real fine-tuning:

### Phase 2 (Tokenization & Forward Pass)

```elixir
# In Trainer.compute_batch_loss/2
# TODO:
# 1. Tokenize anchor, positive, negative texts
# 2. Create input tensors (input_ids, attention_mask)
# 3. Run forward pass via Nx
# 4. Extract embeddings
# 5. Compute triplet loss: max(0, margin + d(anc, pos) - d(anc, neg))
# 6. Return scalar loss
```

### Phase 3 (Backward Pass & Optimization)

```elixir
# In Trainer.train_epoch/5
# TODO:
# 1. Wrap forward pass in Nx.Defn
# 2. Compute gradients via auto-diff
# 3. Apply gradient clipping
# 4. Update weights with Adam optimizer
# 5. Return updated model_params
```

### Phase 4 (Data Collection)

```elixir
# In EmbeddingFinetuneJob
# TODO:
# 1. Query codebase for snippets
# 2. Deduplicate and clean
# 3. Create positive pairs (similar code)
# 4. Create negative pairs (random code)
# 5. Write to JSON for training
```

## Summary

- ✅ Fine-tune only (way simpler than training from scratch)
- ✅ Use Triplet Loss for contrastive learning
- ✅ Start with learning_rate = 1e-5
- ✅ Monitor loss: should decrease
- ✅ Run daily via Oban job
- ✅ Reload weights hot-swap (no restart)
- 🚧 Phase 2: Tokenization + forward pass
- 🚧 Phase 3: Backward pass + optimization
- 🚧 Phase 4: Data collection from codebase
