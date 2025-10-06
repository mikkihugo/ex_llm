# Embedding Consolidation - The Best Way

## Current Situation (3 Modules! 😱)

You have **THREE** embedding modules doing overlapping work:

### 1. `EmbeddingEngine` (Rust NIF - BROKEN)
- **Location**: `lib/singularity/embedding_engine.ex`
- **Tech**: Rustler NIF (native Rust)
- **Models**: Jina v3 (ONNX), Qodo-Embed-1 (Candle)
- **Status**: ❌ **BROKEN** - requires cargo, compilation fails
- **Pros**: Fast (native Rust + GPU), non-blocking (dirty scheduler)
- **Cons**: Complex setup, requires Rust toolchain, currently not working

### 2. `EmbeddingService` (Bumblebee)
- **Location**: `lib/singularity/embedding_service.ex`
- **Tech**: Bumblebee (pure Elixir/Nx)
- **Models**: CodeT5 (code), Jina v2 (text)
- **Status**: ⚠️ **PARTIAL** - Bumblebee setup needed
- **Pros**: Pure Elixir, no Rust needed, GPU via EXLA
- **Cons**: Blocking BEAM (unless using dirty scheduler)

### 3. `EmbeddingGenerator` (Hybrid with Fallback)
- **Location**: `lib/singularity/llm/embedding_generator.ex`
- **Tech**: Bumblebee (local) → Google AI (cloud fallback)
- **Models**: Jina v2 (local) → text-embedding-004 (Google)
- **Status**: ✅ **WORKS** - has fallback chain
- **Pros**: Automatic fallback, works even if local fails
- **Cons**: Cloud dependency for fallback

## The Best Way: Consolidate to ONE Module

**For internal tooling, use `EmbeddingGenerator` as the single source of truth.**

### Why EmbeddingGenerator is Best

1. ✅ **Already works** - has fallback to Google AI
2. ✅ **Simplest setup** - no Rust compilation needed
3. ✅ **Automatic fallback** - never fails (falls back to cloud)
4. ✅ **Good enough for internal use** - Bumblebee is fast enough
5. ✅ **Less complexity** - one module, one API

### Recommended Architecture

```
EmbeddingGenerator (Single Entry Point)
    ↓
Try Local (Bumblebee/GPU)
    - Jina v2 (768 dims) for general text
    - CodeBERT for code (optional)
    ↓ (if local fails)
Fallback to Cloud (Google AI)
    - text-embedding-004 (768 dims)
    - FREE tier: 1500 requests/day
    ↓ (if cloud fails)
Zero vector (graceful degradation)
```

## Consolidation Plan

### Step 1: Make EmbeddingGenerator the Standard

**Update all code to use `EmbeddingGenerator.embed/2`:**

```elixir
# OLD (multiple modules)
EmbeddingService.embed(text)
EmbeddingEngine.embed(text)

# NEW (single module)
EmbeddingGenerator.embed(text)  # Auto-fallback included
```

### Step 2: Deprecate Other Modules

**Mark as deprecated:**

```elixir
# embedding_service.ex
@deprecated "Use Singularity.EmbeddingGenerator instead"

# embedding_engine.ex
@deprecated "Rustler NIF version - use Singularity.EmbeddingGenerator for simpler setup"
```

### Step 3: Update ArtifactStore

**In `artifact_store.ex`, use EmbeddingGenerator:**

```elixir
defp generate_embedding_async(artifact) do
  text = generate_embedding_text(artifact)

  case Singularity.EmbeddingGenerator.embed(text) do
    {:ok, embedding} ->
      artifact
      |> KnowledgeArtifact.changeset(%{embedding: embedding})
      |> Repo.update()

    {:error, reason} ->
      Logger.error("Embedding failed for #{artifact.artifact_id}: #{inspect(reason)}")
  end
end
```

## Implementation (Internal Tooling - Optimized)

### Enhanced EmbeddingGenerator

```elixir
defmodule Singularity.EmbeddingGenerator do
  @moduledoc """
  **Single source of truth for embeddings** (internal tooling).

  Fallback chain (optimized for dev experience):
  1. Local Bumblebee (Jina v2) - Fast, GPU-accelerated, private
  2. Google AI (text-embedding-004) - Cloud fallback, FREE
  3. Zero vector - Graceful degradation

  ## Usage

      # Standard (auto-fallback)
      {:ok, embedding} = EmbeddingGenerator.embed("async worker pattern")

      # Force local only
      {:ok, embedding} = EmbeddingGenerator.embed("code", provider: :bumblebee)

      # Force cloud only
      {:ok, embedding} = EmbeddingGenerator.embed("text", provider: :google)
  """

  require Logger

  @type embedding :: Pgvector.t()
  @type provider :: :auto | :bumblebee | :google

  @doc """
  Generate embedding with automatic fallback.

  Internal tooling = prioritize working over performance.
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, opts \\ []) do
    provider = Keyword.get(opts, :provider, :auto)

    case provider do
      :auto -> embed_with_fallback(text)
      :bumblebee -> embed_bumblebee(text)
      :google -> embed_google(text)
      _ -> {:error, :invalid_provider}
    end
  end

  # Existing embed_with_fallback/1, embed_google/1, embed_bumblebee/1...
end
```

### Updated KnowledgeArtifactStore

```elixir
alias Singularity.EmbeddingGenerator

defp generate_embedding_async(artifact) do
  text = generate_embedding_text(artifact)

  # Use single embedding generator (auto-fallback)
  case EmbeddingGenerator.embed(text, provider: :auto) do
    {:ok, embedding} ->
      artifact
      |> KnowledgeArtifact.changeset(%{embedding: embedding})
      |> Repo.update()

      Logger.debug("Generated embedding for #{artifact.artifact_type}/#{artifact.artifact_id}")
      {:ok, embedding}

    {:error, reason} ->
      Logger.error("Embedding generation failed: #{inspect(reason)}")
      {:error, reason}
  end
end
```

## What to Keep vs Remove

### ✅ KEEP: EmbeddingGenerator
- **Path**: `lib/singularity/llm/embedding_generator.ex`
- **Why**: Works, has fallback, simple setup
- **Action**: Make it the standard, enhance if needed

### ❌ DEPRECATE: EmbeddingService
- **Path**: `lib/singularity/embedding_service.ex`
- **Why**: Overlaps with EmbeddingGenerator
- **Action**: Mark deprecated, migrate callers to EmbeddingGenerator

### ❌ REMOVE or FIX LATER: EmbeddingEngine
- **Path**: `lib/singularity/embedding_engine.ex`
- **Why**: Rustler NIF broken, complex setup
- **Action**: Either fix Rust compilation OR remove entirely (not needed for internal use)

## Migration Script

```elixir
# mix/tasks/embedding.migrate.ex
defmodule Mix.Tasks.Embedding.Migrate do
  @moduledoc """
  Migrate from old embedding modules to EmbeddingGenerator.
  """

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    # Find all calls to old embedding modules
    files = Path.wildcard("lib/**/*.ex")

    Enum.each(files, fn file ->
      content = File.read!(file)

      # Replace EmbeddingService calls
      updated =
        content
        |> String.replace("EmbeddingService.embed", "EmbeddingGenerator.embed")
        |> String.replace("EmbeddingEngine.embed", "EmbeddingGenerator.embed")

      if content != updated do
        File.write!(file, updated)
        Mix.shell().info("Updated: #{file}")
      end
    end)
  end
end
```

## Testing the Consolidation

```elixir
# Test all three fallback levels
defmodule EmbeddingGeneratorTest do
  use ExUnit.Case

  test "local bumblebee embedding works" do
    {:ok, embedding} = EmbeddingGenerator.embed("test code", provider: :bumblebee)
    assert is_struct(embedding, Pgvector)
    assert Pgvector.size(embedding) == 768
  end

  test "google fallback works" do
    {:ok, embedding} = EmbeddingGenerator.embed("test text", provider: :google)
    assert is_struct(embedding, Pgvector)
  end

  test "auto fallback chain" do
    {:ok, embedding} = EmbeddingGenerator.embed("async worker pattern")
    assert is_struct(embedding, Pgvector)
  end
end
```

## Summary: The Best Way

**For internal tooling:**

1. **Use**: `EmbeddingGenerator` only
2. **Deprecate**: `EmbeddingService` (redundant)
3. **Remove or Fix Later**: `EmbeddingEngine` (broken Rustler NIF)

**Why this is best:**
- ✅ Simplest (one module, one API)
- ✅ Works now (no Rust compilation needed)
- ✅ Automatic fallback (never fails)
- ✅ Good enough for internal use (Bumblebee is fast)
- ✅ Less maintenance (fewer moving parts)

**You don't need Rust NIFs for internal tooling!** Bumblebee + EXLA on your RTX 4080 is plenty fast for knowledge base search.

---

**Next Step:** Run the migration script and update all callers to use `EmbeddingGenerator`.
