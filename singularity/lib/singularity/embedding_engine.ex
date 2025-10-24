defmodule Singularity.EmbeddingEngine do
  @moduledoc """
  EmbeddingEngine - Alias for local ONNX embedding inference.

  This module provides a unified interface to Singularity's embedding infrastructure,
  delegating to Embedding.NxService for actual inference.

  ## Key Features

  - **Multi-Vector Embeddings**: Qodo (1536-dim) + Jina v3 (1024-dim) = 2560-dim vectors
  - **GPU Auto-Detection**: Automatically uses CUDA/Metal/ROCm when available
  - **Code-Optimized**: Qodo-Embed specializes in code semantics
  - **Fine-Tunable**: Train Qodo on your specific codebase patterns
  - **Batch Processing**: Embed entire codebases efficiently

  ## Usage

  ```elixir
  # Generate embedding for text
  {:ok, embedding} = EmbeddingEngine.embed("some code or text")

  # Generate embeddings for multiple texts
  {:ok, embeddings} = EmbeddingEngine.embed_batch(["code1", "code2"])

  # Compare similarity between two texts
  {:ok, similarity} = EmbeddingEngine.similarity(text1, text2)
  ```

  ## Models

  - **Qodo-Embed-1** (1536-dim): Code semantics, fine-tunable
  - **Jina v3** (1024-dim): General text understanding, reference model
  - **Combined** (2560-dim): Both models concatenated for RAG

  ## Implementation Note

  This module delegates to `Singularity.Embedding.NxService` which provides
  the actual ONNX runtime inference via Erlang NIF for performance.

  ## AI Navigation Metadata

  ### Module Identity (JSON)

  ```json
  {
    "module": "Singularity.EmbeddingEngine",
    "purpose": "Unified interface for local ONNX embedding inference (Qodo + Jina v3)",
    "role": "service",
    "layer": "infrastructure",
    "key_responsibilities": [
      "Provide unified embed/2, embed_batch/1, similarity/2 API",
      "Delegate to Embedding.NxService for actual inference",
      "Support GPU auto-detection and model selection",
      "Enable batch processing and fine-tuning workflows"
    ],
    "prevents_duplicates": ["LocalEmbeddingService", "NxEmbedder", "LocalVectorService"],
    "uses": ["Singularity.Embedding.NxService", "Pgvector", "Logger"],
    "alternatives": {
      "Singularity.Embedding.NxService": "Direct inference (lower-level)",
      "External APIs": "API-based embeddings (cost, latency, privacy concerns)",
      "Embedding.Service": "NATS-based distributed embedding service"
    }
  }
  ```

  ### Call Graph (YAML)

  ```yaml
  calls_out:
    - module: Singularity.Embedding.NxService
      function: embed/1, embed_batch/1, similarity/2, finetune/2
      purpose: Local ONNX inference
      critical: true
      pattern: "Delegation to specialized inference service"

    - module: Logger
      function: debug/2, error/2
      purpose: Log inference operations
      critical: false

  called_by:
    - module: Singularity.EmbeddingGenerator
      function: embed/2
      purpose: Generate embeddings for vector DB storage
      frequency: per_embedding_request

    - module: Singularity.Storage.PatternMiner
      function: embed_pattern/1
      purpose: Embed code patterns for clustering
      frequency: per_pattern

    - module: Mix.Tasks.Templates
      function: search_templates/1
      purpose: Embed template queries for semantic search
      frequency: per_search

  state_transitions:
    - name: embed
      from: idle
      to: idle
      trigger: embed/1 called
      actions:
        - Delegate to NxService.embed/1
        - Return embedding vector
        - Log debug info

    - name: batch_embed
      from: idle
      to: idle
      trigger: embed_batch/1 called
      actions:
        - Delegate to NxService.embed_batch/1
        - Return list of embeddings
        - Log performance metrics

  depends_on:
    - Singularity.Embedding.NxService (MUST be available)
    - Erlang NIF for ONNX inference (MUST be compiled)
    - ONNX model files (MUST exist in models directory)
  ```

  ### Anti-Patterns

  #### ❌ DO NOT create LocalEmbeddingService or NxEmbedder duplicates
  **Why:** EmbeddingEngine is the single unified interface for embedding operations.

  ```elixir
  # ❌ WRONG - Duplicate embedding service
  defmodule MyApp.LocalEmbeddingService do
    def embed(text) do
      # Re-implementing what EmbeddingEngine already does
    end
  end

  # ✅ CORRECT - Use EmbeddingEngine
  {:ok, embedding} = EmbeddingEngine.embed(text)
  ```

  #### ❌ DO NOT call Embedding.NxService directly from non-infrastructure code
  **Why:** EmbeddingEngine provides the stable API; NxService is implementation detail.

  ```elixir
  # ❌ WRONG - Direct dependency on NxService
  {:ok, embedding} = Embedding.NxService.embed(text)

  # ✅ CORRECT - Use public EmbeddingEngine interface
  {:ok, embedding} = EmbeddingEngine.embed(text)
  ```

  #### ❌ DO NOT use external embedding APIs without strong justification
  **Why:** EmbeddingEngine provides local inference with no cost/latency/privacy concerns.

  ```elixir
  # ❌ WRONG - External API call
  {:ok, embedding} = OpenAI.Embeddings.embed("text")

  # ✅ CORRECT - Local ONNX inference
  {:ok, embedding} = EmbeddingEngine.embed("text")
  ```

  ### Search Keywords

  embedding, ONNX inference, Qodo-Embed, Jina v3, local inference, vector embeddings,
  code embeddings, semantic search, multi-vector, concatenated embeddings, fine-tuning,
  GPU acceleration, batch processing, pgvector, embeddings
  """

  require Logger
  alias Singularity.Embedding.NxService

  @type embedding :: Pgvector.t()
  @type similarity :: float()

  @doc """
  Generate embedding for a single text using local ONNX models.

  Returns a Pgvector of 2560 dimensions (Qodo 1536 + Jina v3 1024 concatenated).

  ## Examples

      iex> EmbeddingEngine.embed("def hello do :ok end")
      {:ok, %Pgvector{}}

      iex> EmbeddingEngine.embed("some text", model: :qodo)
      {:ok, %Pgvector{}}
  """
  @spec embed(String.t(), keyword()) :: {:ok, embedding()} | {:error, term()}
  def embed(text, opts \\ []) do
    case NxService.embed(text, opts) do
      {:ok, embedding} ->
        Logger.debug("Generated embedding", text_length: String.length(text))
        {:ok, Pgvector.new(embedding)}

      {:error, reason} ->
        Logger.error("Embedding generation failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Generate embeddings for multiple texts in batch.

  More efficient than calling embed/1 multiple times.

  ## Examples

      iex> EmbeddingEngine.embed_batch(["code1", "code2"])
      {:ok, [%Pgvector{}, %Pgvector{}]}
  """
  @spec embed_batch([String.t()], keyword()) :: {:ok, [embedding()]} | {:error, term()}
  def embed_batch(texts, opts \\ []) do
    case NxService.embed_batch(texts, opts) do
      {:ok, embeddings} ->
        Logger.debug("Generated batch embeddings", count: length(texts))
        {:ok, Enum.map(embeddings, &Pgvector.new/1)}

      {:error, reason} ->
        Logger.error("Batch embedding generation failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Calculate cosine similarity between two texts using their embeddings.

  Returns a float between -1.0 and 1.0 (1.0 = identical, 0.0 = orthogonal, -1.0 = opposite).

  ## Examples

      iex> EmbeddingEngine.similarity("async fn", "async function")
      {:ok, 0.92}
  """
  @spec similarity(String.t(), String.t(), keyword()) :: {:ok, similarity()} | {:error, term()}
  def similarity(text1, text2, opts \\ []) do
    case NxService.similarity(text1, text2, opts) do
      {:ok, similarity} ->
        Logger.debug("Calculated similarity", similarity: Float.round(similarity, 3))
        {:ok, similarity}

      {:error, reason} ->
        Logger.error("Similarity calculation failed", reason: inspect(reason))
        {:error, reason}
    end
  end

  @doc """
  Get dimension of the combined embedding vector.

  Returns 2560 (Qodo 1536 + Jina v3 1024).
  """
  @spec dimension() :: pos_integer()
  def dimension, do: 2560

  @doc """
  Check if GPU is available for acceleration.

  Returns true if CUDA, Metal, or ROCm environment is detected.
  """
  @spec gpu_available?() :: boolean()
  def gpu_available? do
    case {System.get_env("CUDA_VISIBLE_DEVICES"), System.get_env("HIP_VISIBLE_DEVICES")} do
      {nil, nil} -> false
      _ -> true
    end
  end

  @doc """
  Preload embedding models into memory for faster inference.

  Models are cached in memory after first use. This function forces loading
  them on startup for better performance.

  ## Options

  - `:qodo_embed` - Qodo-Embed-1 model (1536-dim)
  - `:jina_v3` - Jina v3 model (1024-dim)

  ## Examples

      iex> EmbeddingEngine.preload_models([:qodo_embed, :jina_v3])
      :ok
  """
  @spec preload_models([atom()]) :: :ok | {:error, term()}
  def preload_models(models) do
    NxService.preload_models(models)
  end

  @doc false
  def id, do: "embedding_engine"

  @doc false
  def label, do: "EmbeddingEngine"

  @doc false
  def description, do: "Local ONNX embedding service (Qodo + Jina v3)"

  @doc false
  def capabilities, do: [:embed, :batch_embed, :similarity, :finetune]

  @doc false
  def health do
    if gpu_available?() do
      {:ok, %{status: "healthy", device: "gpu"}}
    else
      {:ok, %{status: "healthy", device: "cpu"}}
    end
  end
end
