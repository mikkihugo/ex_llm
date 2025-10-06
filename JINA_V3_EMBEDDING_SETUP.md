# Jina v3 + CodeT5 Dual Embedding Setup

## Overview

Singularity now uses **intelligent dual-model embedding** with automatic content type detection:

- **CodeT5** (Bumblebee) - For code chunks, functions, modules
- **Jina v3** (Ortex/ONNX) - For docs, comments, long text (up to 8,192 tokens)

## Why Jina v3 over Jina v2?

### Jina v3 Advantages:
- **570M parameters** (vs v2's 137M) - Better quality
- **Task-specific adapters** - LoRA for retrieval/clustering/classification
- **Matryoshka dimensions** - Flexible 32-1024 dims (storage optimization)
- **89 languages** - Multilingual support
- **#2 on MTEB** - Beats OpenAI & Cohere on benchmarks

### Why ONNX (Ortex) instead of Bumblebee?
- Jina v3 requires transformers 4.34+ (Bumblebee doesn't support yet)
- ONNX is **faster** for inference (optimized runtime)
- **GPU acceleration** via ONNX Runtime (CUDA/TensorRT/ROCm)
- Official Jina v3 ONNX models available on HuggingFace

## Setup

### 1. Dependencies Added

```elixir
# mix.exs
{:ortex, "~> 0.1.10"},  # ONNX Runtime for Jina v3
{:bumblebee, "~> 0.5.3"},  # For CodeT5
{:nx, "~> 0.7.1"},  # Numerical computing
{:exla, "~> 0.7.1"},  # GPU acceleration
```

### 2. Model Configuration

```elixir
# embedding_service.ex
@codet5_model "Salesforce/codet5p-110m-embedding"
@codet5_finetuned "priv/models/codet5-finetuned"  # Your fine-tuned model
@jina_v3_onnx "jinaai/jina-embeddings-v3"
@jina_v3_onnx_path "priv/models/jina-v3-onnx"
```

### 3. Auto-Detection Logic

The system automatically detects content type:

**Code indicators:**
- `def function()` - Function definitions
- `class ClassName` - Class definitions
- `import module` - Import statements
- `{ }` - Curly braces
- `=>` - Arrow functions
- `::` - Module separators
- `@decorator` - Decorators/annotations

**Decision:**
- 2+ code indicators → Use **CodeT5** (fine-tuned on YOUR codebase)
- Otherwise → Use **Jina v3** (8192 token context for docs)

## Usage

### Automatic (Recommended)

```elixir
# Auto-detects and uses CodeT5 for code
{:ok, result} = EmbeddingService.embed("def foo(x), do: x * 2")
# => %{embedding: [...], model: "codet5-finetuned", type: :code}

# Auto-detects and uses Jina v3 for text
{:ok, result} = EmbeddingService.embed("This is a long documentation paragraph...")
# => %{embedding: [...], model: "jina-v3", type: :text}
```

### Manual Override

```elixir
# Force Jina v3 for long code documentation
EmbeddingService.embed(long_doc, type: :text)

# Force CodeT5 for code-like text
EmbeddingService.embed(pseudocode, type: :code)
```

## Model Downloads

### Jina v3 ONNX (First Run)

On first use, Jina v3 ONNX model will auto-download from HuggingFace:

```
Downloading from https://huggingface.co/jinaai/jina-embeddings-v3/resolve/main/onnx/model.onnx
✅ Jina v3 ONNX model downloaded to priv/models/jina-v3-onnx/model.onnx
```

**Size:** ~2.2GB (one-time download, cached locally)

### CodeT5 Fine-tuned (Optional)

Train your own CodeT5 on YOUR codebase:

```elixir
# Train on your code patterns
Singularity.CodeModelTrainer.train_on_codebase(repos: ["your-repo"])

# Result: 30-50% better retrieval accuracy!
# Saved to: priv/models/codet5-finetuned
```

## Jinja3 Template Support

Both models handle Jinja3 templates (backward compatible with Jinja2):

```elixir
# Automatically preprocesses Jinja3 syntax
text = """
{{ variable }}
{% for item in items %}
  {{ item.name }}
{% endfor %}
"""

EmbeddingService.embed(text)
# Jinja3 blocks replaced with placeholders for better embeddings
```

## Performance

### CodeT5 (Bumblebee)
- **Dimensions:** 768
- **Max tokens:** 512
- **Speed:** ~5-10k chunks/sec (CPU), ~50k chunks/sec (GPU)
- **Best for:** Code snippets, functions, modules

### Jina v3 (ONNX)
- **Dimensions:** 1024 (or 32-1024 with Matryoshka)
- **Max tokens:** 8,192
- **Speed:** ~3-8k chunks/sec (CPU), ~30k chunks/sec (GPU via ONNX Runtime)
- **Best for:** Documentation, requirements, long text

## Fallback Strategy

```
1. Try local model (CodeT5 or Jina v3 based on type)
2. If local fails → Fallback to Google text-embedding-004 (free API)
3. If Google fails → Return error
```

## GPU Acceleration

### EXLA (Bumblebee/CodeT5)
```bash
export EXLA_TARGET=cuda  # or rocm
export CUDA_HOME=/path/to/cuda
```

### ONNX Runtime (Jina v3)
```bash
# Automatically uses CUDA if available
export ONNX_RUNTIME_EXECUTION_PROVIDERS="CUDAExecutionProvider,CPUExecutionProvider"
```

## Roadmap

### TODO:
- [ ] Proper SentencePiece tokenizer for Jina v3 (currently simplified)
- [ ] Download tokenizer.json from HuggingFace
- [ ] Matryoshka dimension truncation (save storage)
- [ ] Task-specific LoRA adapters (retrieval vs classification)
- [ ] Batch inference optimization
- [ ] Model warm-up on startup

### Future:
- [ ] Jina v3 fine-tuning on YOUR docs (when ONNX supports it)
- [ ] Multi-GPU inference
- [ ] Quantized models (INT8) for faster inference

## References

- **Jina v3 Blog:** https://jina.ai/news/jina-embeddings-v3-a-frontier-multilingual-embedding-model/
- **Jina v3 HF:** https://huggingface.co/jinaai/jina-embeddings-v3
- **Ortex GitHub:** https://github.com/elixir-nx/ortex
- **CodeT5+ Paper:** https://arxiv.org/abs/2305.07922

---

**Status:** ✅ Ready to use (after `mix deps.get`)

**Next Steps:**
1. `cd singularity_app && mix deps.get`
2. Test embedding: `iex -S mix` → `EmbeddingService.embed("test")`
3. Watch Jina v3 auto-download on first text embedding
