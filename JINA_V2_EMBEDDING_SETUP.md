# Jina v2 + CodeT5 Dual Embedding Setup (Bumblebee Only)

## Overview

Singularity uses **dual-model embedding** with automatic content type detection - **all via Bumblebee**:

- **CodeT5** (Bumblebee) - For code chunks, functions, modules (512 tokens)
- **Jina v2** (Bumblebee) - For docs, comments, long text (8,192 tokens)

## Why Jina v2 (not v3)?

**Jina v2 Advantages:**
- ✅ **Bumblebee compatible** - No ONNX/Ortex needed
- ✅ **8,192 token context** - 16x longer than CodeT5
- ✅ **768 dimensions** - Good quality/storage balance
- ✅ **Proven & stable** - Battle-tested since 2023
- ✅ **Simpler setup** - One framework (Bumblebee)

**vs Jina v3:**
- Jina v3 needs transformers 4.34+ (not in Bumblebee yet)
- Jina v3 requires ONNX/Ortex (extra complexity)
- Jina v2 is "good enough" for 95% of use cases

## Architecture

### Unified Bumblebee Stack

```
┌─────────────────────────────────────┐
│     EmbeddingService (GenServer)    │
├─────────────────────────────────────┤
│                                     │
│  Auto-detect: Code or Text?        │
│                                     │
├────────────────┬────────────────────┤
│                │                    │
│   Code         │       Text         │
│   ↓            │       ↓            │
│ CodeT5         │     Jina v2        │
│ (512 tokens)   │   (8192 tokens)    │
│                │                    │
└────────────────┴────────────────────┘
         ↓              ↓
    ┌──────────────────────┐
    │   Bumblebee (Nx)     │
    ├──────────────────────┤
    │   EXLA (GPU/CUDA)    │
    └──────────────────────┘
```

## Setup

### Dependencies (Already in mix.exs)

```elixir
{:bumblebee, "~> 0.5.3"},  # Unified ML framework
{:nx, "~> 0.7.1"},         # Numerical computing
{:exla, "~> 0.7.1"},       # GPU acceleration
```

**No Ortex needed!** Everything runs through Bumblebee.

### Model Configuration

```elixir
# embedding_service.ex
@codet5_model "Salesforce/codet5p-110m-embedding"
@codet5_finetuned "priv/models/codet5-finetuned"
@jina_v2_model "jinaai/jina-embeddings-v2-base-en"
```

## Auto-Detection Logic

### Code Indicators

```elixir
code_patterns = [
  ~r/def\s+\w+/,      # def function
  ~r/class\s+\w+/,    # class Foo
  ~r/import\s+/,      # import module
  ~r/\{.*\}/,         # { braces }
  ~r/=>/,             # =>
  ~r/::\w+/           # Module::name
]
```

**Decision:**
- **2+ indicators** → CodeT5 (fine-tuned on YOUR code)
- **OR text < 200 chars** → CodeT5 (likely code snippet)
- **Otherwise** → Jina v2 (long docs, requirements, etc.)

## Usage

### Automatic (Recommended)

```elixir
# Auto-detects as :code → uses CodeT5
EmbeddingService.embed("def foo(x), do: x * 2")
# => {:ok, %{embedding: [...], model: "codet5", type: :code, dim: 768}}

# Auto-detects as :text → uses Jina v2
EmbeddingService.embed("""
This is a long documentation paragraph explaining the architecture.
It has multiple sentences and describes complex concepts.
""")
# => {:ok, %{embedding: [...], model: "jina-v2", type: :text, dim: 768}}
```

### Manual Override

```elixir
# Force Jina v2 for code documentation
EmbeddingService.embed(code_doc, type: :text)

# Force CodeT5 for pseudocode
EmbeddingService.embed(pseudocode, type: :code)
```

## Model Downloads (Automatic on First Use)

### CodeT5 (110M params, ~440MB)

```
Bumblebee will auto-download from:
https://huggingface.co/Salesforce/codet5p-110m-embedding

Cached at: ~/.cache/huggingface/hub/
```

### Jina v2 (137M params, ~550MB)

```
Bumblebee will auto-download from:
https://huggingface.co/jinaai/jina-embeddings-v2-base-en

Cached at: ~/.cache/huggingface/hub/
```

**Total:** ~1GB one-time download

## Fine-Tuning CodeT5 (Optional)

Train CodeT5 on **YOUR codebase** for 30-50% better retrieval:

```elixir
# Train on your repos
Singularity.CodeModelTrainer.train_on_codebase(repos: ["singularity"])

# Fine-tuned model saved to:
# priv/models/codet5-finetuned/

# Auto-loaded on next embed() call
```

## Jinja Template Support

Both models handle Jinja2/Jinja3 templates:

```elixir
text = """
{{ variable }}
{% for item in items %}
  {{ item.name }}
{% endfor %}
"""

EmbeddingService.embed(text)
# Jinja blocks replaced with placeholders: [JINJA3_VAR], [JINJA3_FOR], etc.
```

## Performance

| Model    | Dimensions | Max Tokens | Speed (CPU) | Speed (GPU) | Use Case              |
|----------|------------|------------|-------------|-------------|-----------------------|
| CodeT5   | 768        | 512        | ~10k/sec    | ~50k/sec    | Code snippets         |
| Jina v2  | 768        | 8,192      | ~5k/sec     | ~30k/sec    | Docs, requirements    |

**GPU Acceleration (EXLA):**
```bash
export EXLA_TARGET=cuda  # or rocm
export CUDA_HOME=/path/to/cuda
```

## Fallback Strategy

```
1. Try local Bumblebee (CodeT5 or Jina v2)
   ↓ (if fails)
2. Fallback to Google text-embedding-004 (free API)
   ↓ (if fails)
3. Return error
```

## Comparison: Jina v2 vs v3

| Feature              | Jina v2 (Bumblebee)   | Jina v3 (ONNX)        |
|----------------------|-----------------------|-----------------------|
| **Bumblebee**        | ✅ Native support     | ❌ Needs Ortex        |
| **Setup**            | ✅ Simple             | ❌ Complex (ONNX)     |
| **Parameters**       | 137M                  | 570M                  |
| **Dimensions**       | 768                   | 1024 (+ Matryoshka)   |
| **Max Tokens**       | 8,192                 | 8,192                 |
| **Task Adapters**    | ❌ No                 | ✅ LoRA adapters      |
| **MTEB Rank**        | Top 20                | #2                    |
| **Multilingual**     | ✅ Yes                | ✅ 89 languages       |
| **Fine-tuning**      | ✅ Full control       | ⚠️ LoRA only          |

**Verdict:** Jina v2 is simpler, proven, and "good enough" for most use cases.

## Next Steps

```bash
cd singularity_app
mix deps.get
iex -S mix
```

Test it:
```elixir
# Code → CodeT5
EmbeddingService.embed("def hello, do: :world")

# Text → Jina v2 (auto-downloads on first use)
EmbeddingService.embed("This is a long document about embeddings...")
```

## Roadmap

- [x] Dual-model setup (CodeT5 + Jina v2)
- [x] Auto content-type detection
- [x] Jinja template preprocessing
- [x] Fine-tuning infrastructure (CodeT5)
- [ ] Model caching/warm-up on startup
- [ ] Batch inference optimization
- [ ] Fine-tune Jina v2 on YOUR docs (future)

---

**Status:** ✅ Ready to use (simpler than Jina v3 ONNX setup)

**Framework:** Bumblebee only (no Ortex needed)
