# GPU & Embedding Architecture

## Three Independent Layers

### 1. TRAINING (EXLA + Nx)
**Purpose:** Model training - CodeT5p (current) + StarCoder2-7B (Q1 2026) + Embedding fine-tuning (RTX 4080 only)
**Control:** XLA_TARGET environment variable

| Platform | XLA_TARGET | EXLA Client | Speed |
|----------|-----------|------------|-------|
| macOS dev | `metal` | `:host` (CPU) | Slow |
| RTX 4080 prod | `cuda118` | `:cuda` | Fast |
| Linux no GPU | `cpu` | `:host` (CPU) | Slow |

**Key:** Metal is NOT supported by XLA upstream, so macOS uses CPU for training.

### 2. EMBEDDINGS (Pure Elixir Nx/Axon)
**Purpose:** Vector generation via Axon models + Nx tensor operations (inference + fine-tuning)
**Control:** EXLA backend (same as training, via XLA_TARGET)
**Models:** Qodo-Embed-1 (safetensors) + Jina v3 (ONNX format)

| Platform | GPU Available | Speed | Latency |
|----------|---|--------|---------|
| macOS dev | Metal GPU (via EXLA) | Moderate | 15-50ms |
| RTX 4080 prod | CUDA GPU (via EXLA) | Fast | 5-15ms |
| Linux no GPU | CPU only | Slow | 100-200ms |

**Key:** Uses EXLA backend (same as training) for GPU acceleration. GPU support depends on XLA_TARGET configuration.

### 3. DATABASE (PostgreSQL + pgvector)
**Purpose:** Store vectors + metadata (all environments share same DB)
**Control:** Nix auto-startup

| Environment | Database | Strategy |
|-------------|----------|----------|
| macOS dev | singularity (localhost:5432) | Shared with prod |
| RTX 4080 prod | singularity (localhost:5432) | Shared with dev |
| Test/CI | singularity (Ecto.Sandbox) | Sandboxed transactions |

**Key:** Single database for living knowledge base (internal tooling strategy).

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│ APPLICATION                                                      │
│ (Elixir + Gleam)                                                 │
└────────────────┬──────────────────────────────────────────────────┘
                 │
     ┌───────────┼───────────┐
     │           │           │
     ▼           ▼           ▼
┌────────────┐ ┌──────────┐ ┌────────────┐
│   EXLA     │ │  EXLA    │ │PostgreSQL  │
│ (Training) │ │(Embeddings)│ (Storage)  │
└─────┬──────┘ └────┬─────┘ └────────────┘
      │             │
      └─────┬───────┘
            │
       XLA_TARGET (unified)
            │
   macOS: :host (CPU)
   Prod: :cuda (CUDA)
```

## Execution Flow

### macOS Development
```
nix develop
  ├─ PostgreSQL starts (localhost:5432)
  ├─ XLA_TARGET detected → metal → EXLA uses CPU (:host)
  │  ├─ CodeT5p training: Slow (CPU only)
  │  └─ Embedding inference + fine-tuning: Slow (CPU only via Nx/Axon)
  │     └─ Both use same EXLA backend
  │     └─ Models: Qodo-Embed-1 + Jina v3 (2560-dim concatenated)
  └─ Result: Pure Elixir Nx tensor operations (no external inference APIs)

Performance:
- Embedding inference: ~15-50ms per text (CPU only)
- Embedding fine-tuning: Supported but slow (CPU only)
- Training: CPU only (not suitable for production)
- Shared database with prod (learning across environments)
```

### RTX 4080 Production
```
nix develop
  ├─ PostgreSQL starts (localhost:5432)
  ├─ XLA_TARGET detected → cuda118 (via nvidia-smi) → EXLA uses CUDA (:cuda)
  │  ├─ CodeT5p training: Fast (CUDA GPU - 1-5 tokens/sec)
  │  └─ Embedding inference + fine-tuning: Fast (CUDA GPU via Nx/Axon)
  │     └─ Both CodeT5p and embeddings use same CUDA backend
  │     └─ Models: Qodo-Embed-1 + Jina v3 (2560-dim concatenated)
  └─ Result: Pure Elixir Nx tensor operations with GPU acceleration

Performance:
- Embedding inference: ~5-15ms per text (CUDA GPU)
- Embedding fine-tuning: Fast (CUDA GPU - RTX 4080)
- Training: Fast (CUDA GPU - both CodeT5p + embeddings)
- Shared database with dev (living knowledge base)
```

## Key Insights

### Unified Nx/EXLA Backend (Training + Embeddings)
- **Single backend:** Both CodeT5p training and Qodo/Jina embeddings use EXLA
- **macOS:** Limited to CPU (:host) because XLA doesn't support Metal upstream
- **RTX 4080:** Uses CUDA (:cuda) for both training and embedding inference/fine-tuning
- **Models:** Pure Elixir Axon models with safetensors/ONNX weight loading
- **Result:** Consistent device handling, simplified configuration

### Database Strategy
- **Single shared database:** All environments learn together
- **Internal tooling:** No multi-tenancy needed
- **Living knowledge base:** Models improve across dev/test/prod

## Configuration

### Zero Manual Setup
All three layers auto-detect:

```bash
# Automatic (no config needed)
nix develop                          # PostgreSQL starts
XLA_TARGET="${auto-detected}"        # CUDA → Metal → CPU
ONNX auto-selects GPU                # Uses best available

# Optional overrides
export XLA_TARGET=cpu                # Force CPU for testing
export SINGULARITY_DB_HOST=remotedb  # Use external database
```

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `XLA_TARGET` | Auto | `cuda118` / `metal` / `cpu` |
| `SINGULARITY_DB_HOST` | `localhost` | PostgreSQL host |
| `SINGULARITY_DB_PORT` | `5432` | PostgreSQL port |
| `SINGULARITY_DB_NAME` | `singularity` | Database name |

## Performance Targets

### Development (macOS + Nx CPU)
| Task | Latency | Throughput | Notes |
|------|---------|-----------|-------|
| Embedding inference | 15-50ms | 20-65 emb/sec | Qodo (1536) + Jina v3 (1024) concatenated |
| Vector search (2560-dim) | 10-50ms | 20-100 queries/sec | pgvector |
| CodeT5p training | Slow | <1 token/sec | CPU only - not for prod |
| Embedding fine-tuning | Supported | Very slow | CPU only - not recommended |

### Production (RTX 4080 + EXLA CUDA)
| Task | Latency | Throughput | Notes |
|------|---------|-----------|-------|
| Embedding inference | 5-15ms | 65-200 emb/sec | Qodo (1536) + Jina v3 (1024) concatenated |
| Vector search (2560-dim) | 5-20ms | 50-200 queries/sec | pgvector |
| CodeT5p training | N/A | 1-5 tokens/sec | EXLA CUDA GPU |
| Embedding fine-tuning | Supported | Fast | EXLA CUDA GPU (available now) |

## Deployment Checklist

- [ ] `nix develop` enters shell
- [ ] PostgreSQL auto-starts
- [ ] XLA_TARGET auto-detected correctly (CUDA on RTX 4080, :host on macOS)
- [ ] Nx/EXLA embeddings run (Axon models via Nx tensor operations)
- [ ] Embedding service online (NxService.embed/1)
- [ ] Vector search returns results
- [ ] Same database as dev (living knowledge base)

## Next Steps

1. **Current:** Qodo + Jina v3 embeddings (2560-dim concatenated) via pure Elixir Nx
2. **Now available:** Embedding fine-tuning on RTX 4080 (EXLA CUDA)
3. **Q1 2026:** Fine-tune StarCoder2-7B on RTX 4080
4. **Optional:** Optimize macOS inference via Nx native backend or explore accelerators

## References

- `DEPLOYMENT_GUIDE.md` - Full deployment instructions
- `singularity/config/runtime.exs` - EXLA and embedding configuration
- `.envrc` - Environment auto-detection
- `singularity/lib/singularity/embedding/` - Pure Elixir embedding modules
  - `nx_service.ex` - Main embedding service API
  - `model.ex` - Axon model definitions
  - `model_loader.ex` - Weight loading (safetensors/ONNX)
  - `trainer.ex` - Fine-tuning support
  - `tokenizer.ex` - Text tokenization
- `singularity/config/config.exs` - Database configuration
