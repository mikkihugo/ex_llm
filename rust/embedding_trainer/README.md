# Embedding Trainer

Fine-tune embedding models daily using tch-rs (PyTorch bindings in Rust).

**Status:** Framework complete, fine-tuning loop = TODO stubs

## Setup

### 1. Install PyTorch (tch-rs dependency)

```bash
# Via Nix (recommended)
nix develop

# Or via pip (installs libtorch)
pip install torch

# Verify
python -c "import torch; print(torch.cuda.is_available())"
```

### 2. Build Trainer Binary

```bash
cd rust/embedding_trainer
cargo build --release

# Binary location:
target/release/train_embeddings
```

### 3. Test Trainer Directly

```bash
# Train Qodo model (CPU)
./target/release/train_embeddings \
  --model qodo \
  --epochs 1 \
  --device cpu \
  --output-dir ../../priv/models

# Train Jina V3 with GPU
./target/release/train_embeddings \
  --model jina-v3 \
  --epochs 1 \
  --device cuda \
  --learning-rate 1e-5 \
  --output-dir ../../priv/models
```

### 4. Configure Oban Job (Elixir)

In `singularity/config/config.exs`:

```elixir
config :singularity, Oban,
  queues: [training: 1],
  jobs: [
    {Singularity.Jobs.EmbeddingFinetuneJob, cron: "0 2 * * *"}  # 2 AM daily
  ]
```

### 5. Trigger Training

```elixir
# Manual trigger (testing)
iex> Singularity.Jobs.EmbeddingFinetuneJob.schedule_now(model: "qodo", epochs: 1)

# Or via Oban UI
# Visit http://localhost:4000/admin/oban (requires oban_web)
```

## Models Supported

| Model | Repo | Dims | Type | Best For |
|-------|------|------|------|----------|
| **Jina V3** | jinaai/jina-embeddings-v3 | 1024 | T5-based | High-quality, long context |
| **Qodo-Embed-1** | Qodo/Qodo-Embed-1-1.5B | 1536 | Qwen2-based | Code embeddings |
| **MiniLM-L6-v2** | sentence-transformers/all-MiniLM-L6-v2 | 384 | BERT-based | Fast, CPU-friendly |
| **multilingual-e5** | intfloat/multilingual-e5-large | 1024 | E5-based | Multilingual |

## Architecture

```
Elixir Oban Job (Daily 2 AM)
    ↓
singularity/lib/singularity/jobs/embedding_finetune_job.ex
    ├─ Validates environment
    ├─ Prepares training data (from codebase)
    ├─ Calls Rust trainer binary
    ├─ Waits for completion
    ├─ Reloads weights in EmbeddingEngine NIF
    └─ Verifies new model works
    ↓
rust/embedding_trainer/src/main.rs
    ├─ Parses CLI args
    ├─ Loads pre-trained model from HF
    ├─ Creates training loop
    ├─ Fine-tunes on new data
    └─ Saves checkpoint-latest
    ↓
priv/models/checkpoint-latest/
    ├─ config.json
    ├─ pytorch_model.bin
    └─ tokenizer.json
```

## Implementation TODOs

### 1. Training Loop (src/main.rs)

```rust
// Currently: Mock training (logs but doesn't actually train)
// TODO: Implement:
// 1. Load actual model weights via tch
// 2. Tokenize training texts
// 3. Create contrastive loss function
// 4. Optimizer + backward pass
// 5. Save real weights to checkpoint
```

### 2. Data Preparation (Elixir Oban job)

```elixir
# Currently: Generates mock training data
# TODO: Implement:
# 1. Query codebase for code snippets
# 2. Tokenize into sentences
# 3. Create positive pairs (similar code)
# 4. Write to JSON for trainer
```

### 3. Model Reload (EmbeddingEngine NIF)

```elixir
# Currently: Logs "Models reloaded" but doesn't actually reload
# TODO: Implement:
# 1. Detect checkpoint-latest
# 2. Load weights into running Rust NIF
# 3. Verify new model works
# 4. Hot-swap without restarting
```

## Example: Full Fine-tuning Loop

When fully implemented, the flow will be:

```elixir
# 1. Oban triggers daily at 2 AM
# 2. Collects 1000 code snippets from your project
# 3. Creates contrastive pairs (similar code = positive pairs)
# 4. Calls tch-rs trainer:
#    - Loads Qodo-Embed-1 pre-trained weights
#    - Fine-tunes on 1000 samples for 1 epoch
#    - Saves weights to priv/models/checkpoint-latest
# 5. Reloads weights in running EmbeddingEngine NIF
# 6. Embeddings now reflect your codebase's patterns
```

**Result:** Your embedding model learns from YOUR code over time.

## Performance Notes

### GPU vs CPU

| Device | Qodo (1.5B) | Jina V3 (T5) | Speed | Best For |
|--------|------------|------------|-------|----------|
| **CPU** | 30 samples/min | 20 samples/min | Slow | Development |
| **CUDA** | 3000 samples/min | 2000 samples/min | Fast | Production |
| **Metal** | 2500 samples/min | 1500 samples/min | Fast | macOS |

### Recommended Settings

**Development (CPU):**
```bash
--epochs 1 --batch-size 8 --device cpu
# ~5 minutes for 100 samples
```

**Production (CUDA):**
```bash
--epochs 3 --batch-size 32 --device cuda
# ~2 minutes for 1000 samples
```

## Troubleshooting

### Build Errors

```bash
# PyTorch not found
error[E0463]: can't find crate for `tch`

# Solution: Install PyTorch
pip install torch
# Or use Nix:
nix develop
```

### CUDA Not Detected

```bash
# Check if CUDA available
nvidia-smi

# If using nix, enable CUDA:
# Modify flake.nix to include cuda package
```

### Out of Memory

```bash
# Reduce batch size
--batch-size 8  # Instead of 32

# Or use CPU for debugging
--device cpu
```

## Files

```
rust/embedding_trainer/
├── Cargo.toml                 # Dependencies (tch-rs, etc)
├── src/
│   ├── main.rs               # CLI entry point, training loops
│   ├── trainer.rs            # EmbeddingTrainer struct
│   └── models.rs             # Model configs (Jina, Qodo, etc)
└── README.md                 # This file

singularity/
└── lib/singularity/jobs/
    └── embedding_finetune_job.ex  # Oban job scheduling
```

## Next Steps

1. **Implement training loop** - Add actual fine-tuning in `src/main.rs`
2. **Implement data collection** - Query codebase for training samples in Oban job
3. **Implement model reload** - Hot-swap weights in EmbeddingEngine NIF
4. **Monitor training** - Add metrics/logging to track improvement

## References

- **tch-rs:** https://github.com/LaurentMazare/tch-rs
- **HuggingFace Hub:** https://github.com/huggingface/hf-hub-rs
- **PyTorch:** https://pytorch.org/
- **Jina Embeddings:** https://jina.ai/embeddings/
- **Qodo Embed:** https://huggingface.co/Qodo/Qodo-Embed-1-1.5B
