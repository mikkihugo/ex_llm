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

### 2. EMBEDDINGS (ONNX Runtime + Rust NIF)
**Purpose:** Vector generation (inference only, not training)
**Control:** ONNX auto-detection (independent of XLA_TARGET)

| Platform | GPU Available | Speed | Latency |
|----------|---|--------|---------|
| macOS dev | Metal GPU | Fast | 5-10ms |
| RTX 4080 prod | CUDA GPU | Fast | 5-10ms |
| Linux no GPU | None | Moderate | 10-20ms |

**Key:** ONNX independently detects and uses available GPU. Metal works great for embeddings!

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
│   EXLA     │ │  ONNX    │ │PostgreSQL  │
│ (Training) │ │(Embeddings)│ (Storage)  │
└─────┬──────┘ └────┬─────┘ └────────────┘
      │             │
      ├─XLA_TARGET  ├─Auto-detect (independent)
      │             │
   macOS: CPU    macOS: Metal GPU ✓
   Prod: CUDA    Prod: CUDA GPU ✓
      │             │
      └─EXLA CPU    └─5-10ms fast inference
```

## Execution Flow

### macOS Development
```
nix develop
  ├─ PostgreSQL starts (localhost:5432)
  ├─ XLA_TARGET detected → metal
  │  ├─ EXLA configured with CPU (:host)
  │  ├─ CodeT5p training: Slow (CPU only)
  │  └─ Embedding fine-tuning: Disabled (production only on RTX 4080)
  └─ ONNX detects Metal GPU
     └─ Jina v3/Qodo embeddings: Fast inference (Metal GPU - 5-10ms)

Result:
- Fast inference embeddings (Metal GPU)
- Slow training (CPU only - not suitable for production)
- Shared database with prod (learning across environments)
```

### RTX 4080 Production
```
nix develop
  ├─ PostgreSQL starts (localhost:5432)
  ├─ XLA_TARGET detected → cuda118 (via nvidia-smi)
  │  ├─ EXLA configured with CUDA (:cuda)
  │  ├─ CodeT5p training: Fast (CUDA GPU - 1-5 tokens/sec)
  │  └─ Embedding fine-tuning: Fast (CUDA GPU - full training on RTX 4080)
  └─ ONNX detects CUDA GPU
     └─ Jina v3/Qodo embeddings: Fast inference + training (CUDA GPU)

Result:
- Fast inference embeddings (CUDA GPU - 5-10ms)
- Fast training (CUDA GPU - both CodeT5p + embeddings)
- Shared database with dev (living knowledge base)
```

## Key Insights

### ONNX Embeddings Work Independently
- **macOS:** Uses Metal GPU automatically (Metal ≠ Metal for XLA)
- **RTX 4080:** Uses CUDA GPU automatically
- **No config needed:** ONNX Runtime detects best GPU
- **Speed:** 5-10ms per embedding (both platforms)

### EXLA Training is Separate
- **macOS:** Limited to CPU (XLA doesn't support Metal upstream)
- **RTX 4080:** Uses CUDA for fast training
- **Future:** StarCoder2-7B fine-tuning ready on RTX 4080

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

### Development (macOS + Metal)
| Task | Latency | Throughput | Notes |
|------|---------|-----------|-------|
| Embedding inference | 5-10ms | 100+ emb/sec | Metal GPU (Jina v3) |
| Vector search (1536-dim) | 10-50ms | 20-100 queries/sec | pgvector + Metal |
| CodeT5p training | Slow | <1 token/sec | CPU only - not for prod |
| Embedding fine-tuning | N/A | Disabled | Production only |

### Production (RTX 4080 + CUDA)
| Task | Latency | Throughput | Notes |
|------|---------|-----------|-------|
| Embedding inference | 5-10ms | 100+ emb/sec | CUDA GPU (Jina v3) |
| Vector search (1536-dim) | 5-20ms | 50-200 queries/sec | pgvector + CUDA |
| CodeT5p training | N/A | 1-5 tokens/sec | CUDA GPU |
| Embedding fine-tuning | N/A | 50-100k tokens/sec | CUDA GPU (Q1 2026) |

## Deployment Checklist

- [ ] `nix develop` enters shell
- [ ] PostgreSQL auto-starts
- [ ] XLA_TARGET auto-detected correctly
- [ ] ONNX embeddings run on GPU (Metal/CUDA)
- [ ] Vector search returns results
- [ ] Same database as dev (learning across environments)

## Next Steps

1. **Current:** Jina v3 embeddings on Metal/CUDA (5-10ms fast!)
2. **3-6 months:** Collect Rust/Elixir training data
3. **Q1 2026:** Fine-tune StarCoder2-7B on RTX 4080
4. **Optional:** Explore MLX embeddings on Metal for even faster dev

## References

- `DEPLOYMENT_GUIDE.md` - Full deployment instructions
- `singularity/config/runtime.exs` - EXLA configuration
- `.envrc` - Environment auto-detection
- `singularity/config/config.exs` - Database configuration
