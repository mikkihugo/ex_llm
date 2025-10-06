# Rust Embeddings Setup - Using EmbeddingEngine (Not Bumblebee!)

## Clarification

You're using **Rust-based embeddings** (fast, GPU-accelerated via ONNX/Candle), NOT Bumblebee!

### Your Models (Rust NIF):
- **Jina v3** (ONNX Runtime) - 8192 tokens, 1024 dims, for text/docs
- **Qodo-Embed-1** (Candle) - 32k tokens, 1536 dims, for code (SOTA!)

### Why Rust > Bumblebee:
- ✅ 10-100x faster (native Rust + GPU)
- ✅ Non-blocking (dirty scheduler, won't freeze BEAM)
- ✅ Batch optimized (process 100+ texts at once)
- ✅ Lower memory (models loaded once in Rust)

## Problem Fixed

### Issue 1: Missing Rust Toolchain in Nix ✅

**Before:**
```nix
# Only cargo tools, no rustc/cargo itself!
rust-analyzer
cargo-audit
cargo-watch
# ... etc
```

**After:**
```nix
# Added base Rust toolchain
rustc        # Rust compiler
cargo        # Package manager
rustfmt      # Code formatter
clippy       # Linter

# Then cargo tools...
rust-analyzer
cargo-audit
# ... etc
```

**File changed:** ✅ `flake.nix`

### Issue 2: Wrong Rustler Path ✅

**Before:**
```elixir
use Rustler, otp_app: :singularity, crate: "embedding_engine"
# Looked in: native/embedding_engine (doesn't exist)
```

**After:**
```elixir
use Rustler,
  otp_app: :singularity,
  crate: "embedding_engine",
  path: Path.join([__DIR__, "..", "..", "..", "rust", "embedding_engine"])
# Now looks in: rust/embedding_engine (correct!)
```

**File changed:** ✅ `lib/singularity/embedding_engine.ex`

## Next Steps

### 1. Reload Nix Environment

Since we updated `flake.nix`, you need to reload:

```bash
# Exit current shell
exit

# Re-enter with updated flake
nix develop

# Or with direnv
direnv reload

# Verify Rust is available
cargo --version  # Should show: cargo 1.x.x
rustc --version  # Should show: rustc 1.x.x
```

### 2. Compile Rust NIF

```bash
cd singularity_app

# This will now compile the Rust NIF
mix compile

# Or manually build just the Rust part
cd ../rust/embedding_engine
cargo build --release
```

### 3. Update KnowledgeArtifactStore

Change from `EmbeddingGenerator` (Bumblebee) to `EmbeddingEngine` (Rust):

```elixir
# lib/singularity/knowledge/artifact_store.ex

# BEFORE (wrong - uses Bumblebee)
alias Singularity.EmbeddingGenerator

case EmbeddingGenerator.embed(text, provider: :auto) do

# AFTER (correct - uses Rust NIF)
alias Singularity.EmbeddingEngine

case EmbeddingEngine.embed(text, model: :jina_v3) do  # or :qodo_embed for code
```

### 4. Test Embeddings

```elixir
# In IEx
iex -S mix

# Test Jina v3 (text/docs)
iex> EmbeddingEngine.embed("async worker pattern", model: :jina_v3)
{:ok, [0.123, 0.456, ...]}  # 1024 dims

# Test Qodo-Embed-1 (code - SOTA!)
iex> EmbeddingEngine.embed("def foo(x), do: x * 2", model: :qodo_embed)
{:ok, [0.789, 0.012, ...]}  # 1536 dims

# Batch processing (much faster!)
iex> texts = ["text1", "text2", "text3"]
iex> EmbeddingEngine.embed_batch(texts, model: :jina_v3)
{:ok, [[...], [...], [...]]}
```

## Rust NIF Architecture

```
┌─────────────────────────────────────────┐
│    Elixir (BEAM)                        │
│                                         │
│  EmbeddingEngine.embed(text)            │
│         ↓                               │
│  Rustler NIF call (non-blocking)        │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│    Rust (Native Code)                   │
│                                         │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │  Jina v3     │  │  Qodo-Embed-1   │ │
│  │  (ONNX RT)   │  │  (Candle)       │ │
│  │  8192 tokens │  │  32k tokens     │ │
│  │  1024 dims   │  │  1536 dims      │ │
│  └──────────────┘  └─────────────────┘ │
│         ↓                  ↓            │
│    RTX 4080 GPU (CUDA)                  │
└─────────────────────────────────────────┘
           ↓
    [0.123, 0.456, ...]  # Fast embeddings!
```

## Model Selection Guide

### Use Jina v3 for:
- ✅ General text
- ✅ Documentation
- ✅ Long documents (up to 8192 tokens)
- ✅ Natural language queries

**Dimensions:** 1024

### Use Qodo-Embed-1 for:
- ✅ Source code
- ✅ Code snippets
- ✅ Function signatures
- ✅ Technical content

**Dimensions:** 1536 (better for code!)

## Knowledge Base Integration

### Update artifact_store.ex

```elixir
defmodule Singularity.Knowledge.ArtifactStore do
  alias Singularity.EmbeddingEngine  # Use Rust NIF, not Bumblebee!

  defp generate_embedding_async(artifact) do
    text = generate_embedding_text(artifact)

    # Choose model based on artifact type
    model = case artifact.artifact_type do
      type when type in ["code_template", "code_pattern"] ->
        :qodo_embed  # Code: use Qodo (1536 dims)

      _ ->
        :jina_v3  # Text/docs: use Jina v3 (1024 dims)
    end

    case EmbeddingEngine.embed(text, model: model) do
      {:ok, embedding} ->
        # Convert to Pgvector
        pgvector = Pgvector.new(embedding)

        artifact
        |> KnowledgeArtifact.changeset(%{embedding: pgvector})
        |> Repo.update()

      {:error, reason} ->
        Logger.error("Embedding failed: #{inspect(reason)}")
    end
  end

  def search(query_text, opts \\ []) do
    # Detect if query is code or text
    model = if code_query?(query_text), do: :qodo_embed, else: :jina_v3

    case EmbeddingEngine.embed(query_text, model: model) do
      {:ok, embedding} ->
        pgvector = Pgvector.new(embedding)
        results = search_by_embedding(pgvector, opts)
        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp code_query?(text) do
    # Simple heuristic: contains code keywords or syntax
    String.match?(text, ~r/(def|defmodule|fn|function|class|async|await|\(|\)|=>|->)/)
  end
end
```

## Database Migration Note

Since we're changing embedding dimensions (Bumblebee uses 768, Rust uses 1024 or 1536), you may need to:

### Option 1: Keep 1536 dims (supports both models)
```sql
-- Current schema already uses 1536
ALTER TABLE knowledge_artifacts
ALTER COLUMN embedding TYPE vector(1536);
```

✅ **This works!** Jina v3 (1024) can be padded to 1536, or use Qodo exclusively (1536 native).

### Option 2: Use different tables per model
```sql
-- Jina v3 artifacts (text)
CREATE TABLE knowledge_artifacts_text (
  ...
  embedding vector(1024)
);

-- Qodo artifacts (code)
CREATE TABLE knowledge_artifacts_code (
  ...
  embedding vector(1536)
);
```

❌ **Don't do this** - unnecessary complexity for internal tooling!

## Summary

✅ **Fixed flake.nix** - Added rustc/cargo to Nix environment
✅ **Fixed embedding_engine.ex** - Corrected Rustler path to rust/embedding_engine
⏳ **Need to**: Reload Nix shell, compile Rust NIF, test embeddings
⏳ **Need to**: Update ArtifactStore to use EmbeddingEngine instead of EmbeddingGenerator

**You're using the FAST embeddings (Rust + GPU), not the slow ones (Bumblebee)!** 🚀

---

**Next:** Reload Nix environment and compile!

```bash
# Exit and re-enter Nix shell
exit
nix develop

# Verify Rust is available
cargo --version

# Compile everything
cd singularity_app
mix compile
```
