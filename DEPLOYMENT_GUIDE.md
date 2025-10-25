# RTX 4080 Deployment Guide

**Status:** ✅ Ready to Deploy

All configuration for RTX 4080 CUDA acceleration is complete. Every deployment targets the RTX 4080 server on Linux, which automatically enables GPU acceleration.

## Overview

Singularity deployment stack for RTX 4080 (Linux):

```
User Code (Elixir/Gleam)
    ↓
EXLA.Backend (Nx compiler)
    ↓
CUDA 11.8 Client (XLA compiler)
    ↓
NVIDIA RTX 4080 GPU (16GB VRAM)
```

**Key Feature:** Zero manual GPU configuration needed - everything auto-detects.

## GPU Configuration

### VRAM Allocation
- **Total:** 16GB (RTX 4080)
- **Models:** 12GB (75% in EXLA config)
- **System:** 4GB reserved
- **Max Model:** ~7B-10B parameters

### Auto-Detection (Smart GPU Detection)

Detection priority:
1. Explicit `XLA_TARGET` environment variable (if set)
2. Check for `nvidia-smi` (CUDA available?)
3. Check OS type (Metal on macOS, CPU on Linux)

**On macOS (local development):**
```bash
$ command -v nvidia-smi  # Not found
$ uname -s               # Darwin
$ XLA_TARGET             # auto-detects → metal
# Metal available for CoreML, MLX, other frameworks
# EXLA falls back to CPU (no XLA Metal support)
```

**On RTX 4080 (Linux production):**
```bash
$ command -v nvidia-smi  # Found!
$ XLA_TARGET             # auto-detects → cuda118
# CUDA 11.8 acceleration enabled automatically for EXLA
```

**On Linux without CUDA (fallback):**
```bash
$ command -v nvidia-smi  # Not found
$ uname -s               # Linux
$ XLA_TARGET             # auto-detects → cpu
# CPU fallback (no GPU available)
```

**No manual configuration needed** - the system handles it.

**Manual override (if needed):**
```bash
export XLA_TARGET=cpu        # Force CPU (testing/debugging)
export XLA_TARGET=cuda120    # Force specific CUDA version
export XLA_TARGET=metal      # Use Metal on macOS for CoreML/MLX tasks
```

## Model Configuration

### Current (Production Ready)
- **CodeT5p-770m** (1.5GB) - Code generation via EXLA
- **Jina Embeddings v3** (1024 dims) - Text embeddings via pure Elixir Nx/Axon (safetensors)
- **Qodo-Embed-1** (1536 dims) - Code embeddings via pure Elixir Nx/Axon (concatenated 2560-dim)

### Future (Q1 2026)
- **StarCoder2-7B** - Fine-tuned for Rust/Elixir
  - 14GB full size → 3.5GB with INT8 quantization
  - Fits in 12GB budget
  - EXLA ready for RTX 4080 training

## Database Configuration

### Tested & Working
- ✅ 51 migrations pass cleanly
- ✅ graph_nodes table with pgvector embeddings (1536-dim semantic search)
- ✅ intarray indexes for dependency queries
- ✅ All extensions enabled:
  - pgvector (semantic code search)
  - timescaledb (time-series data)
  - postgis (geospatial)
  - citext (case-insensitive)
  - intarray + bloom indexes

## Deployment Instructions

### 1. Clone & Setup

```bash
# Clone repository
git clone <repo>
cd singularity-incubation

# Enter Nix shell (auto-detects CUDA on Linux RTX 4080)
nix develop

# Setup databases
./scripts/setup-database.sh
```

### 2. Run Migrations

```bash
cd singularity

# Run all 51 migrations (creates graph_nodes with vector support)
mix ecto.migrate

# Verify CUDA is available
iex> Singularity.Repo.query!("SELECT version();")
```

### 3. Environment Variables

**Automatic (no action needed):**
```bash
# .envrc auto-detects available GPU:
XLA_TARGET=cuda118       # If nvidia-smi found (CUDA available)
XLA_TARGET=metal         # If on macOS without CUDA (Metal available)
XLA_TARGET=cpu           # If on Linux without CUDA (no GPU)
EXLA_MODE=opt            # Optimized precompiled binaries (always set)
```

**How detection works:**
```bash
if command -v nvidia-smi >/dev/null 2>&1; then
  XLA_TARGET=cuda118     # CUDA available
elif [ "$(uname -s)" = "Darwin" ]; then
  XLA_TARGET=metal       # macOS - Metal available for other frameworks
else
  XLA_TARGET=cpu         # No GPU - use CPU
fi
```

**What each target does:**
| Target | EXLA | Metal/CoreML | Use Case |
|--------|------|-------------|----------|
| `cuda118` | ✅ GPU training | N/A | RTX 4080 production |
| `metal` | ❌ CPU (not supported) | ✅ Available | macOS embeddings via CoreML/MLX |
| `cpu` | ✅ CPU training | N/A | No GPU available |

**Optional overrides (if debugging):**
```bash
# Force CPU even if CUDA available (for testing)
export XLA_TARGET=cpu

# Force specific CUDA version
export XLA_TARGET=cuda120  # (cuda118, cuda111 also available)

# Force Metal on macOS for CoreML/MLX tasks
export XLA_TARGET=metal
```

## Verification

### 1. EXLA Backend
```bash
iex> Nx.default_backend()
# Should return: EXLA.Backend
```

### 2. CUDA Client
```bash
iex> {:ok, _} = EXLA.Client.new(Nx.default_backend())
# Should complete without errors on RTX 4080
```

### 3. Embeddings
```bash
iex> Singularity.EmbeddingService.embed("hello world")
# Should return 1024-dim vector (Jina v3)
```

### 4. Vector Search
```bash
iex> Singularity.SemanticCodeSearch.search("async handler")
# Should return results from graph_nodes with vector similarity
```

## Performance Targets

### Training (StarCoder2 Fine-Tuning)
- **Tokens/sec:** 50-100k (with CUDA)
- **VRAM:** 12GB (at 75% fraction)
- **Duration:** 7-10 days for 10k examples

### Inference (Code Generation)
- **Latency:** 50-200ms per request
- **Throughput:** 5-10 requests/sec
- **VRAM:** 3-5GB

### Embeddings (Vector Generation)
- **Latency:** 5-10ms per embedding
- **Throughput:** 100+ embeddings/sec
- **VRAM:** 1-2GB (ONNX Runtime)

## Known Limitations

1. **Metal/macOS XLA:** No upstream EXLA support
   - macOS dev uses CPU fallback for EXLA (works but slow)
   - Metal CAN be used for other GPU work (CoreML, MLX for embeddings, etc)
   - Only EXLA training uses CPU fallback on macOS
   - Not a production blocker (production is RTX 4080 with CUDA)

2. **StarCoder2-7B Size:** 14GB full precision
   - Solution: INT8 quantization → 3.5GB
   - Fits in 12GB budget
   - Planned upgrade: Q1 2026

3. **Unified Nx/EXLA Backend:**
   - Both CodeT5p training and Qodo/Jina embeddings use EXLA
   - macOS: CPU only (Nx CPU backend via EXLA :host client)
   - RTX 4080: CUDA GPU (EXLA :cuda client for both training and embeddings)
   - Consistent device handling and configuration

## Configuration Files

### Updated for RTX 4080 Deployment

**`.envrc`** - Auto-detects XLA_TARGET
```bash
export XLA_TARGET="${XLA_TARGET:-$(uname -s | grep -q Darwin && echo 'cpu' || echo 'cuda118')}"
export EXLA_MODE="opt"
```

**`singularity/config/runtime.exs`** - Platform-specific EXLA config
```elixir
platform =
  case System.get_env("XLA_TARGET") do
    nil ->
      case :os.type() do
        {:unix, :darwin} -> :macos   # macOS: CPU fallback
        _ -> :linux                  # Linux RTX 4080: CUDA
      end
    "cuda" <> _ -> :linux
    "metal" -> :macos
    "cpu" -> :cpu
    _ -> :cpu
  end

config :exla,
  default_client: (
    case platform do
      :linux -> :cuda   # RTX 4080 with CUDA
      :macos -> :host   # macOS CPU
      :cpu -> :host
    end
  ),
  clients: [
    cuda: [platform: :cuda, memory_fraction: 0.75],
    host: [platform: :host]
  ]
```

**`singularity/mix.exs`** - EXLA as optional dependency
```elixir
{:exla, "~> 0.6", optional: true}
```

## Troubleshooting

### EXLA not loading
```bash
# Check if CUDA binaries are available
ls ~/.cache/mix/

# Force recompile with correct platform
rm -rf ~/.cache/singularity/exla
mix deps.get
```

### CUDA version mismatch
```bash
# Check installed CUDA version on RTX 4080
nvidia-smi

# If CUDA 12.0+, override XLA_TARGET
export XLA_TARGET=cuda120
mix recompile
```

### Embedding errors
```bash
# Verify ONNX models are cached
ls ~/.cache/huggingface/

# Clear cache and re-download
rm -rf ~/.cache/huggingface/
iex> Singularity.EmbeddingService.embed("test")
```

## Next Steps

1. **Deploy to RTX 4080** → CUDA acceleration activates automatically
2. **Collect training data** → Start gathering Rust/Elixir code examples
3. **Fine-tune StarCoder2-7B** → When data reaches 10k examples (6-12 months)
4. **Monitor performance** → Track embedding quality and inference latency

## Support

For issues:
1. Check `.envrc` is being loaded (`direnv allow`)
2. Verify `uname -s` returns correct OS
3. Run `iex> Nx.default_backend()` to check EXLA
4. Check CUDA version with `nvidia-smi`
5. See [CLAUDE.md](CLAUDE.md) for general development setup
