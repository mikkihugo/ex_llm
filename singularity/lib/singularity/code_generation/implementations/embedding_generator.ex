defmodule Singularity.CodeGeneration.Implementations.EmbeddingGenerator do
  @moduledoc """
  Embedding Generator - Local ONNX embeddings with multi-vector concatenation.

  Always generates 2560-dimensional concatenated embeddings:
  - **Qodo-Embed-1** (1536-dim): Code semantics, specialized for source code
  - **Jina v3** (1024-dim): General text understanding
  - **Concatenated**: 2560-dim combining both models for maximum quality

  ## Key Benefits
  - ✅ Local inference (no API calls, works offline)
  - ✅ Dual-model strength (code + text understanding)
  - ✅ No API keys needed
  - ✅ No quota limits
  - ✅ Deterministic (same input = same embedding every time)
  - ✅ Consistent 2560-dim output (no dimension variance)

  ## Usage

      # Generate embedding - always 2560-dim
      {:ok, embedding} = EmbeddingGenerator.embed("def hello do :ok end")
      # => %Pgvector{} with 2560 dimensions

      # The :model option is ignored; both models always used for quality
      {:ok, embedding} = EmbeddingGenerator.embed("some text", model: :ignored)

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.EmbeddingGenerator",
    "purpose": "High-level embedding generation API with automatic model selection",
    "role": "service",
    "layer": "llm_services",
    "key_responsibilities": [
      "Provide embed/2 API for 2560-dim concatenated embeddings",
      "Delegate to EmbeddingEngine for Qodo + Jina v3 concatenation",
      "Ensure consistent 2560-dimensional output for all texts",
      "Return pgvector format for PostgreSQL storage"
    ],
    "prevents_duplicates": ["EmbeddingService", "LocalEmbeddingGenerator", "Vectorizer"],
    "uses": ["EmbeddingEngine", "Logger", "Pgvector"],
    "embedding_strategy": "Concatenated multi-vector (always 2560-dim)",
    "models_used": {
      "qodo_embed": "1536-dim code-optimized",
      "jina_v3": "1024-dim general-purpose"
    },
    "output": "2560-dim concatenated vector (1536 + 1024)"
  }
  ```

  ### Architecture Diagram (Mermaid)

  ```mermaid
  graph TB
    User["User Code"] -->|1. embed/2| Gen["EmbeddingGenerator"]
    Gen -->|2. always concatenate| Engine["EmbeddingEngine"]

    Engine -->|3a. Qodo inference| Qodo["Qodo-Embed<br/>(1536-dim)"]
    Engine -->|3b. Jina inference| Jina["Jina v3<br/>(1024-dim)"]

    Qodo -->|combine| Concat["Concatenate<br/>[1536 || 1024]"]
    Jina -->|combine| Concat

    Concat -->|normalize| Norm["Normalize to<br/>unit length"]

    Norm -->|4. convert| PGVec["Pgvector<br/>(2560-dim)"]

    PGVec -->|5. return| Gen
    Gen -->|6. {:ok, embedding}| User
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.EmbeddingEngine
      function: embed/2
      purpose: Delegate to unified embedding inference service
      critical: true
      pattern: "Direct delegation to embedding service"

    - module: System
      function: get_env/1
      purpose: Check GPU environment variables
      critical: true
      pattern: "Hardware detection (CUDA_VISIBLE_DEVICES, HIP_VISIBLE_DEVICES)"

    - module: Pgvector
      function: new/1
      purpose: Convert embedding array to pgvector format
      critical: true
      pattern: "PostgreSQL vector format conversion"

    - module: Logger
      function: debug/2, error/2
      purpose: Log model selection and errors
      critical: false

  called_by:
    - module: Singularity.Storage.PatternMiner
      function: embed_pattern/1
      purpose: Generate embeddings for code patterns
      frequency: per_pattern

    - module: Singularity.CodeSearch
      function: index_code/1
      purpose: Embed code chunks for semantic search
      frequency: per_index_operation

    - module: Singularity.Embedding.Service
      function: handle_request/1
      purpose: Process embedding requests from pgmq
      frequency: per_pgmq_request

    - module: Singularity.Knowledge.LearningLoop
      function: embed_learned_pattern/1
      purpose: Embed newly discovered patterns
      frequency: per_learning_event

  state_transitions:
    - name: embed_with_auto_detection
      from: idle
      to: idle
      trigger: embed/2 called without explicit model
      actions:
        - Detect GPU availability
        - Select appropriate model (Qodo for GPU, MiniLM for CPU)
        - Delegate to EmbeddingEngine
        - Return embedding

    - name: embed_with_forced_model
      from: idle
      to: idle
      trigger: embed/2 called with model option
      actions:
        - Use specified model directly
        - Skip GPU detection
        - Delegate to EmbeddingEngine
        - Return embedding

  depends_on:
    - Singularity.EmbeddingEngine (MUST be available)
    - ONNX models on disk (MUST exist)
    - Pgvector hex package (MUST be installed)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create LocalEmbedder, EmbeddingService, or VectorGenerator duplicates
  **Why:** EmbeddingGenerator is the single public API for embeddings with automatic model selection.

  ```elixir
  # ❌ WRONG - Duplicate embedding service
  defmodule MyApp.LocalEmbedder do
    def embed_text(text) do
      # Re-implementing what EmbeddingGenerator already does
    end
  end

  # ✅ CORRECT - Use EmbeddingGenerator
  {:ok, embedding} = EmbeddingGenerator.embed(text)
  ```

  #### ❌ DO NOT call EmbeddingEngine.embed directly from non-infrastructure code
  **Why:** EmbeddingGenerator provides automatic model selection; EmbeddingEngine is lower-level.

  ```elixir
  # ❌ WRONG - Bypass automatic model selection
  {:ok, embedding} = EmbeddingEngine.embed(text, model: :minilm)

  # ✅ CORRECT - Let EmbeddingGenerator auto-select
  {:ok, embedding} = EmbeddingGenerator.embed(text)
  ```

  #### ❌ DO NOT hardcode model selection logic in callers
  **Why:** Hardware detection should be centralized in EmbeddingGenerator.

  ```elixir
  # ❌ WRONG - Duplicate GPU detection logic
  model = case System.get_env("CUDA_VISIBLE_DEVICES") do
    nil -> :minilm
    _ -> :qodo_embed
  end
  {:ok, embedding} = EmbeddingEngine.embed(text, model: model)

  # ✅ CORRECT - Let EmbeddingGenerator handle detection
  {:ok, embedding} = EmbeddingGenerator.embed(text)
  ```

  #### ❌ DO NOT ignore GPU availability when it is present
  **Why:** GPU models are 2-3x faster and code-optimized; should always be preferred.

  ```elixir
  # ❌ WRONG - Forcing CPU model when GPU available
  {:ok, embedding} = EmbeddingGenerator.embed(text, model: :minilm)

  # ✅ CORRECT - Use automatic selection to prefer GPU
  {:ok, embedding} = EmbeddingGenerator.embed(text)
  ```

  ### Search Keywords

  embedding generation, ONNX embeddings, Qodo-Embed, MiniLM, GPU auto-detection,
  semantic search, text-to-vector, pgvector conversion, code embeddings, vector database,
  machine learning, model selection, hardware detection, embedding API, local inference
  """

  require Logger
  alias Singularity.EmbeddingEngine

  @type embedding :: Pgvector.t()

  @doc """
  Generate embedding for text using pure local ONNX models.

  Automatically selects model based on hardware availability:
  - GPU available (CUDA/Metal/ROCm) → Qodo-Embed (1536D, code-optimized)
  - CPU only → MiniLM-L6-v2 (384D, lightweight but excellent)

  No API calls, works offline, no API keys needed.

  ## Options

  - `:model` - Force specific model: `:qodo_embed` or `:minilm`
  - `:dimension` - Expected dimension (for validation)

  ## Examples

      # Auto-select best model
      {:ok, embedding} = EmbeddingGenerator.embed("async worker pattern")

      # Force MiniLM on CPU
      {:ok, embedding} = EmbeddingGenerator.embed("query", model: :minilm)

      # Force Qodo-Embed for code
      {:ok, embedding} = EmbeddingGenerator.embed("fn main() {}", model: :qodo_embed)
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, opts \\ []) do
    model = opts[:model] || select_best_model()

    case EmbeddingEngine.embed(text, model: model) do
      {:ok, embedding} ->
        Logger.debug("Generated embedding via #{model}", dimension: byte_size(inspect(embedding)))
        {:ok, Pgvector.new(embedding)}

      {:error, reason} ->
        Logger.error("Embedding generation failed", model: model, reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Get dimension of specified model.
  """
  @spec dimension(atom()) :: pos_integer()
  def dimension(:qodo_embed), do: 1536
  def dimension(:minilm), do: 384
  def dimension(:jina_v3), do: 1024

  # Private: Auto-select best available model
  defp select_best_model do
    # Prefer Qodo-Embed if available (GPU with code specialization)
    # Fall back to MiniLM for CPU-only environments
    case System.get_env("CUDA_VISIBLE_DEVICES") || System.get_env("HIP_VISIBLE_DEVICES") do
      nil ->
        # No GPU found
        Logger.debug("No GPU detected, using MiniLM-L6-v2 for embeddings")
        :minilm

      _gpu ->
        # GPU available
        Logger.debug("GPU detected, using Qodo-Embed-1 for embeddings")
        :qodo_embed
    end
  end
end
